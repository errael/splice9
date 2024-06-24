vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload './ui.vim' as i_ui
import autoload '../../splice.vim'
import autoload Rlib('util/with.vim') as i_with
import autoload Rlib('util/log.vim') as i_log

# TODO: props don't work interacting with diff coloration
const use_props = false

#
# export def HighlightConflict()
# export def MoveToConflict(forw: bool = true)
#

const pri_hl_conflict = 100
const pri_hl_cur_conflict = 110

const CONFLICT_MARKER_MARK = '======='

# NOTE: the numeric conflict ID is a capture group.
export const CONFLICT_PATTERN = splice.numberedConflictPattern
    ? '\m^=======* :\(\d\+\):$' : '\m^=======*$'

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


#
# Highlight all the conflicts in this buffer
#
export def HighlightConflict()
    #log.Log('conf ids before:' .. string(id_conflict))
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
    #log.Log('conf ids after:' .. string(id_conflict))
enddef

export def MoveToConflict(forw: bool = true)
    var flags = forw ? '' : 'b'

    ###
    ### could just do HighlightConflict only once after spliceinit
    ###
    HighlightConflict()

    # the next/prev conflict
    var lino = search(CONFLICT_PATTERN, flags)
    if lino == 0
        i_ui.SplicePopupKey('ENOCONFLICT')
        return
    endif

    #log.Log('cur_conf ids before:' .. string(id_cur_conflict))
    if use_props
        id_cur_conflict_prop->DeleteHighlights()
        id_cur_conflict_prop = []
        var col = col([lino, '$'])
        id_prop += 1
        prop_add(lino, 1, { type: 'prop_cur_conflict', length: col, id: id_prop })
        id_cur_conflict_prop->add(id_prop)
    else
        # This line looses id_conflict_match
        #id_cur_conflict_match->DeleteHighlights()

        id_cur_conflict_match = []
        var t = matchaddpos(splice.hl_cur_conflict, [ lino ], pri_hl_cur_conflict)
        id_cur_conflict_match->add([winnr(), t])
    endif
    #log.Log('cur_conf ids after:' .. string(id_cur_conflict))
enddef

# Remove all of the highlights
def DeleteHighlights(ids: list<any>)
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
        clearmatches()

        #ids->foreach((_, v) => {
        #    matchdelete(v[1], v[0])
        #    n_delete += 1
        #})

        # ids->filter((_, v) => {
        #     matchdelete(v)
        #     return false
        #     })
    endif
    #echo 'DeleteHighlights:' n_delete
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

