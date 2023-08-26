vim9script

var standalone_exp = false
if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
    standalone_exp = true
endif

# set 'testing' to true and source this file for testing
var testing = false

import autoload './log.vim' as i_log
import autoload './vim_assist.vim'
import autoload './MapModeFilters.vim'
import autoload '../modes.vim' as i_modes

const Pad = vim_assist.Pad
const MapModeFilterExpr = MapModeFilters.MapModeFilterExpr
const MapModeFilter = MapModeFilters.MapModeFilter
const Keys2Str = vim_assist.Keys2Str
# Having the following gives weird startup messages
#const ModesDispatch = i_modes.ModesDispatch

if standalone_exp
    i_log.LogInit($HOME .. '/play/SPLICE_LOG')
    i_log.Log('=== ' .. strftime('%c') .. ' ===')
    i_log.Log('=== Unit Testing ===')
endif


# each action has
#   a_dflt:     default binding character(s)
#   a_dsply:    order in which to display values

# Lists are built and cached from following

# The key is action name
const actions_info = {
    Grid:     { a_dflt: 'g',       a_dsply:  0, },
    Loupe:    { a_dflt: 'l',       a_dsply:  1, },
    Compare:  { a_dflt: 'c',       a_dsply:  2, },
    Path:     { a_dflt: 'p',       a_dsply:  3, },

    Original: { a_dflt: 'o',       a_dsply:  4, },
    One:      { a_dflt: '1',       a_dsply:  5, },
    Two:      { a_dflt: '2',       a_dsply:  6, },
    Result:   { a_dflt: 'r',       a_dsply:  7, },

    Diff:     { a_dflt: 'd',       a_dsply:  8, },
    DiffOff:  { a_dflt: 'D',       a_dsply:  9, },
    Next:     { a_dflt: 'n',       a_dsply: 10, },
    Previous: { a_dflt: 'N',       a_dsply: 11, },
    Layout:   { a_dflt: '<Space>', a_dsply: 12, },
    Scroll:   { a_dflt: 's',       a_dsply: 13, },

    UseHunk1: { a_dflt: 'u1',      a_dsply: 14, },
    UseHunk2: { a_dflt: 'u2',      a_dsply: 15, },
    UseHunk:  { a_dflt: 'u',       a_dsply: 16, },

    Quit:     { a_dflt: 'q',       a_dsply: 17, },
    Cancel:   { a_dflt: 'CC',      a_dsply: 18, },
}

var actionsSortedBy: dict<list<string>>

# return action names list sorted by "actions_info[act_name][field]"
# cache the returned value for re-use.
export def ActionsSortedBy(field: string): list<string>
    if ! actionsSortedBy->has_key(field)
        var x = actions_info->keys()
            ->map((i, act_name) => [ act_name, actions_info[v][field] ])
            ### ->filter((i, v) => v[1] != 88)
            ->sort((a1, a2) => a1[1] - a2[1])
            ->map((i, v) => v[0])
        unlockvar 2 actionsSortedBy
        actionsSortedBy[field] = x
        lockvar 2 actionsSortedBy
    endif
    return actionsSortedBy[field]
enddef

# actions_grouping used for display spacing
# or maybe put a flag/marker into anctions_info or could have a "a_grp" field
var actions_groupings = [ 4, 4, 6, 3 ]

# Add empty items, returned by FSep, in list to separate groups.
# Input list should be sorted by 'a_dsply'.
export def AddSeparators(l: list<any>, FSep: func): list<any>
    var idx = 0
    for grp_size in actions_groupings
        idx += grp_size
        l->insert(FSep(), idx)
        idx += 1
    endfor
    return l
enddef

# would like to return null, but string can't be null
# TODO: instead of 'splice_bind_', how about 'splice_map_'? Maybe not.
def GetMapping(key: string): string
    var mapping = g:->get('splice_bind_' .. key, null)
    if mapping == 'None' || mapping == ''
        return ''
    elseif mapping != null
        return mapping
    endif

    # Use the default taking prefix into account, unless use meta
    var dflt = actions_info[key]['a_dflt']
    if ! !!g:->get('splice_bind_use_meta', false)
        return g:->get('splice_prefix', '-') .. dflt
    endif

    # Use the Meta Key with the defaults.
    if dflt == '<Space>'
        mapping = "\u16\uA0"
    else
        mapping = ''
        for c in dflt
            mapping ..= '<M-' .. c .. '>'
        endfor
    endif
    return mapping
enddef

# If global setting, use that.
# Otherwise bind-map as usual
def Bind(key: string)
    var mapping = GetMapping(key)
    if mapping == ''
        i_log.Log(() => "Bind-Map: SKIP '" .. key .. "'")
        return
    endif
    var t = "<ScriptCmd>i_modes.ModesDispatch('Splice" .. key .. "')<CR>"
    i_log.Log(() => printf("Bind-Map: '%s' -> '%s'", mapping, t))
    execute 'nnoremap' mapping t
