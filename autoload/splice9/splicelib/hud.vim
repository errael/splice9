vim9script

var standalone_exp = false
if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
    standalone_exp = true
endif

# NOTE: simplification/rewrite when vim9 classes. "class Mode"
#   TODO:   HUD query what commands are allowed
#           current mode, 
#           'o','r','1','2'; 'u'/'u1'-'u2'; diffs-on/off
#           cur-diff (should there be a diff diagram? highlight in layout)
#
# TODO: o, r, 1, 2 are not always valid, maybe grey when not valid
# TODO: other items might be subject to greying out,
# TODO: for example, diffs may not be valid in loupe mode.

var testing = standalone_exp

var hl_label: string
var hl_sep: string
var hl_command: string
var hl_rollover: string
var hl_active: string
# TODO: use hl_active for current mode, diff on, scrollbind on

var Log: func

if ! testing
    import autoload './util/log.vim'
    import autoload './util/vim_assist.vim'
    import autoload './util/keys.vim'
    import autoload './util/ui.vim'
    import autoload '../splice.vim'

    # highlights used on the HUD and in its text properties

    hl_label = splice.hl_label
    hl_sep = splice.hl_sep
    hl_command = splice.hl_command
    hl_rollover = splice.hl_rollover
    hl_active = splice.hl_active

    Log = log.Log
else
    import './vim_assist.vim'
    import './hud_sub.vim'
    import './log.vim'
    import './keys.vim'
    import './ui.vim'

    const DumpDia = hud_sub.DumpDia
    const DisplayHuds = hud_sub.DisplayHuds
    Log = log.Log
    log.LogInit('/home/err/play/SPLICE_LOG')

    hl_label = 'SpliceLabel'
    hl_sep = 'SpliceLabel'
    hl_command = 'SpliceCommand'
    hl_rollover = 'Pmenu'
    hl_active = 'Keyword'

    highlight SpliceCommand term=bold cterm=bold gui=bold
    highlight SpliceLabel term=underline ctermfg=6 guifg=DarkCyan

endif

if exists('&mousemoveevent')
    &mousemoveevent = true
endif

const With = vim_assist.With
const ModifiableEE  = vim_assist.ModifiableEE 
const Pad = vim_assist.Pad
const Replace = vim_assist.Replace
const ReplaceBuf = vim_assist.ReplaceBuf
const MappingsList = keys.MappingsList
const AddSeparators = keys.AddSeparators

# The HUD is made up of 3 lines and 3 sections:
#
#       modes || layout || commands
#
# Each section is 3 lines high. Each section is a fixed width.
# Much of the detailed info about the sections is derived
# dynamically during startup.

# use vertical double bar if possible
const sepchar = &encoding == 'utf-8' && &ambiwidth == 'single'
    ? nr2char(0x2551) : '|'
const sep_pad = '  '
const sep = sep_pad .. sepchar .. sep_pad

var layout_width: number
var layout_offset: number
var actions_offset: number

# actions is the locations of actions/commands in the HUD
# actions[name] = [ lnum, col0, col1 ]
var actions: dict<list<number>>
var base_actions: dict<list<number>>
var hunk_action1: dict<list<number>>
var hunk_action2: dict<list<number>>
const u_h = 'UseHunk'
const u_h1 = 'UseHunk1'
const u_h2 = 'UseHunk2'
const u_h_name = 'u :  use hunk'

const label_modes = 'Splice Modes:'
const label_layout = 'Layout:'
const label_commands = 'Splice Commands:'

const btn_display_commands = 'BtnDisplayCommands'

#
# There are special_cmds, these are ui related
# and handled within the HUD.
#
const special_cmds = [ btn_display_commands ]
var SpliceBtnDisplayCommands: func
SpliceBtnDisplayCommands = () => {
    echo 'UNINITIALIZED: SpliceBtnDisplayCommands'
}

#
# Track last window position.
# Use it to go back to the prev window before executing a command.
# [ winid, [ pos... ] ]
var last_win = null_list

def ClearWinPos()
    last_win = null_list
enddef

def RestoreWinPos()
    if last_win != null
        # copy before it's change by win_gotoid
        var lw = last_win->deepcopy()
        if win_gotoid(lw[0])
            setpos('.', lw[1])
        endif
        last_win = null_list
    endif
