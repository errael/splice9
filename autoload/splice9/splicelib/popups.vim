vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload './util/keys.vim' as i_keys
import autoload './util/ui.vim' as i_ui
import autoload Rlib('util/strings.vim') as i_strings

import "../../../plugin/splice.vim" as i_plugin
const splice9_string_version = i_plugin.splice9_string_version 

#########################################################################
# TODO: this goes in hud. ###############################################
#
# var winid_props: number
# winid_props = DisplayDiffOptsPopup()
# popup_setoptions(winid_props, { callback: PropertyDialogClosing })

# def PropertyDialogClosing(winid: number, result: any): list<string>
#     var enabled_props = GetCheckedProperties(winid)
#     echom 'RESULT:' enabled_props
#     echom enabled_props->join(',')
#     #winid_props = 0
#     return enabled_props
# enddef
# 
# nnoremap <special> <LeftRelease> <ScriptCmd>Release()<CR>
# def Release()
#     var mp = getmousepos()
#     var isProp = CheckClickProperty(winid_props, mp)
#     if ! isProp
#         echo "NOT PROP"
#     endif
# enddef
#########################################################################

export def DisplayCommandsPopup(command_display_names: dict<string>)
    var text = CreateCurrentMappings(command_display_names)
    i_ui.PopupMessage(text, 'Shortcuts (Splice9 ' .. splice9_string_version .. ')', 1)
enddef

export def DisplayDiffOptsPopup(): number
    var winid = i_ui.PopupProperties(FormattedDiffOpts(), 'Diff Options')
    popup_setoptions(winid, { filter: PropertyDialogClickOrClose })
    return winid
enddef

def PropertyDialogClickOrClose(winid: number, key: string): bool
    if key == "\<LeftRelease>"
        var mp = getmousepos()
        var isProp = CheckClickProperty(winid, mp)
    elseif key == 'x' || key == "\x1b"
        popup_close(winid)
    endif
    return true
enddef

# g_diff_translations, after changing do "set syntax=diff"

const diffopts: list<string> =<< trim END
    filler
    iblank
    icase
    iwhite
    iwhiteall
    iwhiteeol
    horizontal
    vertical
    closeoff
    followwrap
    internal
    indent-heuristic
END
#context:{n}
#hiddenoff
#foldcolumn:{n}
#algorithm: myers minimal patience histogram

#
# Put the checkbox "[ ] " or "[X] " in front of each diff options.
#
# NOTE: the number of list elements should not be changed by this function
def FormattedDiffOpts(): list<string>
    var cur_opts = &diffopt->split(',')
    return diffopts->mapnew((_, val) =>
        printf('[%s] %s', cur_opts->index(val) >= 0 ? 'X' : ' ', val))
enddef

# If a boolean property is clicked, then flip it to other state
# Should this take windid as an argument?
def CheckClickProperty(winid: number, mp: dict<number>): bool
    if mp.winid == winid
        if mp.line >= 1 && mp.line <= len(diffopts)
            var bnr = getwininfo(winid)[0].bufnr
            var s = bnr->getbufoneline(mp.line)
            var enabled = s[1] != ' '
            #echom enabled s
            # flip the checkmark
            s = (enabled ? '[ ]' : '[X]') .. s[3 : ]
            s->setbufline(bnr, mp.line)
            return true
        endif
    endif
    return false
enddef

export def GetCheckedProperties(winid: number): list<string>
    var enabled_props: list<string> = null_list
    if winid != 0
        enabled_props = []
        var bnr = getwininfo(winid)[0].bufnr
        for s in bnr->getbufline(1, '$')
            if ! empty(s) && s[1] != ' '
                enabled_props->add(s[4 : ])
            endif
        endfor
    endif
    return enabled_props
enddef

# for displaying mappings in a popup
def CreateCurrentMappings(command_display_names: dict<string>): list<string>
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
    defaults->i_strings.Pad('r')
    act_names->i_strings.Pad('l')
    act_keys->i_strings.Pad('r')
    mappings->i_strings.Pad('l')
    var ret: list<string>
    for i in range(len(mappings))
        ret->add(printf("%s %s %s   %s",
            defaults[i], act_names[i], act_keys[i], mappings[i]))
    endfor
    return ret
enddef

####### DEBUG ###########################################

finish

try
prop_type_add('popupheading', {highlight: 'WildMenu'})
catch
endtry

def PropertyDialogClose(winid: number, key: string): bool
    if char2nr(key) == char2nr("\<ScriptCmd>")
        return false    # wan't these handled
    endif
    if key == 'x' || key == "\x1b"
        popup_close(winid)
        return true
    endif

    return true
enddef

def PopupProperties(msg: list<string>, title: string = '', header_line = -1,
        tweak_options: dict<any> = null_dict): number
    var options: dict<any> = {
        close: 'button',
        filter: PropertyDialogClose,
        mapping: true,   # otherwise don't get <ScriptCmd>
    }
    options->extend(tweak_options)
    return PopupMessageCommon(msg, title, header_line, options)
enddef

def PopupMessageCommon(msg: list<string>, title: string, header_line: number,
        tweak_options: dict<any> = null_dict): number

    var options: dict<any> = {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        border: [],
        padding: [1, 2, 1, 2],
        highlight: 'WildMenu',
        #close: 'click',
        drag: 1,
        #mousemoved: 'any', moved: 'any',
        #moved: [0, 0, 0, 0],
        #mousemoved: [0, 0, 0, 0],
        mapping: false,
        #filter: FilterCloseAnyKey
    }
    options->extend(tweak_options)

    if len(title) > 0
        options.title = ' ' .. title .. ' '
    endif
    #var outmsg = msg + [ '', '(Click on Popup to Dismiss. Drag Border.)' ]
    var outmsg: list<string> = msg->copy()
    if options->get('close', '') == 'click'
        outmsg->extend(['', '(Click on Popup to Dismiss. Drag Border.)' ])
    endif

    var winid = popup_create(outmsg, options)
    var bnr = winid->winbufnr()
    if header_line >= 0
        prop_add(header_line, 1,
            {length: len(msg[0]), bufnr: bnr, type: 'popupheading'})
    endif

    return winid
enddef

#winid_props = PopupProperties(FormattedDiffOpts(), 'Shortcuts (Splice9 ' .. splice9_string_version .. ')', 1)

var winid_props: number
winid_props = DisplayDiffOptsPopup()
popup_setoptions(winid_props, { callback: PropertyDialogClosing })
echo winid_props