enddef

def UnBind(key: string)
    var mapping = GetMapping(key)
    if mapping == ''
        i_log.Log(() => "Bind-UnMap: SKIP '" .. key .. "'")
        return
    endif
    i_log.Log(() => "Bind-UnMap: '" .. mapping .. "'")
    execute 'unmap' mapping
enddef


###############################
# MappingsList()->AddSeparators(() => [])

# [['Grid', ['<M-x>', '<M-g>'], 'g'], ['Loupe', ['<M-l>'], 'l'],
#     ['Compare', ['<M-c>'], 'c'], ['Path', ['<M-p>'], 'p'], [],
# ...
# ['UseHunk1', ['<M-u><M-1>'], 'u1'], ['UseHunk2', ['<M-u><M-2>'], 'u2'],
#     ['UseHunk', ['<M-u>'], 'u']]

const FilterSpliceMap = MapModeFilterExpr('n', "m['rhs'] =~ '^<ScriptCmd>i_modes\.ModesDis'")

# Return list of mappings
export def MappingsList(): list<any>
    var mappings: dict<list<string>>
    for k in actions_info->keys()
        mappings[k] = []
    endfor
    for [k, v] in maplist()->filter(FilterSpliceMap)
            ->map((i, m) => MappingPair(m['rhs'], m['lhs']))
        # only include known splice commands
        #i_log.Log(() => printf("MappingPair() '%s' '%s'", k, v))
        if mappings->has_key(k)
            mappings[k]->add(v)
        endif
    endfor
    # Add the UseHunk mappings, but not if already in list
    AddHunkIfNeeded(mappings, 'UseHunk')
    AddHunkIfNeeded(mappings, 'UseHunk1')
    AddHunkIfNeeded(mappings, 'UseHunk2')
    # turn dict into list, sort, add default
    return mappings->items()
        ->sort((a1, a2) =>
            actions_info[a1[0]]['a_dsply'] - actions_info[a2[0]]['a_dsply'])
        ->map((i, v) => {
            v->add(actions_info[v[0]]['a_dflt'])
            return v
        })
enddef