enddef

# only save positions for our magic merge windows
def SaveWinPos()
    var bnr = bufnr()
    last_win = bnr >= 1 && bnr <= 4
                ? [ win_getid(), getcurpos() ] : null_list
enddef

augroup hud
    autocmd!
    autocmd WinLeave * SaveWinPos()
augroup END


def ExecuteCommand(cmd: string)
    if testing
        RestoreWinPos()
        echo 'Execute: ' .. cmd
        if special_cmds->index(cmd) >= 0
            execute 'Splice' .. cmd .. '()'
        endif
    else
        RestoreWinPos()
        var splice_cmd = 'Splice' .. cmd
        Log('Execute: ' .. splice_cmd)
        if special_cmds->index(cmd) >= 0
            splice_cmd ..= '()'
        endif
        execute splice_cmd
    endif
enddef

################################################################
#
# modes section designations/specifications
#

var modes_section =<< EOF
 [g]rid    [c]ompare
 XXXXXX    YYYYYYYYY
 [l]oupe   [p]ath
 XXXXXXX   YYYYYY
EOF
# Set up modes_section, add label and get rid of markers
modes_section = [ label_modes, modes_section[0], modes_section[2] ]->Pad()
lockvar! modes_section

# each modes value:  dict of
#   m_line:     hud line, 1 based
#   m_col:      hud col, 0 based, of activate '*'
#   m_lays:     index into layout_diagrams
#   m_nfile:    number of files for X,Y substitution
#   m_len:      chars on screen, "[g]rid" == 6
const modes = {
    grid:       { m_line: 2, m_col: 0,   m_lays: 0, m_nfile: 0, m_len: 6 },
    loupe:      { m_line: 3, m_col: 0,   m_lays: 1, m_nfile: 1, m_len: 7 },
    compare:    { m_line: 2, m_col: 10,  m_lays: 2, m_nfile: 2, m_len: 9 },
    path:       { m_line: 3, m_col: 10,  m_lays: 3, m_nfile: 1, m_len: 6 }
}

################################################################
#
# commands
#

# The commands HUD display
var command_display =<< EOF
d: cycle diffs   n: next conflict   space: cycle layouts   u1: use hunk1   o: original   1: one   q: save-quit
AAAAAAAAAAAAAA   BBBBBBBBBBBBBBBB   CCCCCCCCCCCCCCCCCCCC   DDDDDDDDDDDDD   EEEEEEEEEEE   FFFFFF   GGGGGGGGGGGG
D: diffs off     N: prev conflict   s: toggle scrollbind   u2: use hunk2   r: result     2: two   CC: error-exit
AAAAAAAAAAAA     BBBBBBBBBBBBBBBB   CCCCCCCCCCCCCCCCCCCC   DDDDDDDDDDDDD   EEEEEEEEE     FFFFFF   GGGGGGGGGGGGGG
EOF

# 
# The following list/method associates internal actions with HUD command buttons.
# Command button boundaries are dynamically built from the above command_display.
#
var command_actions = [
    'Diff',    'Next',     'Layout', 'UseHunk1', 'Original', 'One', 'Quit',
    'DiffOff', 'Previous', 'Scroll', 'UseHunk2', 'Result',   'Two', 'Cancel',
]
def ActionsByIndex(): list<string>
    # return ActionsSortedBy('a_cidx')
    return command_actions
enddef
# [ 'cycle diffs', 'next conflict', ... ]
var command_display_names: dict<string>

# Extract the button outlines from command_display (extracting 1 and 3 but...)
var command_markers = [ command_display->remove(1) ]
    ->add(command_display->remove(2))
command_display->insert(label_commands)->Pad()
lockvar! command_display
lockvar! command_markers
lockvar! command_actions

# The hunks are dynamically selected based on mode
const hunks = [ ' u: use hunk', 'u1: use hunk', 'u2:  hunk2  ' ]

################################################################
#
# Layouts
#

