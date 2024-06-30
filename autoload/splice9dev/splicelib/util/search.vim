vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload './ui.vim' as i_ui
import autoload '../../splice.vim'
import autoload './bufferlib.vim' as i_buflib
import autoload Rlib('util/with.vim') as i_with
import autoload Rlib('util/log.vim') as i_log

#
# export def HighlightConflict()
# export def MoveToConflict(forw: bool = true)
# export def MoveToFirstConflict()
#

export const id_cursors = 998
const id_cur_conflict = 999

export const pri_hl_cursors = 200
const pri_hl_cur_conflict = 110
const pri_hl_conflict = 100

# The conflict index is in a capture group.
export const CONFLICT_PATTERN = '\m^=======* :\(\d\+\):$'
const FIRST_CONFLICT_PATTERN = '\m^=======* :1:$'

#
# Auto Commands, autocmd
#

var didInit: bool
export def Init()
    if didInit
        return
    endif
    didInit = true
    augroup search
        autocmd!
        autocmd CursorMoved * CursorMoved()
        autocmd BufEnter * BufEnter()
    augroup END
enddef

def CursorMoved()
    if i_buflib.buffers.result.Winnr() == winnr()
        CurrentConflictHighlight()
    endif
enddef

# Clear any current conflict highlight when changing windows
def BufEnter()
    #i_log.Log(printf("BUF WIN ENTER wnr %d, bnr %d", winnr(), bufnr()))
    ClearHighlight(id_cur_conflict, winnr())
    # and re-check
    CursorMoved()
enddef

#def IsOnConflict(): bool
#    return match(s, CONFLICT_PATTERN) >= 0
#enddef


export def ClearHighlight(id: number, win: number)
    #i_log.Log(printf('CLEAR CONFLICT HIGHLIGHT w-%d b-%d', winnr(), bufnr()))
    try
        matchdelete(id, win)
    catch /E957:\|E803:/
        #echom 'winnr():' winnr() 'delete():' v
    endtry
enddef

def CurrentConflictHighlight()
    var lino: number = getcurpos()[1]
    var s = getline(lino)
    ClearHighlight(id_cur_conflict, winnr())
    # Get out fastest if there's no chance.
    if s[0] != '='
        return
    endif

    if match(s, CONFLICT_PATTERN) < 0
        return
    endif

    matchaddpos(splice.hl_cur_conflict, [lino], pri_hl_cur_conflict, id_cur_conflict)

enddef

#
# Highlight all the conflicts in this window
#
export def HighlightAllConflicts()
    matchadd(splice.hl_conflict, CONFLICT_PATTERN, pri_hl_conflict)
enddef


export def MoveToConflict(forw: bool = true)
    var flags = forw ? '' : 'b'

    # the next/prev conflict
    var lino = search(CONFLICT_PATTERN, flags)
    if lino == 0
        i_ui.SplicePopupAlert(["No more conflicts"], '')
    endif
enddef

export def MoveToFirstConflict()
    search(FIRST_CONFLICT_PATTERN, '')
enddef


