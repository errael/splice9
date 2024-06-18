vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload './util/keys.vim' as i_keys
import autoload './util/ui.vim' as i_ui
import autoload Rlib('util/strings.vim') as i_strings
import autoload Rlib('util/log.vim') as i_log

import autoload "../../../plugin/splice.vim" as i_plugin

export def DisplayCommandsPopup(command_display_names: dict<string>)
    var options: dict<any> = {}
    var text = CreateCurrentMappings(command_display_names)
    i_ui.PopupMessage(text, 'Shortcuts (Splice9 ' .. i_plugin.splice9_string_version .. ')', 1)
enddef

#export def DisplayDiffOptsPopup(at_mouse: bool = true, tweak_options: dict<any> = {}): number
#    if at_mouse
#        # put the dialog at the mouse position
#        var mp = getmousepos()
#        tweak_options->extend({line: mp.screenrow, col: mp.screencol})
#    endif
#    var winid = i_ui.PopupProperties(FormattedDiffOpts(), 'Diff Options',
#        v:none, tweak_options)
#    popup_setoptions(winid, { filter: PropertyDialogClickOrClose })
#    return winid
#enddef

# map winid to list of properties it contains
var properties_map: dict<list<string>>

export def DisplayPropertyPopup(properties: list<string>,
                                enabled: list<string>,
                                at_mouse: bool = true,
                                tweak_options: dict<any> = {}): number
    if at_mouse
        # put the dialog at the mouse position
        var mp = getmousepos()
        tweak_options->extend({line: mp.screenrow, col: mp.screencol})
    endif
    var winid = i_ui.PopupProperties(FormattedProperties(properties, enabled),
                                     'Diff Options', v:none, tweak_options)
    popup_setoptions(winid, { filter: PropertyDialogClickOrClose })
    properties_map[winid] = properties
    i_log.Log(() => printf("DisplayPropertyPopup: %s %s", winid, properties_map))
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

export def PropertyDialogClose(winid: number)
    i_log.Log(() => printf("PropertyDialogClose: %s %s", winid, properties_map))
    properties_map->remove(winid)
enddef


# Put the checkbox "[ ] " or "[X] " in front of each diff options.
#
# TODO: maybe need to precede property with '*'
#       or something so that arbitrary text can be easily included.
def FormattedProperties(properties: list<string>, enabled: list<string>): list<string>
    #var cur_opts = &diffopt->split(',')
    #i_log.Log(() => printf("FormattedProperties: &diffopt= '%s', cur_opts= %s",
    #    &diffopt, cur_opts))
    return properties->mapnew((_, val) =>
        val->empty() ? ''
            : printf('[%s] %s', enabled->index(val) >= 0 ? 'X' : ' ', val)
    )
enddef

#
# TODO: how about "AddRadioBtnGroup(), 
#

# Sets of radio buttons

export def AddRadioBtnGroup(radio_btn_group: list<string>)
    if radio_btn_groups->index(radio_btn_group) < 0
        i_log.Log(() => printf("AddRadioBtnGroup: %s", radio_btn_group))
        radio_btn_groups->add(radio_btn_group)
        PopulateRadioButtons()

    endif
enddef

var radio_btn_groups: list<list<string>> = [ ]

# The radio buttons with the group they belond to
var radioButtons: dict<list<string>> = {}

def PopulateRadioButtons()
    for l in radio_btn_groups
        for opt in l
            #echo 'ADD RADIO:' opt l
            radioButtons[opt] = l
        endfor
    endfor
    #echo 'RADIO BUTTONS:' radioButtons
enddef

# If its a radio button, handle it and return true.
# line must be a valid button
def HandleRadioButton(winid: number, bnr: number, line: number): bool
    var s = bnr->getbufoneline(line)
    var opt = s[4 : ]
    var l = radioButtons->get(opt, null_list)
    if l->empty()
        return false
    endif
    for opt2 in l
        if opt == opt2
            SetProperty(bnr, line, true)
        else
            var property_list = properties_map->get(winid, null_list)
            if property_list != null
                SetProperty(bnr, property_list->index(opt2) + 1, false)
            endif
        endif
    endfor
    return true
enddef

# line must be a valid button
def SetProperty(bnr: number, line: number, enable: bool)
    var s = bnr->getbufoneline(line)
    s = (enable ? '[X]' : '[ ]') .. s[3 : ]
    s->setbufline(bnr, line)
enddef

# line must be a valid button
def FlipProperty(bnr: number, line: number)
    var s = bnr->getbufoneline(line)
    var enabled = s[1] != ' '
    SetProperty(bnr, line, !enabled)
enddef

# If a boolean property is clicked, then flip it to other state
def CheckClickProperty(winid: number, mp: dict<number>): bool
    if mp.winid == winid
        var property_list = properties_map->get(winid, null_list)
        if property_list != null
            var bnr = getwininfo(winid)[0].bufnr
            #if mp.line >= 1 && mp.line <= getbufinfo(bnr)[0].linecount
            if mp.line >= 1 && mp.line <= len(property_list)
                var s = bnr->getbufoneline(mp.line)
                # TODO: also verify that "s" has '[' and ']'
                if s->empty()
                    return false
                endif
                if ! HandleRadioButton(winid, bnr, mp.line)
                    FlipProperty(bnr, mp.line)
                endif

                #var s = bnr->getbufoneline(mp.line)
                #var enabled = s[1] != ' '
                #echom enabled s
                # flip the checkmark

                #s = (enabled ? '[ ]' : '[X]') .. s[3 : ]
                #s->setbufline(bnr, mp.line)
                #FlipProperty(bnr, mp.line)
                return true
            endif
        endif
    endif
    return false
enddef

# return [ [enabled props], [disabled_props] ]
export def GetPropertyState(winid: number): list<list<string>>
    var enabled_props: list<string> = []
    var disabled_props: list<string> = []
    if winid != 0
        enabled_props = []
        var bnr = getwininfo(winid)[0].bufnr
        for s in bnr->getbufline(1, '$')
            if len(s) > 4 && s[0] == '[' && s[2] == ']'
                if s[1] == ' '
                    disabled_props->add(s[4 : ])
                else
                    enabled_props->add(s[4 : ])
                endif
            endif
        endfor
    endif
    return [ enabled_props, disabled_props ]
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