#
# Layouts available for Grid (originally in modes.py)
# Comments for the diagrams for the other modes not done
#
# Grid
#   Layout 0                 Layout 1                        Layout 2
#   +-------------------+    +--------------------------+    +---------------+
#   |     Original      |    | One    | Result | Two    |    |      One      |
#   |2                  |    |        |        |        |    |2              |
#   +-------------------+    |        |        |        |    +---------------+
#   |  One    |    Two  |    |        |        |        |    |     Result    |
#   |3        |4        |    |        |        |        |    |3              |
#   +-------------------+    |        |        |        |    +---------------+
#   |      Result       |    |        |        |        |    |      Two      |
#   |5                  |    |2       |3       |4       |    |4              |
#   +-------------------+    +--------------------------+    +---------------+

#
#       Each HUD section annotated: Splice Modes:, Layout:, Splice Commands:.
#
#       The vim9 implementation allows:
#               Layout:
#                  Original  XXX  Result
#
#               Layout:    Original
#                          One  Two
#                           Result
#               
#               Layout:
#                          XXXXXXXX
#                          YYYYYY
#       squeezing stuff together which reduces max width of HUD

var grid_layout_0 =<< EOF
Original
One  Two
Result
EOF

var grid_layout_1 =<< EOF

One Result Two

EOF


var grid_layout_2 =<< EOF
One
Result
Two
EOF

# XXXXXXXX One,Two,Result,Original
var loupe_layout_0 =<< END

XXXXXXXX

END

# XXXXXXXX is Original,One,Two
# YYYYYY is Result,One,Two
var compare_layout_0 =<< END

XXXXXXXX YYYYYY

END

# XXXXXXXX is Original,One,Two
# YYYYYY is Result,One,Two
var compare_layout_1 =<< END

XXXXXXXX
YYYYYY
END

# XXX is One,Two
var path_layout_0 =<< END

Original XXX Result

END

var path_layout_1 =<< END
Original
XXX
Result
END

const layout_diagrams: list<list<any>> = [
    [
        grid_layout_0,
        grid_layout_1,
        grid_layout_2,
    ], [
        loupe_layout_0,
    ], [
        compare_layout_0,
        compare_layout_1,
    ], [
        path_layout_0,
        path_layout_1,
    ]]

################################################################
#
# at startup build structures and text property definitions
#

def FindMaxLayoutWidth()
    # find the width of the longest possible diagram string
    var n = 0
    for s in layout_diagrams->flattennew(2)
        if len(s) > n
            n = len(s)
        endif
    endfor
    # "+ 2" for a little space around the longest line
    layout_width = n + 2

    lockvar layout_width
enddef

# 1 - Extract displayed command names
# 2 - Create actions button parameters for highlight/rollover text properties.
# actions['Action'] = [line, start, end]. Action like 'Grid'/'Next'/'Quit'
# line/start/end is in buffer, starts at 1. end exclusive
def BuildBaseActions(): dict<list<number>>
    # action_by_index is the order the commands appear left to right,
    # top to bottom. Also the order that items in command_markers are found.
    var command_action_keys = ActionsByIndex()
    var cmd_idx = 0
    var t_actions: dict<list<number>>
    var start: number
    var line = 2
    for m in command_markers
        start = 0
        while true
            # result is button boundaries for highlight/rollover.
            var result = matchstrpos(m,
                '\v(A+)|(B+)|(C+)|(D+)|(E+)|(F+)|(G+)', start)
            if result[1] == -1 | break | endif

            var actKey = command_action_keys[cmd_idx]

            # 1 - Extract displayed command names, discard like: "u1: "
            var t = command_display[line - 1]->slice(result[1], result[2])
            command_display_names[actKey] = matchlist(t, '\v.*:\s+(.*)')[1]

            # 2 - Create actions button parameters for text propertiess
            # Add one to make the column values 1 based.
            t_actions[actKey] = [ line,
                actions_offset + result[1] + 1,
                actions_offset + result[2] + 1]

            start = result[2]
            cmd_idx += 1
        endwhile
        line += 1
    endfor

    # From modes add in the Grid, Loupe, ... actions
    for [ k, v ] in modes->items()
        # make key Grid, not grid, to correspond to command name
        var actKey = k[0]->toupper() .. k[1 : ]
        var [lino, col] = [ v.m_line, v.m_col ]
        # +1 makes it 1 based, +1 to skip activation position
        col += 2
        t_actions[actKey] = [ lino, col, col + v.m_len ]
        command_display_names[actKey] = k
    endfor

    unlockvar! command_markers
    command_markers = null_list
    return t_actions
