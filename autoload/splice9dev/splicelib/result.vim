vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload '../splice.vim'
import autoload './modes.vim' as i_modes
import autoload './settings.vim' as i_settings

import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/stack.vim') as i_stack
import autoload './util/windows.vim'
import autoload './util/bufferlib.vim' as i_buflib
import autoload './util/ui.vim' as i_ui
import autoload './util/search.vim' as i_search

const CONFLICT_MARKER_START = '<<<<<<<'
const CONFLICT_MARKER_MARK  = '======='
const CONFLICT_MARKER_END   = '>>>>>>>'

var CONFLICT_MARKER_START_PATTERN = '^' .. CONFLICT_MARKER_START
var CONFLICT_MARKER_MARK_PATTERN  = '^' .. CONFLICT_MARKER_MARK
var CONFLICT_MARKER_END_PATTERN   = '^' .. CONFLICT_MARKER_END

export class Conflict
    var id: number
    var left: list<string> = []
    var right: list<string> = []
    def new(this.id)
    enddef

endclass

# Have this hear so we dont' export more than needed.
class ConflictLocal extends Conflict
    var local = 13
    def Lock()
        this.LockL(this.left)
        this.LockL(this.right)
    enddef

    def LockL(l: list<string>)
        lockvar l
    enddef
endclass

var conflicts: list<ConflictLocal> = []

#
# Replace the conflict mark under the cursor with the reconstructed conflict
# text Cursor must be on a conflict marker in the result buffer.
#
export def RestoreOriginalConflictText()
    var bnr: number = bufnr()
    if i_buflib.buffers.result.bufnr != bnr
        i_ui.SplicePopupAlert(["\"Result\" file not focused"], 'Use Both')
        return
    endif

    var lino: number = getcurpos()[1]
    var marker = matchlist(getline(lino), i_search.CONFLICT_PATTERN)
    if marker->empty()
        i_ui.SplicePopupAlert(["Cursor not on Conflict line"], 'Use Both')
        return
    endif

    append(lino, GetConflictText(marker[1]->str2nr()))
    # delete splice9's conflict marker from the buffer
    bnr->deletebufline(lino)
enddef
# In RestoreOriginalConflictText, could append pieces directly into buffer, in
# reverse order, and avoid creating temp list. But guessing there's additional
# overhead per buffer modification
#       - bigger number of lines to shuffle pointers
#       - undo 

#
# Return the reconstructed conflict text
#
def GetConflictText(n: number): list<string>
    var c = conflicts[n - 1]
    var s: list<string>
    s->add(CONFLICT_MARKER_START)
    s->extend(c.left)
    s->add(CONFLICT_MARKER_MARK)
    s->extend(c.right)
    s->add(CONFLICT_MARKER_END)
    return s
enddef

# Scan the merge file, save the conflict data; replace conflict data
# conflict marker that references the conflict.
# For example "===== :3:" is index 2 (3 - 1) into the "conflicts" list.
def Process_result()
    i_log.Log('Process_result()', '', true, ':ls')
    windows.Close_all()
    i_log.Log('Process_result() after Close_all', '', true, ':ls')
    i_buflib.buffers.result.Open()
    i_log.Log('Process_result() after Open', '', true, ':ls')

    var cur_hunk: list<string>

    var lines = []
    var in_conflict = false
    for line in getline(1, '$')
        i_log.Log(line, 'result')
        if in_conflict
            var magic = false
            if line =~ CONFLICT_MARKER_MARK_PATTERN
                lines->add(line .. ' :' .. conflicts->len() .. ':')
                cur_hunk = conflicts[-1].right
                magic = true
            endif
            if line =~ CONFLICT_MARKER_END_PATTERN
                in_conflict = false
                conflicts[-1].Lock()
                magic = true
            endif
            if ! magic
                cur_hunk->add(line)
            endif
            i_log.Log(() => 'DISCARD1: ' .. line, 'result')
            continue
        endif

        if line =~ CONFLICT_MARKER_START_PATTERN
            in_conflict = true
            conflicts->add(ConflictLocal.new(conflicts->len() + 1))
            cur_hunk = conflicts[-1].left
            i_log.Log(() => 'DISCARD2: ' .. line, 'result')
            continue
        endif

        lines->add(line)
    endfor

    #echom conflicts

    deletebufline('', 1, '$')
    setbufline('', 1, lines)

enddef

def Setlocal_fixed_buffer(b: i_buflib.Buffer, filetype: string)
    b.Open()
    # the following are buffer local
    &swapfile = false
    &modifiable = false
    &filetype = filetype
    # wrap is window local
    i_settings.Set_cur_window_wrap()
enddef

def Setlocal_buffers()
    i_buflib.buffers.result.Open()
    var filetype = &filetype

    Setlocal_fixed_buffer(i_buflib.buffers.original, filetype)
    Setlocal_fixed_buffer(i_buflib.buffers.one, filetype)
    Setlocal_fixed_buffer(i_buflib.buffers.two, filetype)

    i_buflib.buffers.result.Open()
    i_settings.Set_cur_window_wrap()
enddef

export def Init()
    Process_result()
    i_log.Log('Init() after Process_result', '', true, ':ls')

    # funny dance, can't do CreateHudBuffer until after Process_result()
    i_buflib.buffers.CreateHudBuffer()
    i_log.Log('Init() after buffers.CreateHudBuffer()', '', true, ':ls')

    Setlocal_buffers()
    i_log.Log('Init() after Setlocal_buffers()', '', true, ':ls')
    &hidden = true

    var initial_mode = i_settings.Setting('initial_mode')->tolower()
    i_modes.ActivateInitialMode(initial_mode)
enddef

