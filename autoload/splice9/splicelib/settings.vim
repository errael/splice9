vim9script

var standalone_exp = false
if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
    standalone_exp = true
endif

if ! standalone_exp
    import autoload './util/log.vim' as i_log
    import autoload './util/vim_assist.vim'
else
    import './vim_assist.vim'
endif

const Log = i_log.Log

var PutIfAbsent = vim_assist.PutIfAbsent

export def Setting(setting: string): any
    var key = 'splice_' .. setting
    Log(() => $"Setting: key: {key}", 'setting')
    if ! g:->has_key(key)
        throw $"Setting unknown: '{key}'"
    endif
    Log(() => $"Setting: get(key): '{g:->get(key)}', type {type(g:->get(key))}", 'setting')
    return g:->get(key)
enddef

var settings_errors: list<string>

# Assume VAL already quoted by string() method.
var bad_var_template =<< trim END
    For 'GLOB', value 'VAL' not allowed.
        Must be OKVALS.
END

def BadVarMsg(glob: string, val: string, okvals: string): list<string>
    var s1 = bad_var_template[0]->substitute('\CGLOB', glob, '')
    s1 = s1->substitute('\CVAL', val, '')
    return [ '', s1, bad_var_template[1]->substitute('\COKVALS', okvals, '') ]
enddef

# ToString, call string() on arg, unless arg is string. Avoids extra '.
def TS(a: any): any
    if type(a) == v:t_string | return a | endif
    return string(a)
enddef

# return like: 'a', 'b', 'c'
def QuoteList(slist: list<any>): string
    return slist->mapnew((_, v) => string(v))->join(", ")
enddef

# Return true if use setting is ok, otherwise add errormsg to settings_errors.
# 
# If a problem, the setting is assigned the default value.
#
# If the call wan't some additional message massaging, One way
# is to use the GetDefault() to put in a tag and edit it.
def CheckOneOfSetting(setting: string, ok: list<any>, default: any): bool
    #log.Log('checking: ' .. string(setting) .. " " .. string(ok) .. " " ..  string(GetDefault))
    var msg = []
    var val = g:->get(setting, null)
    if val != null && ok->index(val) == -1
        msg = BadVarMsg('g:' .. setting, TS(val),
            "one of " .. QuoteList(ok))
        if default != null
            msg->add("    Using: " .. default)
            g:[setting] = default
        endif
        settings_errors->extend(msg)
        return false
    endif
    return true
enddef

# Configuration variables


# TODO:
# Rather than having defaults in vim global space,
# may want to set up default in one place, then use a
# separate dictionary just for python. Not worth the bother
# since Splice *owns* vim when it runs, no problem polluting g:.

# { setting-name: [ [ ok_values... ], default_val ]
# NOTE: 'splice_wrap' default val is computed based on '&wrap'
var setting_info = {
    splice_disable:                    [ [ 0, 1, false, true ], false ],
    splice_initial_mode:
        [ [ 'grid', 'loupe', 'compare', 'path' ], 'grid' ],

    splice_initial_layout_grid:        [ [ 0, 1, 2 ], 0 ],
    splice_initial_layout_loupe:       [ [ 0 ],       0 ],
    splice_initial_layout_compare:     [ [ 0, 1 ],    0 ],
    splice_initial_layout_path:        [ [ 0, 1 ],    0 ],

    splice_initial_diff_grid:          [ [ 0, 1 ],          0 ],
    splice_initial_diff_loupe:         [ [ 0 ],             0 ],
    splice_initial_diff_compare:       [ [ 0, 1 ],          0 ],
    splice_initial_diff_path:          [ [ 0, 1, 2, 3, 4 ], 0 ],

    splice_initial_scrollbind_grid:    [ [ 0, 1, false, true ], false ],
    splice_initial_scrollbind_loupe:   [ [ 0, 1, false, true ], false ],
    splice_initial_scrollbind_compare: [ [ 0, 1, false, true ], false ],
    splice_initial_scrollbind_path:    [ [ 0, 1, false, true ], false ],

    splice_wrap:                       [ [ 'wrap', 'nowrap' ], '' ],
}
# Make the default splice_wrap the vimrc wrap setting
setting_info.splice_wrap[1] = &wrap ? 'wrap' : 'nowrap'
lockvar setting_info

var settings_init = false
export def InitSettings(): list<string>
    if settings_init
        return null_list
    endif

    # TODO: splice_leader is new. Needed?
    var t = exists('g:splice_leader') ? g:splice_leader : '-'
    g:->PutIfAbsent('splice_prefix', t)

    for [ setting, info ] in setting_info->items()
        g:->PutIfAbsent(setting, info[1])
        CheckOneOfSetting(setting, info[0], info[1])
    endfor
    return settings_errors
enddef


def TestSettings()
    echo "TESTING..."
    InitSettings()
    echo settings_errors->join("\n")
    echo ' '
    for k in setting_info->keys()
        echo printf("k: %s, v: %s\n", k, g:->get(k))
    endfor
enddef