enddef

#
# Various textprops for the hud.
#

const prop_action = 'prop_action'
const prop_rollover = 'prop_rollover'
const prop_label = 'prop_label'
const prop_sep = 'prop_sep'
const prop_active = 'prop_active'

# NOTE: arg dict has bnr, assumed constant for duration
var did_action_props = false
def AddHeaderProps(d: dict<any> = null_dict)
    # Assuming bnr doesn't change
    if did_action_props | return | endif

    var props_com = {
        highlight: hl_command,
        priority: 100,
        combine: false,
    }
    var props_roll = {
        highlight: hl_rollover,
        priority: 110,
        combine: false,
    }
    var props_lab = {
        highlight: hl_label,
        priority: 100,
        combine: false,
    }
    var props_sep = {
        highlight: hl_sep,
        priority: 100,
        combine: false,
    }
    var props_act = {
        highlight: hl_active,
        priority: 100,
        combine: false,
    }
    props_com->extend(d)
    props_roll->extend(d)
    props_lab->extend(d)
    props_sep->extend(d)
    props_act->extend(d)

    prop_type_add(prop_action, props_com)
    prop_type_add(prop_rollover, props_roll)
    prop_type_add(prop_label, props_lab)
    prop_type_add(prop_sep, props_sep)
    prop_type_add(prop_active, props_act)

    did_action_props = true
enddef

# DoInit_1 doesn't depend on hudbufnr.
# This is only done once during startup
var did_init_1 = false
def DoInit_1()
    if did_init_1 | return | endif
    FindMaxLayoutWidth()

    layout_offset = modes_section[0]->len()  + sep->len()
    actions_offset = layout_offset + layout_width + sep->len()
    lockvar layout_offset
    lockvar actions_offset

    base_actions = BuildBaseActions()

    # The UseHunk1 location is also used for UseHunk
    # Remove any UseHunk from base actions
    var tmp = base_actions->remove(u_h1)
    hunk_action2[u_h1] = tmp
    hunk_action1[u_h] = tmp

    tmp = base_actions->remove(u_h2)
    hunk_action2[u_h2] = tmp

    # add the displayed name for UseHunk
    command_display_names[u_h] = matchlist(u_h_name, '\v.*:\s+(.*)')[1]

    # add some special commands
    base_actions[btn_display_commands] = [ 1,
        actions_offset + 1, actions_offset + 1 + label_commands->len() ]

    lockvar! base_actions
    lockvar! hunk_action2
    lockvar! hunk_action1
    lockvar! command_display_names
    #echo string(base_actions)
    #echo string(hunk_action2)
    #echo string(hunk_action1)

    did_init_1 = true
enddef

################################################################
#
# create the HUD, recreated for each state change
#

# Add the action textprop to each command in HUD.
def HighlightActions(bnr: number)
    var props = {type: prop_action, bufnr: bnr, all: true}
    prop_remove(props)

    for [ line, start, end ] in actions->values()
        props.end_col = end
        prop_add(line, start, props)
    endfor
enddef

def HighlightMode(mode: string, bnr: number)
    var props = {type: prop_active, bufnr: bnr, all: true}
    prop_remove({type: prop_active, bufnr: bnr, all: true})
    var v = modes->get(mode)
    # increase length to include the '*'
    props.length = v.m_len + 1
    prop_add(v.m_line, v.m_col + 1, props)
enddef

# Labels and seperators. The labels are on the first line of the buffer
def HighlightLabels(bnr: number)
    var props = {type: prop_label, bufnr: bnr, all: true}
    prop_remove(props)

    props.length = len(label_modes)
    prop_add(1, 1, props)
    props.length = len(label_layout)
    prop_add(1, layout_offset + 1, props)
    props.length = len(label_commands)
    prop_add(1, actions_offset + 1, props)

    # and the separators
    props.type = prop_sep
    props.length = len(sepchar)
    prop_remove(props)
    setpos('.', [bnr, 1, 1, 0])
    while searchpos(sepchar, 'W') != [0, 0]
        var [ _, lino, col; x ] = getcurpos()
        prop_add(lino, col, props)
    endwhile
    setpos('.', [bnr, 1, 1, 0])
