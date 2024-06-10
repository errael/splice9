vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

# NOTE: simplification/rewrite when vim9 classes. "class Mode"
#   TODO:   HUD query what commands are allowed
#           current mode, 
#           'o','r','1','2'; 'u'/'u1'-'u2'; diffs-on/off
#           cur-diff (should there be a diff diagram? highlight in layout)
#
# TODO: o, r, 1, 2 are not always valid, maybe grey when not valid
# TODO: other items might be subject to greying out,
# TODO: for example, diffs may not be valid in loupe mode.
# TODO: in layout diagram, highlight which files are part of diff

export const hud_name = '__Splice_HUD__'

import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/with.vim') as i_with
import autoload Rlib('util/strings.vim') as i_strings
import autoload './util/keys.vim' as i_keys
import autoload './util/ui.vim' as i_ui
import autoload './util/windows.vim'
import autoload '../splice.vim'
import autoload './modes.vim' as i_modes

import "../../../plugin/splice.vim" as i_plugin
const splice9_string_version = i_plugin.splice9_string_version 

# highlights used on the HUD and in its text properties

var hl_label: string    = splice.hl_label
var hl_sep: string      = splice.hl_sep
var hl_command: string  = splice.hl_command
var hl_rollover: string = splice.hl_rollover
var hl_active: string   = splice.hl_active
var hl_diff: string     = splice.hl_diff

if exists('&mousemoveevent')
    &mousemoveevent = true
endif

const Pad = i_strings.Pad
const Replace = i_strings.Replace
const ReplaceBuf = i_strings.ReplaceBuf

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
# actions[name] = [ lnum, col0, col1, id ]
# id is used for prop_add
var actions: dict<list<number>>
# actions_ids[id] === actions[actions_ids[id]][3]
# which lets found property map to action name
var actions_ids: dict<string>
var actions_id_next = 1
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

const local_commands_popup = 'DisplayCommandsPopup'

#
# There are local_cmds, these are ui related
# and handled within the HUD.
#
const local_ops: dict<func> = {
    ['Splice' .. local_commands_popup]: () => call(local_commands_popup, [])
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


def ExecuteCommand(cmd: string, id: number)
    RestoreWinPos()
    var splice_cmd = 'Splice' .. cmd
    var Flocal = local_ops->get(splice_cmd, null_function)
    if Flocal != null
        i_log.Log(() => '===EXECUTE LOCAL UI===: ' .. splice_cmd)
        Flocal()
    else
        i_modes.ModesDispatch(splice_cmd)
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

# Allocate and return the id associated with the action command
def AddActionPropId(actKey: string): number
    var id = actions_id_next
    actions_id_next += 1
    actions_ids[id] = actKey
    return id
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
                actions_offset + result[2] + 1,
                AddActionPropId(actKey) ]

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
        t_actions[actKey] = [ lino, col, col + v.m_len, AddActionPropId(actKey) ]
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
const prop_diff = 'prop_diff'

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
    var props_diff = {
        highlight: hl_diff,
        priority: 100,
        combine: false,
    }
    props_com->extend(d)
    props_roll->extend(d)
    props_lab->extend(d)
    props_sep->extend(d)
    props_act->extend(d)
    props_diff->extend(d)

    prop_type_add(prop_action, props_com)
    prop_type_add(prop_rollover, props_roll)
    prop_type_add(prop_label, props_lab)
    prop_type_add(prop_sep, props_sep)
    prop_type_add(prop_active, props_act)
    prop_type_add(prop_diff, props_diff)

    did_action_props = true
enddef

# StartupInit doesn't depend on hudbnr.
# This is only done once during startup
var did_init_1 = false
def StartupInit()
    if did_init_1 | return | endif
    FindMaxLayoutWidth()

    layout_offset = modes_section[0]->len()  + sep->len()
    actions_offset = layout_offset + layout_width + sep->len()
    lockvar layout_offset
    lockvar actions_offset

    base_actions = BuildBaseActions()

    # The UseHunk1 location is also used for UseHunk
    # Remove any UseHunk from base actions
    # dicts: one for UsingHunk[12] and one for UseHunk
    var tmp = base_actions->remove(u_h1)
    hunk_action2[u_h1] = tmp
    hunk_action1[u_h] = tmp->copy()
    hunk_action1[u_h][3] = AddActionPropId(u_h)

    tmp = base_actions->remove(u_h2)
    hunk_action2[u_h2] = tmp

    # add the displayed name for UseHunk
    command_display_names[u_h] = matchlist(u_h_name, '\v.*:\s+(.*)')[1]

    # add some local UI commands
    base_actions[local_commands_popup] = [ 1,
        actions_offset + 1,
        actions_offset + 1 + label_commands->len(),
        AddActionPropId(local_commands_popup) ]

    lockvar! base_actions
    lockvar! hunk_action2
    lockvar! hunk_action1
    lockvar! command_display_names
    lockvar! actions_ids

    did_init_1 = true
