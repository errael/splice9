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

const pri_hl_conflict = 100
const pri_hl_cur_conflict = 110

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
    ClearConflictHighlight()
    # and re-check
    CursorMoved()
enddef

#def IsOnConflict(): bool
#    return match(s, CONFLICT_PATTERN) >= 0
#enddef

const id_cur_conflict = 999

def ClearConflictHighlight()
    #i_log.Log(printf('CLEAR CONFLICT HIGHLIGHT w-%d b-%d', winnr(), bufnr()))
    try
        matchdelete(id_cur_conflict)
    catch /E957:\|E803:/
        #echom 'winnr():' winnr() 'delete():' v
    endtry
enddef

def CurrentConflictHighlight()
    var lino: number = getcurpos()[1]
    var s = getline(lino)
    ClearConflictHighlight()    # could use flag to try and avoid, too messy
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
# Highlight all the conflicts in this buffer
#
export def HighlightAllConflicts()
    matchadd(splice.hl_conflict, CONFLICT_PATTERN, pri_hl_conflict)
enddef


export def MoveToConflict(forw: bool = true)
    var flags = forw ? '' : 'b'

    # the next/prev conflict
    var lino = search(CONFLICT_PATTERN, flags)
    if lino == 0
        i_ui.SplicePopupKey('ENOCONFLICT')
    endif
enddef

export def MoveToFirstConflict()
    search(FIRST_CONFLICT_PATTERN, '')
enddef


finish


################################################################
################################################################
################################################################

# Following of historical interest up for deletion

# TODO: props don't work interacting with diff coloration
const use_props = false

const CONFLICT_MARKER_MARK = '======='


        #autocmd ModeChanged * ModeChanged()
        #autocmd BufWinEnter * BufWinEnter()
        #autocmd WinNew * WinNew()
        #autocmd WinEnter * WinEnter()

def ModeChanged()
    if i_buflib.buffers.hud.Winnr() == winnr()
        # Prevent (quit) select mode in HUD.
        if match(v:event.new_mode, '[sS]') >= 0
            i_log.Log(() => printf("ModeChanged to SELECT: %s", v:event.new_mode))
            execute ":normal \<ESC>"
        endif
    endif
enddef

def WinEnter()
    i_log.Log(() => printf("WinEnter: win %d bufnr %d", winnr(), bufnr()))
enddef

def WinNew()
    i_log.Log(() => printf("WinNew: win %d bufnr %d", winnr(), bufnr()))
enddef

def BufWinEnter()
    if i_buflib.buffers.result.bufnr == bufnr()
        i_log.Log(() => printf("BufWinEnter: win %d bufnr %d", winnr(), bufnr()))
        # This doesn't work. DO IT AT THE END OF mode.Activate()
        # HighlightConflict()
    endif
enddef

# make them global properties
def AddConflictProps()
    var prop_conflict = {
        highlight: splice.hl_conflict,
        priority: pri_hl_conflict,
        combine: false
    }
    var prop_cur_conflict = {
        highlight: splice.hl_cur_conflict,
        priority: pri_hl_cur_conflict,
        combine: false
    }
    'prop_conflict'->prop_type_add(prop_conflict)
    'prop_cur_conflict'->prop_type_add(prop_cur_conflict)
enddef

# TODO: if the cursor moves off of the cur_conflict line
#       turn off the current conflict. In addition maybe want some other
#       indicator, new or like use_hunk, that means no current conflict


#
# lists of the displayed conflicts
#

# using text properties
var id_conflict_prop: list<number>
var id_cur_conflict_prop: list<number>
# to give each prop its own id
var id_prop: number

# using matchadd
var id_conflict_match: list<list<number>>
var id_cur_conflict_match: list<list<number>>

def Dump(tag: string)
    if true
        return
    endif
    i_log.Log(tag)
    if use_props
        i_log.Log(printf("    id_conflict_prop: %s", id_conflict_match))
        i_log.Log(printf("    id_cur_conflict_prop: %s", id_cur_conflict_match))
    else
        i_log.Log(printf("    id_conflict_match: %s", id_conflict_match))
        i_log.Log(printf("    id_cur_conflict_match: %s", id_cur_conflict_match))
    endif
enddef

export def MoveToConflictOld(forw: bool = true)
    Dump(printf('ENTER: MoveToConflict(forw: %s)', forw))
    var flags = forw ? '' : 'b'

    ###
    ### could just do HighlightConflict only once after spliceinit
    ###

    # HighlightConflict()

    # the next/prev conflict
    var lino = search(CONFLICT_PATTERN, flags)
    if lino == 0
        i_ui.SplicePopupKey('ENOCONFLICT')
    endif

    return


    # #log.Log('cur_conf ids before:' .. string(id_cur_conflict))
    # if use_props
    #     id_cur_conflict_prop->DeleteHighlights()
    #     id_cur_conflict_prop = []
    #     var col = col([lino, '$'])
    #     id_prop += 1
    #     prop_add(lino, 1, { type: 'prop_cur_conflict', length: col, id: id_prop })
    #     id_cur_conflict_prop->add(id_prop)
    # else
    #     # This line looses id_conflict_match
    #     id_cur_conflict_match->DeleteHighlights()

    #     id_cur_conflict_match = []
    #     var t = matchaddpos(splice.hl_cur_conflict, [ lino ], pri_hl_cur_conflict)
    #     id_cur_conflict_match->add([winnr(), t])
    # endif
    # Dump(printf('EXIT: MoveToConflict()'))
    # #log.Log('cur_conf ids after:' .. string(id_cur_conflict))
enddef

#
# Highlight all the conflicts in this buffer
#
export def HighlightConflictOld()
    #log.Log('conf ids before:' .. string(id_conflict))
    Dump('ENTER: HighlightConflict')
    if use_props
        id_conflict_prop->DeleteHighlights()
        id_conflict_prop = []
        var lines = FindLines(CONFLICT_PATTERN)
        #i_log.Log('FindLines: ' .. string(lines))
        id_prop += 1
        prop_add_list({ type: 'prop_conflict', id: id_prop },
            lines->mapnew((_, l) => [ l, 1, l, col([l, '$']) ] ))
        id_conflict_prop->add(id_prop)
    else
        id_conflict_match->DeleteHighlights()
        id_conflict_match = []
        # {} can contain window
        id_conflict_match->add([winnr(), 
            matchadd(splice.hl_conflict, CONFLICT_PATTERN, pri_hl_conflict)])
    endif
    Dump('EXIT: HighlightConflict')
    #log.Log('conf ids after:' .. string(id_conflict))
enddef

# Remove all of the highlights
def DeleteHighlights(ids: list<any>)
    Dump(printf('ENTER: DeleteHighlights(ids: %s)', ids))
    #echom ids
    var n_delete: number
    if use_props
        ids->foreach((_, v) => {
            n_delete += prop_remove({ id: v, all: true })
            })

        # ids->filter((_, v) => {
        #     n_delete += prop_remove({ id: v, all: true })
        #     return false
        #     })
    else
        #clearmatches()

        # After changing "mode", this gets an invalid winnr or ID
        ids->foreach((_, v) => {
            try
                matchdelete(v[1], v[0])
            catch /E957:\|E803:/
                #echom 'winnr():' winnr() 'delete():' v
            endtry
            n_delete += 1
        })

        # ids->filter((_, v) => {
        #     matchdelete(v)
        #     return false
        #     })
    endif
    #echo 'DeleteHighlights:' n_delete
    Dump(printf('EXIT: DeleteHighlights()'))
enddef

# return something suitable for setting text properties
# TODO don't add the same line more than once (not an issue with conflict)
def FindLines(pat: string, flags: string = ''): list<number>
    var result: list<number> = []
    i_with.With(i_with.KeepPosEE.new(), (_) => {
        cursor(1, 1)
        while search(pat, flags .. 'W') != 0
            result->add(line('.'))
        endwhile
    })
    return result
enddef