enddef


# return the layout diagram
def BuildLayoutDiagram(mode: string, layout: number,
        vari_files: list<string>): list<string>
    var num_vari_files =  modes->get(mode).m_nfile
    if len(vari_files) != num_vari_files
        throw 'Wrong number of file names for '
            .. mode .. ': ' .. string(vari_files)
    endif

    var layout_diagram = layout_diagrams[modes[mode].m_lays][layout]->deepcopy()

    # substite X* Y* with vari_files
    if !!num_vari_files
        layout_diagram->map((_, s) => {
            var t = substitute(s, '\v\CX+', vari_files[0], '')
            if num_vari_files == 2
                t = substitute(t, '\v\CY+', vari_files[1], '')
            endif
            return t
            })
    endif

    # get the width after subsitution
    layout_diagram->Pad('c')
    var width = layout_diagram[0]->len()

    # Shift a centered layout_diagram right when it still fit in layout_width.
    if width + 5 <= layout_width
        layout_diagram->Pad('c', layout_width - 5)
        layout_diagram->map((_, s) => '     ' .. s)
    else
        layout_diagram->Pad('r', layout_width)
    endif
        
    # overlay "Layout:" upper-left of the layout_diagram
    #diagram[0] = layout_diagram[0]->Replace(0, len(label_layout) - 1, label_layout)
    layout_diagram[0] = layout_diagram[0]->Replace(0, label_layout)
    return layout_diagram
enddef

def BuildHud(mode: string, layout: number,
        vari_files: list<string>): list<string>
    var layout_display = BuildLayoutDiagram(mode, layout, vari_files)
    var result = []
    var modes_display = modes_section->deepcopy()
    var v = modes->get(mode)
    var [ active_line, active_col ] = [ v.m_line, v.m_col ]
    # get line 0 based
    active_line -= 1
    modes_display[active_line] = modes_display[active_line]
                \->Replace(active_col, '*')

    var j = 0
    while j < 3
        result->add(modes_display[j] .. sep
            .. layout_display[j] .. sep
            .. command_display[j] ..  sep)
        j += 1
    endwhile
    return result
enddef

################################################################
#
# Mouse rollover/click
#

# An actions item.
var current_hud_rollover = null_list

# NOTE: if return needs to differentiate wrong window
#       then could return null vs []
# NOTE: <buffer> <LeftRelease> works, but <buffer> <MouseMove>
#        doesn't work, so must do bnr != hudbufnr

# Return null or item from actions dictionary.
# Could do a binary search within each line,
# or modify prop_find to add an "exact" with lnum/col
# or do a builtin prop_at({lnum},{col}).
def GetHudItemUnderMouse(mpos: dict<number>): list<any>
    if winbufnr(mpos.winid) != hudbufnr
        return null_list
    endif

    var mpos_line = mpos.line
    var mpos_col = mpos.column

    # check if mouse in current rollover
    if current_hud_rollover != null
        var [ i_line, i_start, i_end ] = current_hud_rollover[1]
        if mpos_line == i_line && mpos_col >= i_start && mpos_col < i_end
            return current_hud_rollover
        endif
    endif

    # search for action containing mouse pos
    for item in actions->items()
        var [ i_line, i_start, i_end ] = item[1]
        if mpos_line == i_line && mpos_col >= i_start && mpos_col < i_end
            return item
        endif
    endfor
    return null_list
enddef

# Mouse button, look for command action.
def Release()
    var item = getmousepos()->GetHudItemUnderMouse()
    #echomsg string(item) ####################################
    if item != null
        ExecuteCommand(item[0])
    else
        # Click in hud that's not a command. Forget last position
        ClearWinPos()
    endif
enddef

# Mouse move, handle command button rollover
def Move()
    var item = getmousepos()->GetHudItemUnderMouse()
    if current_hud_rollover != null
        if current_hud_rollover is item
            # echo 'cache hit:' item
            return
        else
            prop_remove({type: prop_rollover, bufnr: hudbufnr, all: true},
                current_hud_rollover[1][0])
            current_hud_rollover = null_list
        endif
    endif
    if item != null
        var [ line, start, end ] = item[1]
        prop_add(line, start,
            {end_col: end, type: prop_rollover, bufnr: hudbufnr, all: true})
        current_hud_rollover = item
    endif