enddef

################################################################
#
# create the HUD, recreated for each major state change
#

# Add the action textprop to each command in HUD.
def HighlightActions(bnr: number)
    var props = {type: prop_action, bufnr: bnr, all: true}
    prop_remove(props)

    for [ line, start, end, id ] in actions->values()
        props.end_col = end
        props.id = id
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

# In the layout area, highlight each matching label.
# Keep it simple, assume label only appears at most once in HUD.
# HUD is current buffer.
def HighlightDiffLabelsInLayout(labels: list<string>)
    var props = {type: prop_diff, all: true}
    prop_remove(props)
    for label in labels
        setpos('.', [0, 1, 1, 0])   # current buffer
        var [line, col] = label->searchpos('W')
        if line != 0
            if col >= layout_offset && col < layout_offset + layout_width
                props.length = len(label)
                prop_add(line, col, props)
            else
                i_log.Log(() => printf("DiffLabel '%s' wrong area %d,%d",
                    label, line, col), 'error')
            endif
        else
            i_log.Log(() => printf("DiffLabel '%s' not found", label), 'error')
        endif
    endfor
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
# Main
#

var hudbnr: number = -1

export def UpdateHudStatus()
    var status = splice.GetStatusDiffScrollbind()   # bounce HACK
    var diffs = splice.GetDiffLabels()              # bounce HACK
    var bnr = hudbnr
    #var bnr = _bnr ?? bufnr(hud_name)
    i_with.With(windows.Remain(), (_) => {
        windows.Focus(bufwinnr(bnr))
        i_with.With(i_with.ModifyBufEE.new(bnr), (_) => {
            i_log.Log(() => printf("UpdateHudStatus: bnr %d, [diff, sbind]: %s, diffs: %s",
                bnr, status, diffs))

            var status_char = status[0] ? '*' : ' '
            var act = actions['DiffOff']
            ReplaceBuf(bnr, act[0], act[1] + 2, status_char)
            status_char = status[1] ? '*' : ' '
            act = actions['Scroll']
            ReplaceBuf(bnr, act[0], act[1] + 2, status_char)
            HighlightDiffLabelsInLayout(diffs)
        })
    })
enddef

#
# This is invoked when the HUD is the current buffer
#
export def DrawHUD(mode: string, layout: number,
        vari_files: list<string>)

    var bnr = bufnr(hud_name)
    i_log.Log(() => printf("DrawHUD: mode: '%s', layout %d, vari_files %s, bnr %d",
        mode, layout, vari_files, bnr))

    if bnr < 0
        throw 'HUD buffer not found'
    endif

    if hudbnr < 0
        hudbnr = bnr
    endif

    if hudbnr != bnr
        throw 'HUD buffer changed'
    endif

    StartupInit() # Does stuff first time called

    InitHudBuffer()
    var hud_lines = BuildHud(mode, layout, vari_files)

    i_with.With(i_with.ModifyBufEE.new(hudbnr), (_) => {
        setline(1, hud_lines)
    })

    HudActionsPropertiesAndHighlights(mode, bnr)
    RefreshMouseCache()
enddef

def InitHudBuffer()
    &swapfile = false
    &modifiable = false
    &buflisted = false
    &buftype = 'nofile'
    &undofile = false
    &list = false
    &filetype = 'splice'        # splice filetype not used
    &wrap = false
    resize 3
    &winfixheight = true
    wincmd =
enddef

