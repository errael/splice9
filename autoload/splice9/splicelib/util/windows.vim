vim9script

import autoload './vim_assist.vim'
import autoload './log.vim'
const Log = log.Log

var KeepWindowEE = vim_assist.KeepWindowEE

#if ! testing
#else
#    def Log(s: string, s2: string = ''): void
#        echo s s2
#    enddef
#endif

# TODO: does it make more sense to use winid everywhere (rather than winnr)

export def Focus(wnr: number)
    var wid = win_getid(wnr)
    Log('focus', 'WIN: focus ' .. string(wnr))

    var err = wid == 0
    if ! err
        err = ! win_gotoid(wid) 
    endif
    if err
        Log(printf("ERROR: Focus: wnr %d", wnr))
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

echomsg "SOMEWHERE IN windows.vim"

### finish

### ############################################################################
### 
### finish
### 
### def focus(winnr):
###     log('focus', 'WIN: focus ' + str(winnr)
###             + (' ERROR' if winnr > len(vim.windows) or winnr < 1 else ''))
###     if winnr <= len(vim.windows) and winnr > 0:
###         vim.current.window = vim.windows[winnr-1]
###     #vim.command('%dwincmd w' % winnr)
###     # execute string(winnr) .. 'wincmd w'
### 
### def close_all():
###     focus(1)
###     vim.command('wincmd o')
### 
### def split():
###     vim.command('wincmd s')
### 
### def vsplit():
###     vim.command('wincmd v')
### 
### def currentnr():
###     return vim.current.window.number
###     #return int(vim.eval('winnr()'))
### 
### def pos():
###     return vim.current.window.cursor
### 
### 
### class remain:
###     def __enter__(self):
###         self.curwindow = currentnr()
###         self.pos = pos()
### 
###     def __exit__(self, type, value, traceback):
###         focus(self.curwindow)
###         vim.current.window.cursor = self.pos
### 