enddef

# This is only for after replacing the hud lines with new hud lines
def RefreshMouseCache()
    current_hud_rollover = null_list
    Move()
enddef

################################################################
#
# Main
#

var created_hud: list<number>

var hudbufnr: number = -1

def InitHudBuffer()
    &swapfile = false
    &modifiable = false
    &buflisted = false
    &buftype = 'nofile'
    &undofile = false
    &list = false
    &filetype = 'splice'
    &wrap = false
    resize 3
    &winfixheight = true
    wincmd =
enddef


# vari_files replace X+, Y+ in layout diagram
def InstallHUD(mode: string, layout: number, bnr: number,
        vari_files: list<string>)
    DoInit_1()

    InitHudBuffer()
    var hud = BuildHud(mode, layout, vari_files)

    #...

    # NOTE: set[buf]line looses text properties, so might as
    #       well rebuild the whole thing every time.
    #       TODO: And get rid of prop_delete when adding props.

    &modifiable = true
    #deletebufline('', 1, '$')
    setline(1, hud)
    &modifiable = false

    hudbufnr = bnr
    DoInit_2(mode, bnr)
    RefreshMouseCache()
enddef

def LogDrawHUD(mode: string, layout: number,
    vari_files: list<string>, bnr: number)
    Log(printf("DrawHUD: mode: '%s', layout %d, vari_files %s, bnr %d",
        mode, layout, vari_files, bnr))
enddef

#
# This is invoked from python when the HUD is the current buffer
#
export def DrawHUD(use_vim: bool, mode: string, layout: number,
        ...vari_files: list<string>)
    var b = bufnr()
    LogDrawHUD(mode, layout, vari_files, b)

    if hudbufnr >= 0 && hudbufnr != b
        throw 'HUD buffer mismatch'
    endif

    InstallHUD(mode, layout, bufnr(), vari_files)
enddef

export def AnyThing()
    Log('THIS IS FROM AnyThing IN HUD.VIM')
enddef

def DoInit_2(mode: string, bnr: number)
    unlockvar! actions
    actions = base_actions->copy()
    if mode == 'grid'
        actions->extend(hunk_action2)
    else
        # not Grid, UseHunk replace UseHunk1, erase UseHunk2
        actions->extend(hunk_action1)
        With(ModifiableEE.new(bnr), (arg) => {
            var tmp = hunk_action2[u_h1]
            ReplaceBuf(bnr, tmp[0], tmp[1], u_h_name)
            tmp = hunk_action2[u_h2]
            ReplaceBuf(bnr, tmp[0], tmp[1], repeat(' ', len(u_h_name)))
        })
    endif
    lockvar! actions

    # TODO: u does nothing if neither one or two is visible
    #           maybe other layout details to enable

    AddHeaderProps({bufnr: bnr})
    HighlightActions(bnr)
    HighlightLabels(bnr)
    HighlightMode(mode, bnr)

    #for s in CreateCurrentMappings()
    #    echo s
    #endfor

    # only map click release in hud
    nnoremap <buffer><special> <LeftRelease> <ScriptCmd>Release()<CR>

    # Can not lock <MouseMove> to the buffer, because rollover moves
    # would not be detected when the vim focus is in a different buffer.
    nnoremap <special> <MouseMove> <ScriptCmd>Move()<CR>
enddef

# for popup
export def CreateCurrentMappings(): list<string>
    # create a separate list for each column
    var act_keys: list<string>
    var defaults: list<string>
    var mappings: list<string>
    var act_names: list<string>
    # ['Grid', ['<M-x>', '<M-g>'], 'g']
    for mappings_item in MappingsList()->AddSeparators(() => [])
        if !! mappings_item
            var [ act_key, mings, dflt ] = mappings_item
            var first_ming = true
            for ming in mings
                mappings->add(ming)
                if first_ming
                    act_keys->add(act_key)
                    defaults->add(dflt)
                    act_names->add("'" .. command_display_names[act_key] .. "'")
                else
                    act_keys->add('')
                    defaults->add('')
                    act_names->add('')
                endif
                first_ming = false
            endfor
        else
            act_keys->add('')
            defaults->add('')
            mappings->add('')
            act_names->add('')
        endif
    endfor
    defaults->Pad('r')
    act_names->Pad('l')
    act_keys->Pad('r')
    mappings->Pad('l')
    var ret: list<string>
    for i in range(len(mappings))
        ret->add(printf("%s %s %s   %s",
            defaults[i], act_names[i], act_keys[i], mappings[i]))
    endfor
    return ret