#
# The HUD has just been drawn.
#
def HudActionsPropertiesAndHighlights(mode: string, bnr: number)
    unlockvar! actions
    actions = base_actions->copy()
    if mode == 'grid'
        actions->extend(hunk_action2)   # two 'use' actions for 'grid'
    else
        # not Grid, UseHunk replace UseHunk1, erase UseHunk2
        i_with.With(i_with.ModifyBufEE.new(bnr), (_) => {
            # blank, or change the name, of the first use item
            var tmp = hunk_action2[u_h1]
            if mode == 'loupe'      # no action for 'loupe'
                ReplaceBuf(bnr, tmp[0], tmp[1], repeat(' ', len(u_h_name)))
            else                    # one action for 'compare'/'path'
                actions->extend(hunk_action1)
                ReplaceBuf(bnr, tmp[0], tmp[1], u_h_name)
            endif
            # blank the second use item
            tmp = hunk_action2[u_h2]
            ReplaceBuf(bnr, tmp[0], tmp[1], repeat(' ', len(u_h_name)))
        })
    endif
    lockvar! actions

    AddHeaderProps({bufnr: bnr})
    HighlightActions(bnr)
    HighlightLabels(bnr)
    HighlightMode(mode, bnr)
    UpdateHudStatus()

    # only map click release in hud
    nnoremap <buffer><special> <LeftRelease> <ScriptCmd>Release()<CR>

    # Can not lock <MouseMove> to the buffer, because rollover moves
    # would not be detected when the vim focus is in a different buffer.
    nnoremap <special> <MouseMove> <ScriptCmd>Move()<CR>
enddef

################################################################
#
# Mouse rollover/click
# Interactive
#

# The action name currently highlighted.
var current_hud_rollover = null_string

# NOTE: if return needs to differentiate wrong window
#       then could return null vs []
# NOTE: <buffer> <LeftRelease> works, but <buffer> <MouseMove>
#        doesn't work, so must do bnr != hudbnr

# Return null or action command name
def GetActionUnderMouse(mpos: dict<number>): string
    var mpos_line = mpos.line
    if winbufnr(mpos.winid) != hudbnr || mpos.line == 0
        return null_string
    endif
    var mpos_col = mpos.column

    # prop_find never has to look far in the HUD; always fast in this situation.
    var prop = prop_find({type: prop_action, bufnr: hudbnr,
        lnum: mpos_line, col: mpos_col})

    var actKey = null_string
    if prop->has_key('id')
        # check if prop covers the mouse, optim since started search at col
        if mpos_line == prop.lnum && mpos_col >= prop.col
            actKey = actions_ids[prop.id]
        endif
    endif

    return actKey
enddef

# Mouse click, execute action
def Release()
    var actKey = getmousepos()->GetActionUnderMouse()
    #echomsg string(item) ####################################
    if actKey != null
        ExecuteCommand(actKey, 0)
    else
        # Click in hud that's not a command. Forget last position
        ClearWinPos()
    endif
enddef

# Mouse move, handle command button rollover
def Move()
    var actKey = getmousepos()->GetActionUnderMouse()
    if current_hud_rollover != null
        if current_hud_rollover == actKey
            # echo 'cache hit:' item
            return
        else
            prop_remove({type: prop_rollover, bufnr: hudbnr, all: true},
                actions[current_hud_rollover][0])
            current_hud_rollover = null_string
        endif
    endif
    if actKey != null
        var [ line, start, end; rest ] = actions[actKey]
        prop_add(line, start,
            {end_col: end, type: prop_rollover, bufnr: hudbnr})
        current_hud_rollover = actKey
    endif
enddef

# This is only for after replacing the hud lines with new hud lines
def RefreshMouseCache()
    current_hud_rollover = null_string
    Move()
enddef

# for displaying mappings in a popup
export def CreateCurrentMappings(): list<string>
    # create a separate list for each column
    var act_keys: list<string>
    var defaults: list<string>
    var mappings: list<string>
    var act_names: list<string>
    def AddBlanks(blank_mapping = true)
        defaults->add('')
        act_names->add('')
        act_keys->add('')
        if blank_mapping
            mappings->add('')
        endif
    enddef

    # ['Grid', ['<M-x>', '<M-g>'], 'g']
    defaults->add('default')
    act_names->add('command')
    act_keys->add('id')
    mappings->add('shortcut')
    #AddBlanks()
    for mappings_item in i_keys.MappingsList()->i_keys.AddSeparators(() => [])
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
                    AddBlanks(false)
                endif
                first_ming = false
            endfor
        else
            AddBlanks()
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

def DisplayCommandsPopup()
    var text = CreateCurrentMappings()
    i_ui.PopupMessage(text, 'Shortcuts (Splice9 ' .. splice9_string_version .. ')', 1)
enddef