# return like: [ 'Grid', '<M-g>' ]; would handle multiple mappings
def MappingPair(rhs: string, lhs: string): list<string>
        return [
            rhs->substitute(''')<[Cc][Rr]>', '', '')
                ->substitute('^<ScriptCmd>i_modes\.ModesDispatch(.Splice', '', ''),
            lhs->Keys2Str(),
        ]
enddef

# Add hunk mapping to list if not alreay there.
# Needed since hunk mappings are dynamically changed around
def AddHunkIfNeeded(d: dict<list<string>>, hunk: string): void
    var l = d[hunk]
    var mapping = GetMapping(hunk)->Keys2Str()
    if l->index(mapping) < 0
        l->add(mapping)
    endif
enddef

# Initialize all bindings except for UseHunk1/UseHunk2

export def InitializeBindings()
    i_log.Log('InitializeBindings()')
    # The default state is UseHunk; UseHunk?(1|2) are dynamically handled,
    # see ActivateGridBindings, DeactivateGridBindings
    var initBindings = actions_info->keys()
        ->filter((i, v) => v != 'UseHunk1' && v != 'UseHunk2')

    # setup the mappings
    for k in initBindings
        Bind(k)
    endfor

    # some commands defined in here
enddef

export def ActivateGridBindings()
    i_log.Log('ActivateGridBindings')
    UnBind('UseHunk')
    Bind('UseHunk1')
    Bind('UseHunk2')
enddef

export def DeactivateGridBindings()
    i_log.Log('DectivateGridBindings')
    UnBind('UseHunk1')
    UnBind('UseHunk2')
    Bind('UseHunk')
enddef

finish

############################################################################
############################################################################
############################################################################

###############################
# BindingKeys temporarily binds key to bogus insert mode mapping,
# then extracts the binding keys and unmap the temp mapping,
# converts keys to string, returns it.
def BindingKeys(key: string): string
    var mapping = GetMapping(key)
    # return mapping
    if mapping == ''
        return null_string
    endif
    var rhs = 'xyzzy-Splice'
    execute 'inoremap' mapping rhs
    var m = maplist()->filter(MapModeFilter('i', rhs, true, 'rhs'))[0]
    execute 'iunmap' mapping
    #var r = [ m.lhs, m.lhsraw ]
    #return r
    return Keys2Str(m.lhs)
enddef

###############################
# ['<M-1>', '<80><fc>^H1', '±', '3c:4d:2d:31:3e:', '80:fc:8:31:', 'b1:']
# NOTE: ['<M-1>', '<80><fc>^H1', '±', '<:M:-:1:>:','80:fc:8:31:', 'b1:']
def BindingKeysDebug(key: string): list<string>
    var mapping = GetMapping(key)
    # return mapping
    if mapping == ''
        return [ null_string ]
    endif
    var rhs = 'xyzzy-Splice'
    execute 'inoremap' mapping rhs
    var m = maplist()->filter(MapModeFilter('i', rhs, true, 'rhs'))[0]
    execute 'iunmap' mapping
    var r = [ m.lhs, m.lhsraw ]
    if m->has_key('lhsrawalt')
        r->add(m.lhsrawalt)
    endif
    for x in r->copy()
        var s: string
        for c in x->str2list()
            s ..= printf("%x:", c)
        endfor
        r->add(s)
    endfor
    return r
enddef

###############################
# list in display order with empty separators
#['Grid', 'Loupe', 'Compare', 'Path', '', 'Original', 'One', 'Two', 'Result', '',
#    'Diff', 'DiffOff', 'Scroll', 'Layout', 'Next', 'Previous', '',
#    'Quit', 'Cancel', '', 'UseHunk1', 'UseHunk2', 'UseHunk']
var displayOrderBindings: list<string>
def DisplayOrderBindings(): list<string>
    if ! !!displayOrderBindings
        var x = ActionsSortedBy('a_dsply')->copy()
        displayOrderBindings = AddSeparators(x, () => '')
        lockvar displayOrderBindings
    endif
    return displayOrderBindings
enddef


###############################
# Grid g <M-g>
# Loupe l <M-l>
# Compare c <M-c>
# Path p <M-p>
# 
# ...
# UseHunk u <M-u>
def BindingList(): list<string>
    var result: list<string>
    #for action in bindingsInOrder
    for action in DisplayOrderBindings()
        if !! action
            #var default = defaultBindings[action]
            var default = actions_info[action]['a_dflt']
            #result->add(action .. "\t" .. default .. "\t" .. GetMapping(action))
            result->add(action .. " " .. default .. " " .. GetMapping(action))
        else
            result->add('')
        endif
    endfor
    return result
enddef

###############################
#'    Grid  g        <M-g>      '
#'   Loupe  l        <M-l>      '
#' Compare  c        <M-c>      '
#'    Path  p        <M-p>      '
#''
#...
#' UseHunk  u        <M-u>      '
def BindingList2(): list<string>
    var result: list<string>

    var defaults_padded: list<string>
    var mappings_padded: list<string>
    #for action in bindingsInOrder
    for action in DisplayOrderBindings()
        if !! action
            #defaults_padded->add(defaultBindings[action])
            defaults_padded->add(actions_info[action]['a_dflt'])
            mappings_padded->add(Keys2Str(GetMapping(action)))
        else
            defaults_padded->add('')
            mappings_padded->add('')
        endif
    endfor

    #var bindings_padded = bindingsInOrder->copy()->Pad('r')
    var bindings_padded = DisplayOrderBindings()->copy()->Pad('r')
    defaults_padded->Pad()
    mappings_padded->Pad()

    for i in range(bindings_padded->len())
        if !! bindings_padded[i]->trim()
            result->add(bindings_padded[i] .. "  "
                .. defaults_padded[i] .. "  "
                .. mappings_padded[i])
        else
            result->add('')
        endif
    endfor
    return result
enddef

def RandomTesting()
    i_log.Log('INIT')
    InitializeBindings()
    i_log.Log('ACTIVATE-GRID')
    ActivateGridBindings()
    i_log.Log('DE-ACTIVATE-GRID')
    DeactivateGridBindings()

    # Have two grid mappings found
    nnoremap <M-x> :SpliceGrid<CR>
    nnoremap <M-z> :SpliceGridx<CR>

    var t: any

    #echo actions_info->keys()
    #echo ActionsSortedBy('a_dsply')
    #echo '============= Display Order Bindings ====================='
    #echo DisplayOrderBindings()
    #echo '================== BindingList2 =========================='
    #for i in BindingList2()
    #    echo "'" .. i .. "'"
    #endfor
    #echo '================== BindingList ==========================='
    #for i in BindingList()
    #    echo !! i ? i : ' '
    #endfor

    #echo '===== MappingsList->AddSeparators(() => []) =============='
    #t = MappingsList()->AddSeparators(() => [])
    #echo t

    #echo '============ BindingKyesDebug ============================'
    #echo actions_info->keys()->map((i, k) => {
    #    var m = GetMapping(k)
    #    var s: string
    #    for c in m->str2list()
    #        s ..= printf("%x:", c)
    #    endfor
    #    #return [ k, m, m->len(), s ]
    #    return [ k, BindingKeysDebug(k) ]
    #})
    #echo '============= BindingKeys ================================'
    #echo actions_info->keys()->map((i, k) => [ k, BindingKeys(k) ])
    #echo '=========================================================='
    #echo actions_info->keys()->map((i, k) => [ k, GetMapping(k) ])
    #for i in MappingsList()->items()
    #    echo i
    #endfor
enddef

if testing
    RandomTesting()
endif