enddef

SpliceBtnDisplayCommands = () => {
    var text = CreateCurrentMappings()
    ui.PopupMessage(text, 'Splice Shortcuts')
}
lockvar! SpliceBtnDisplayCommands

if ! testing
    finish
endif

###########################################################################
###########################################################################
###########################################################################

Log('TESTING, TESTING, 1 2 3 TESTING')

# [ mode, layout, nbr, [varifiles] ]
var hud_args = [
    ['grid',    0, [] ],
    ['grid',    1, [] ],
    ['grid',    2, [] ],
    ['loupe',   0, ['fn0'] ],
    ['loupe',   0, ['Result'] ],
    ['compare', 0, ['fn1', 'fn2'] ],
    ['compare', 1, ['fn3', 'fn4'] ],
    ['compare', 0, ['Original', 'Result'] ],
    ['compare', 1, ['Original', 'Result'] ],
    ['path',    0, ['fn5'] ],
    ['path',    1, ['fn6'] ],
]

var hud_idx = 0

def NextHud(forw: bool = true)

    var use_idx = hud_idx
    if !forw
        hud_idx -= 2
        if hud_idx < 0
            hud_idx += len(hud_args)
        endif
        echom 'hud_idx:' hud_idx
        use_idx = hud_idx
    endif
    hud_idx += 1
    hud_idx %= len(hud_args)

    call(DrawHUD, [ true, hud_args[use_idx] ]->flattennew())
    return
enddef

command! -nargs=0 NN {
    win_gotoid(bufwinid(hudbufnr))
    NextHud()
}

command! -nargs=0 BB {
    win_gotoid(bufwinid(hudbufnr))
    NextHud(false)
}

defcompile

:1wincmd w
new __Splice_HUD__
wincmd J
#nnoremap <buffer> q <ScriptCmd>Release()<CR>
nnoremap <buffer> q :q<CR>
NextHud()

finish

###########################################################################
###########################################################################
###########################################################################

vim9script noclear
NextHud()

vim9script noclear
def X()
    var winid = popup_create('Small Popup', {close: 'click'})
    echo winid
enddef

#vim9script noclear
def Y()
    var winid = popup_create('Small Popup move dismiss', {mousemoved: 'any'})
    echo winid
enddef

vim9script noclear
echo popup_hide(1002)

vim9script noclear
echo popup_close(1002)

vim9script noclear
echo popup_list()

vim9script noclear
X()
vim9script noclear
Y()

vim9script noclear
unmap <MouseMove>

vim9script noclear
unmap <LeftRelease>

################################################################################
var ruler0 = '0         1         2         3         4         5         6         7         8         9         10        11        12        13        14        15        16         '
var ruler  = '012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890'

if false
    echo ruler0
    echo ruler
    DumpHud(6)

    echo 'layout_offset:' layout_offset  
    echo 'actions_offset:' actions_offset  

    # just the offset
    echo match(modes_section[1], '\v \[g\]')
    echo match(modes_section[1], '\v \[c\]')
    echo matchstrpos(modes_section[1], '\v \[g\]')
    echo matchstrpos(modes_section[1], '\v \[c\]')
    #echo searchpos(modes_section[1], '\v \[g\]')

    echo command_markers[0]
    echo ruler0
    echo ruler
endif
################################################################################

def DumpProps(props: list<dict<any>>)
    for d in props
        echo d
    endfor
enddef

vim9script noclear
echo ruler0
echo ruler
var cmd_props = prop_list(1, {bufnr: hudbufnr, end_lnum: -1, types: [prop_action]})
DumpProps(cmd_props)

# vim:ts=8:sts=4: