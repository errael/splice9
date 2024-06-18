vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload './util/keys.vim' as i_keys
import autoload './util/ui.vim' as i_ui
import autoload Rlib('util/strings.vim') as i_strings
import autoload Rlib('util/log.vim') as i_log

# at_mouse - defaults to false
export def DisplayTextPopup(text: list<string>, extras: dict<any> = null_dict)
    i_ui.PopupMessage(text, extras)
enddef

# map winid to list of properties it contains
var properties_map: dict<list<string>>

# RIGHT NOW, state values are always bool, in the future might have other things
# at_mouse - defaults to true
export def DisplayPropertyPopup(properties: list<string>,
                                state: dict<any>,
                                extras: dict<any> = {}): number
    if !extras->has_key('at_mouse')
        extras.at_mouse = true
    endif

    # Can't remove 'close' with popup_setoptions
    # Insure no 'X' to dismiss. Clicking caused weird selections.
    extras.no_close = true

    # TODO: should probably invoke something like i_ui.PopupDialog()
    var winid = i_ui.PopupProperties(FormattedProperties(properties, state), extras)
    popup_setoptions(winid, { filter: PropertyDialogClickOrClose })
    properties_map[winid] = properties
    i_log.Log(() => printf("DisplayPropertyPopup: %s %s", winid, properties_map))
    return winid
enddef

# NOTE: always returning true prevents border drag
def PropertyDialogClickOrClose(winid: number, key: string): bool
    # TODO: why The check for RET/NL ends up causing window scroll
    #if key == "\r" || key == "\n"
    #    return false
    #endif

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
# TODO: maybe should precede property with '*'
#       or something so that arbitrary text can be easily included.
def FormattedProperties(properties: list<string>, state: dict<any>): list<string>
    return properties->mapnew((_, val) =>
        val->empty() ? ''
            : printf('[%s] %s', state[val] ? 'X' : ' ', val)
    )
enddef

# Sets of radio buttons

var radio_btn_groups: list<list<string>> = [ ]

export def AddRadioBtnGroup(radio_btn_group: list<string>)
    if radio_btn_groups->index(radio_btn_group) < 0
        i_log.Log(() => printf("AddRadioBtnGroup: %s", radio_btn_group))
        radio_btn_groups->add(radio_btn_group)
        PopulateRadioButtons()

    endif
enddef

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
            if mp.line >= 1 && mp.line <= len(property_list)
                var s = bnr->getbufoneline(mp.line)

                # skip line if doesn't look like a property "[ ]"/"[X]"
                if len(s) <= 4 || s[0] != '[' || s[2] != ']'
                    return false
                endif
                if ! HandleRadioButton(winid, bnr, mp.line)
                    FlipProperty(bnr, mp.line)
                endif
                return true
            endif
        endif
    endif
    return false
enddef

# return state for each property
export def GetPropertyState(winid: number): dict<any>
    var state: dict<any>
    if winid != 0
        var bnr = getwininfo(winid)[0].bufnr
        for s in bnr->getbufline(1, '$')
            if len(s) > 4 && s[0] == '[' && s[2] == ']'
                state[s[4 : ]] = s[1] != ' '
            endif
        endfor
    endif
    return state
enddef

# for displaying mappings in a popup
export def CreateCurrentMappings(command_display_names: dict<string>): list<string>
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

