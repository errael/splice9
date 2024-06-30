vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload '../../splice.vim'
import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/ui.vim') as i_rui
import autoload Rlib('util/strings.vim') as i_strings

export def ConfigureUiHighlights()
    i_rui.ConfigureUiHighlights({
        heading: splice.hl_heading,
        popup: splice.hl_popup,
        alert_popup: splice.hl_alert_popup,
    })
enddef

export def SplicePopupAlert(msg: list<string>, title: string, center: bool = true)
    i_log.Log(() => msg->join(';'))
    i_rui.PopupAlert(center ? i_strings.Pad(msg, 'c', - i_rui.MIN_POPUP_WIDTH) : msg, title)
enddef

# vim:ts=8:sts=4:
