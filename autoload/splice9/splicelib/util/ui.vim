vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload '../../splice.vim'
import Rlib('util/log.vim') as i_log

const Log = i_log.Log


# dismiss on any key
def FilterCloseAnyKey(winid: number, key: string): bool
    popup_close(winid)
    return true
enddef

prop_type_add('popupheading', {highlight: splice.hl_heading})
export def PopupMessage(msg: list<string>, title: string, header_line = -1)

    var options = {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        border: [],
        padding: [1, 2, 1, 2],
        highlight: splice.hl_popup,
        close: 'click',
        drag: 1,
        #mousemoved: 'any', moved: 'any',
        #moved: [0, 0, 0, 0],
        #mousemoved: [0, 0, 0, 0],
        mapping: false,
        #filter: FilterCloseAnyKey
    }

    if len(title) > 0
        options.title = ' ' .. title .. ' '
    endif
    var outmsg = msg + [ '', '(Click on Popup to Dismiss. Drag Border.)' ]

    var bnr = popup_create(outmsg, options)->winbufnr()
    if header_line >= 0
        prop_add(header_line, 1,
            {length: len(msg[0]), bufnr: bnr, type: 'popupheading'})
    endif
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
    Log(msg)
    PopupError([msg], err[ 1 : ])
enddef

# vim:ts=8:sts=4:
