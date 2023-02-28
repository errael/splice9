vim9script

import autoload './vim_assist.vim'
import autoload './log.vim'
const Log = log.Log

var KeepWindowEE = vim_assist.KeepWindowEE

# TODO: does it make more sense to use winid everywhere (rather than winnr)

export def Focus(wnr: number)
    var wid = win_getid(wnr)
    Log(() => 'WIN: ' .. string(wnr), 'focus')

    var err = wid == 0
    if ! err
        err = ! win_gotoid(wid) 
    endif
    if err
        Log(() => printf("ERROR: Focus: wnr %d", wnr))
    endif
enddef

export def Close_all()
    Focus(1)
    :only
enddef

export def Split()
    :split
enddef

export def Vsplit()
    :vsplit
enddef

export def Currentnr(): number
    return winnr()
enddef

export def Pos(): list<number>
    return getpos('.')
enddef

export def Remain(): any
    return KeepWindowEE.new()
enddef

