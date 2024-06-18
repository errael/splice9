vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload '../../splice.vim'
import autoload Rlib('util/log.vim') as i_log

# dismiss on any key
def FilterCloseAnyKey(winid: number, key: string): bool
    popup_close(winid)
    return true
enddef

export def PopupMessage(msg: list<string>, title: string, header_line = -1): number
    var options: dict<any> = {
        close: 'click',
    }
    return PopupMessageCommon(msg, title, header_line, options)
enddef

export def PopupProperties(msg: list<string>, title: string = '', header_line = -1,
        tweak_options: dict<any> = null_dict): number
    var options: dict<any> = {
        close: 'button',
        filter: PropertyDialogClickOrClose,
        mapping: true,   # otherwise don't get <ScriptCmd>
    }
    options->extend(tweak_options)
    return PopupMessageCommon(msg, title, header_line, options)
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

prop_type_add('popupheading', {highlight: splice.hl_heading})

# msg - popup's buffer contents
# title - the popup title property
# header_line - highlight this buffer line with hl_heading
# tweak_options - 
def PopupMessageCommon(msg: list<string>,
                                title: string = '',
                                header_line: number = -1,
                                tweak_options: dict<any> = null_dict): number

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
    options->extend(tweak_options)

    if ! empty(title)
        options.title = ' ' .. title .. ' '
    endif

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
