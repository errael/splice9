vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload '../../splice.vim'
import autoload Rlib('util/log.vim') as i_log

prop_type_add('popupheading', {highlight: splice.hl_heading})

#
# The "extra" parameter for PopupMessage() and PopupProperties may contain
#
#       tweak_options - used to extend the options given to popup_create
#       at_mouse: bool - if true popup at mouse; default false
#       header_line: number - >= 1, highlight line with hl_heading


export def PopupMessage(msg: list<string>, extras: dict<any> = {}): number
    AddToTweakOptions(extras, {
        close: 'click',
    })
    return PopupMessageCommon(msg, extras)
enddef

# TODO: should probably be PopupDialog()
export def PopupProperties(msg: list<string>, extras: dict<any> = {}): number
    #var options: dict<any> = {
    AddToTweakOptions(extras, {
        close: 'button',
        filter: PropertyDialogClickOrClose,
        mapping: true,   # otherwise don't get <ScriptCmd>
    })
    return PopupMessageCommon(msg, extras)
enddef

def AddToTweakOptions(extras: dict<any>, tweak_options: dict<any>)
    if !extras->has_key('tweak_options')
        extras.tweak_options = {}
    endif
    extras.tweak_options->extend(tweak_options)
enddef

def PropertyDialogClickOrClose(winid: number, key: string): bool
    if char2nr(key) == char2nr("\<ScriptCmd>")
        return false    # wan't these handled
    endif
    if key == 'x' || key == "\x1b"
        popup_close(winid)
        return true
    endif

    return true
enddef

# dismiss on any key
def FilterCloseAnyKey(winid: number, key: string): bool
    popup_close(winid)
    return true
enddef

# msg - popup's buffer contents
# extras - see top of this file
# return: popup's winid
def PopupMessageCommon(msg: list<string>, extras: dict<any> = {}): number

    var options: dict<any> = {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        border: [],
        padding: [1, 2, 1, 2],
        highlight: splice.hl_popup,
        drag: 1,
        mapping: false,

        #close: 'click',
        #mousemoved: 'any', moved: 'any',
        #moved: [0, 0, 0, 0],
        #mousemoved: [0, 0, 0, 0],
        #filter: FilterCloseAnyKey
    }

    if extras->has_key('tweak_options')
        options->extend(extras.tweak_options)
    endif

    if extras->has_key('at_mouse') && extras.at_mouse
        var mp = getmousepos()
        options->extend({line: mp.screenrow, col: mp.screencol})
    endif

    # Sigh!
    if extras->get('no_close', false)
        options->remove('close')
    endif

    var out_msg: list<string> = msg->copy()
    var append_msgs: list<string>
    if options->get('close', '') == 'click'
        append_msgs->extend(['Click on Popup to Dismiss.',
                            'Drag border to move'])
    endif

    if extras->has_key('append_msgs')
        append_msgs->extend(extras.append_msgs)
    endif

    if !append_msgs->empty()
        out_msg += [''] + append_msgs
    endif

    var winid = popup_create(out_msg, options)
    var bnr = winid->winbufnr()
    if extras->has_key('header_line') && extras.header_line > 0
        prop_add(extras.header_line, 1,
            {length: len(msg[extras.header_line - 1]), bufnr: bnr, type: 'popupheading'})
    endif

    return winid
enddef

export def PopupError(msg: list<string>, other: list<any> = [])

    var options = {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        border: [],
        padding: [1, 2, 1, 2],
        highlight: splice.hl_alert_popup,
        close: 'click',
        mousemoved: 'any', moved: 'any',
        mapping: false, filter: FilterCloseAnyKey
        }
    if len(other) > 0
        options.title = ' ' .. other[0] .. ' '
    endif

    popup_create(msg, options)
enddef

# TODO: may add some kind of "how to close" info in E
#       make E dict<dict<any>>
# TODO: This should not be in log.vim, either import or put popup elsewhere
const E = {
    ENOTFILE: ["Current buffer, '%s', doesn't support '%s'", 'Command Issue'],
    ENOCONFLICT: ["No more conflicts"],
}

export def SplicePopup(e_idx: string, ...extra: list<any>)
    var err = E[e_idx]
    var msg = call('printf', [ err[0] ] + extra)
    i_log.Log(msg)
    PopupError([msg], err[ 1 : ])
enddef

# vim:ts=8:sts=4:
