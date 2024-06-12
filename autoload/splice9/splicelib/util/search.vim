vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload './ui.vim' as i_ui
import autoload '../../splice.vim'
import autoload Rlib('util/with.vim') as i_with

# TODO: props don't work interacting with diff coloration
var use_props = false

#
# export def HighlightConflict()
# export def MoveToConflict(forw: bool = true)
#

const pri_hl_conflict = 100
const pri_hl_cur_conflict = 110

const CONFLICT_MARKER_MARK = '======='

const CONFLICT_PATTERN = '\m^=======*$'

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

# add the props when this file is loaded
AddConflictProps()

#
# Highlight all the conflicts in this buffer
#
export def HighlightConflict()
    #log.Log('conf ids before:' .. string(id_conflict))
    if use_props
        id_conflict->DeleteHighlights()
        var lines = FindLines(CONFLICT_PATTERN)
        #log.Log('FindLines: ' .. string(lines))
        id_prop += 1
        prop_add_list({ type: 'prop_conflict', id: id_prop },
            lines->mapnew((_, l) => [ l, 1, l, col([l, '$']) ] ))
        id_conflict->add(id_prop)
    else
        id_conflict->DeleteHighlights()
        # {} can contain window
        id_conflict->add(matchadd(splice.hl_conflict, CONFLICT_PATTERN, pri_hl_conflict))
    endif
    #log.Log('conf ids after:' .. string(id_conflict))
enddef

var id_cur_conflict: list<number>

export def MoveToConflict(forw: bool = true)
    var flags = forw ? '' : 'b'

    ###
    ### could just do HighlightConflict only once after spliceinit
    ###
    HighlightConflict()

    # the next/prev conflict
    var lino = search(CONFLICT_PATTERN, flags)
    if lino == 0
        i_ui.SplicePopup('ENOCONFLICT')
        return
    endif
    #log.Log('cur_conf ids before:' .. string(id_cur_conflict))
    if use_props
        id_cur_conflict->DeleteHighlights()
        var col = col([lino, '$'])
        id_prop += 1
        prop_add(lino, 1, { type: 'prop_cur_conflict', length: col, id: id_prop })
        id_cur_conflict->add(id_prop)
    else
        id_cur_conflict->DeleteHighlights()
        var t = matchaddpos(splice.hl_cur_conflict, [ lino ], pri_hl_cur_conflict)
        id_cur_conflict->add(t)
    endif
    #log.Log('cur_conf ids after:' .. string(id_cur_conflict))
enddef

def DeleteHighlights(ids: list<number>)
    if use_props
        ids->filter( (_, v) => {
            prop_remove({ id: v, all: true })
            return false
            })
    else
        ids->filter( (_, v) => {
            matchdelete(v)
            return false
            })
    endif
enddef

# to give each prop its own id, only if use_props
var id_prop: number

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

var id_conflict: list<number>

