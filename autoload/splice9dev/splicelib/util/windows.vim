vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/with.vim') as i_with

# TODO: does it make more sense to use winid everywhere (rather than winnr)

export def Focus(wnr: number)
    var winid = win_getid(wnr)
    # i_log.Log(() => 'WIN: ' .. string(wnr), 'focus')

    var err = winid == 0
    if ! err
        err = ! win_gotoid(winid) 
    endif
    if err
        i_log.Log(() => printf("ERROR: Focus: wnr %d", wnr))
    endif
enddef

export def Close_all()
    Focus(1)
    if getwininfo()->len() > 1
        :only
    endif
enddef

export def Remain(): i_with.WithEE
    return i_with.KeepWindowPosEE.new()
enddef

