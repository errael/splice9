vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

#import autoload './ui.vim' as i_ui
import autoload '../../splice.vim'
import autoload '../modes.vim' as i_modes
import autoload './bufferlib.vim' as i_buflib
import autoload Rlib('util/with.vim') as i_with
import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/ui.vim') as i_ui

#
# export def HighlightConflict()
# export def MoveToConflict(forw: bool = true)
# export def MoveToFirstConflict()
#

export const id_cursor_line = 997
export const id_flash_cursors = 998
const id_cur_conflict = 999

const pri_hl_conflict = 100
const pri_hl_cursor_line = 101
const pri_hl_cur_conflict = 102
export const pri_hl_flash_cursor = 110

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

# TODO: is bufenter needed?

# TODO: Could disable search augroup while things are changing in modes.vim.
#       When done, do "CursorMoved()"
# TODO: Does it reduce overhead by keeping some state on what's active?

def CursorMoved()
    CurrentResultConflictHighlight()
    HighlightCursorLineInWindows()
enddef

# Clear any current conflict highlight when changing windows
def BufEnter()
    #i_log.Log(printf("BUF WIN ENTER wnr %d, bnr %d", winnr(), bufnr()))
    ClearHighlight(id_cur_conflict, winnr())
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

def CurrentResultConflictHighlight()
    var bnr = i_buflib.buffers.result.bufnr
    var wnr = bufwinnr(bnr)
    if wnr < 1 || wnr != winnr() && !getwinvar(wnr, '&cursorbind')
        return
    endif

    var lino: number = getcurpos(wnr)[1]
    var s = getbufline(bnr, lino)[0]
    ClearHighlight(id_cur_conflict, wnr)
    # Get out fastest if there's no chance.
    if s[0] != '='
        return
    endif

    if match(s, CONFLICT_PATTERN) < 0
        return
    endif

    matchaddpos(splice.hl_cur_conflict, [lino], pri_hl_cur_conflict,
        id_cur_conflict, {window: wnr})
enddef

# clear id_cursor_line when not in diff mode
export def NotifyDiffModeOff(is_off: bool)
    if is_off
        for wnr in range(2, 2 + i_modes.GetNumberOfWindows() - 1)
            ClearHighlight(id_cursor_line, wnr)
        endfor
    endif
enddef

# TODO: Can do better, maybe. Not worth it.
# One try would be to use getmatches() and see the the target line is already
# highlighted.

# HighlightCursorLineInWindows if diff on
def HighlightCursorLineInWindows()
    if i_modes.GetStatus_Diff_Scrollbind()[0]
        for wnr in range(2, 2 + i_modes.GetNumberOfWindows() - 1)
            ClearHighlight(id_cursor_line, wnr)
            var lino: number = getcurpos(wnr)[1]
            matchaddpos(splice.hl_cursor_line, [lino], pri_hl_cursor_line,
                id_cursor_line, {window: wnr})
        endfor
    endif
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
        i_ui.PopupAlert(["No more conflicts"], '')
    endif
enddef

export def MoveToFirstConflict()
    search(FIRST_CONFLICT_PATTERN, '')
enddef


