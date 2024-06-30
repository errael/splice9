vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload Rlib('util/log.vim') as i_log
import autoload './util/keys.vim' as i_keys

const use_config = exists('g:splice_config')
export var config_dict: dict<any> = use_config ? g:splice_config : {}

# Used only during startup, after initialization, Setting(key) is properly used
# Fetch user settings from g:config_dict[name] if exists or g:splice_name.
# If not found then return the default.
# Use "check_default" false to return null if not found.
export def GetFromOrig(setting: string, check_default = true): any
    var dflt = check_default ? setting_info[setting][1] : null
    #echoc printf("GetFromOrig: %s rc: %s, default: %s/%s", setting,
    #    use_config ? config_dict->get(setting, dflt) : g:->get('splice_' .. setting, dflt),
    #    default, setting_info[setting][1])
    return use_config
        ? config_dict->get(setting, dflt) : g:->get('splice_' .. setting, dflt)
enddef

#export def GetDefault(name: string): any
#    return setting_info[name][1]
#enddef

export def Setting(key: string): any
    i_log.Log(() => $"Setting: key: {key}", 'setting')
    if ! config_dict->has_key(key)
        throw $"Setting unknown: '{key}'"
    endif
    i_log.Log(() => printf("Setting: get(key): '%s', type {%s}",
        config_dict->get(key), type(config_dict->get(key))), 'setting')
    return config_dict->get(key)
enddef

export def Set_cur_window_wrap()
    var setting = Setting('wrap')
    if setting != null
        &wrap = setting == 'wrap'
        i_log.Log(() => printf("winnr %d, &wrap set to %s", winnr(), &wrap), 'diffopts')
    endif
enddef

export def ApplyWrap(is_wrap: bool)
    getwininfo()->foreach((_, d) => {
        # Skip the HUD
        if d.winnr != 1
            i_log.Log(() => printf("    WID %d, WNR %d, BNR %d, set %s",
                d.winid, d.winnr, d.bufnr, is_wrap ? 'wrap' : 'nowrap'), 'diffopts')
            win_execute(d.winid, ":set " .. (is_wrap ? 'wrap' : 'nowrap'))
        endif
    })
enddef

#export def ApplyWrapSetting()
#    ApplyWrap(Setting('wrap') == 'wrap')
#enddef

# return[0] list, one on/off-bool per window
# return[1] == true if all the same
# return[2] ignore if return[0] is false, otherwise true means all_on
export def WindowWrapInfo(): list<any>
    var all_on: bool = true
    var all_off: bool = true
    var on_off: list<bool>
    getwininfo()->foreach((_, d) => {
        # Skip the HUD
        if d.winnr != 1
            var is_wrap = getwinvar(d.winnr, '&wrap')
            on_off->add(is_wrap)
            if is_wrap
                all_off = false
            else
                all_on = false
            endif
            i_log.Log(() => printf("    WNR %d, on %s, off %s", d.winnr, all_on, all_off), 'diffopts')
        endif
    })
    return [ on_off, all_on || all_off, all_on]
enddef

export def ChangeSetting(key: string, value: any)
    i_log.Log(() => printf("ChangeSetting: %s: old: %s, new: %s",
        key, config_dict->get(key, "BAD_KEY"), value))
    # only allow wrap to change
    if key == 'wrap'
        if ['wrap', 'nowrap']->index(value) < 0
            i_log.Log(printf("ChangeSetting: value %s'"), 'error')
            return
        endif
    else
        i_log.Log(printf("ChangeSetting: key %s'"), 'error')
        return
    endif

    unlockvar config_dict
    config_dict[key] = value
    lockvar config_dict
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

# NOTE: "ok_vals_msg" overrides "ok"
def RecordSettingError(setting: string, default: any, ok: list<any> = [],
        ok_vals_msg: string = null_string)
    var val = config_dict->get(setting, null)
    var msg = BadVarMsg('g:splice_config.' .. setting, TS(val),
        ok_vals_msg ?? "one of " .. QuoteList(ok))
    if default != null
        msg->add("    Using: '" .. default .. "'")
        config_dict[setting] = default
    endif
    settings_errors->extend(msg)
enddef

def UnknownSetting(setting: string)
    settings_errors->add('')->add(printf(
        "'g:splice_config.%s' is an unkown setting. Misspelling?", setting))
enddef

# Return true if use setting is ok, otherwise add errormsg to settings_errors.
# 
# If a problem, the setting is assigned the default value.
#
# If the call wan't some additional message massaging, One way
# is to use the GetDefault() to put in a tag and edit it.
def CheckOneOfSetting(setting: string, default: any, okfunc: any): bool
    #log.Log('checking: ' .. string(setting) .. " " .. string(ok) .. " " ..  string(GetDefault))
    #var msg = []

    var val = config_dict->get(setting, null)
    if val != null
        if type(okfunc) == v:t_list
            var ok: list<any> = okfunc
            if ok->index(val) == -1
                RecordSettingError(setting, default, ok)
                return false
            endif
        elseif type(okfunc) == v:t_func
            var Func: func = okfunc
            if !Func(setting, val, default)
                return false
            endif
        else
            throw "Internal error: invalid check type"
        endif
    endif
    return true
enddef

# ok is a list of types, 
def CheckTypeOfSetting(setting: any, default: any, ok: list<number>): bool
    #log.Log('checking: ' .. string(setting) .. " " .. string(ok) .. " " ..  string(GetDefault))
    var val = config_dict->get(setting, null)
    # TODO: could map 'ok' list to list of types
    if val != null && ok->index(type(val)) == -1
        RecordSettingError(setting, default, v:none, 'correct type')
        return false
    endif
    return true
enddef

# Configuration variables

# TODO: this should not be used
def ValidAny(setting: string, val: any, default: any): bool
    return true
enddef

#def ValidString(setting: string, s: any, default: string): bool
#enddef

def ValidHighlight(setting: string, hl: any, default: string): bool
    if type(hl) == v:t_string && hlexists(hl)
        return true
    endif
    RecordSettingError(setting, default, v:none, "a valid highlight group")
    return false
enddef
const ValidHlRef = ValidHighlight

# { setting-name: [ [ ok_values... ], default_val ]
# NOTE: 'splice_wrap' default val is computed based on '&wrap'
var setting_info = {
    disable:                    [ [ 0, 1, false, true ], false ],
    debug:                      [ [ 0, 1, false, true ], false ],
    initial_mode:
        [ [ 'grid', 'loupe', 'compare', 'path' ], 'grid' ],

    initial_layout_grid:        [ [ 0, 1, 2 ], 0 ],
    initial_layout_loupe:       [ [ 0 ],       0 ],
    initial_layout_compare:     [ [ 0, 1 ],    0 ],
    initial_layout_path:        [ [ 0, 1 ],    0 ],

    initial_diff_grid:          [ [ 0, 1 ],          0 ],
    initial_diff_loupe:         [ [ 0 ],             0 ],
    initial_diff_compare:       [ [ 0, 1 ],          0 ],
    initial_diff_path:          [ [ 0, 1, 2, 3, 4 ], 0 ],

    initial_scrollbind_grid:    [ [ 0, 1, false, true ], false ],
    initial_scrollbind_loupe:   [ [ 0, 1, false, true ], false ],
    initial_scrollbind_compare: [ [ 0, 1, false, true ], false ],
    initial_scrollbind_path:    [ [ 0, 1, false, true ], false ],

    wrap:                       [ [ 'wrap', 'nowrap' ], '' ],

    hl_label:                   [ ValidHlRef, 'SpliceLabel' ],
    hl_sep:                     [ ValidHlRef, 'SpliceLabel' ],
    hl_command:                 [ ValidHlRef, 'SpliceCommand' ],
    hl_rollover:                [ ValidHlRef, 'Pmenu' ],
    hl_active:                  [ ValidHlRef, 'Keyword' ],
    hl_diff:                    [ ValidHlRef, 'DiffChange' ],
    hl_alert_popup:             [ ValidHlRef, 'Pmenu' ],
    hl_popup:                   [ ValidHlRef, 'ColorColumn' ],
    hl_heading:                 [ ValidHlRef, 'SpliceUnderline' ],
    hl_conflict:                [ ValidHlRef, 'SpliceConflict' ],
    hl_cur_conflict:            [ ValidHlRef, 'SpliceCConflict' ],

    # logging validation/init is handled before settings initialization
    log_enable:                 [ [ 0, 1, false, true ], false ],
    log_file:                   [ ValidAny, $HOME .. '/SPLICE_LOG' ],
    logging_exclude_categories: [ ValidAny, [ 'focus', 'result', 'setting',
                                            'diffopts'] ],

    prefix:                     [ ValidAny, null ],
    leader:                     [ ValidAny, null ],
}
# Make the default splice_wrap the vimrc wrap setting
setting_info.wrap[1] = &wrap ? 'wrap' : 'nowrap'
lockvar setting_info

var did_settings_init = false
# Insure that all settings are in config_dict.
# Return a list of errors.
export def InitSettings(): list<string>
    if did_settings_init
        return null_list
    endif

    # Splice doc says to use "g:splice_prefix", but the original has a
    # dance to secondarily check "g:splice_leader".
    var prefix = GetFromOrig('prefix', false)
    if prefix == null
        var leader = GetFromOrig('leader', false)
        prefix = leader != null ? leader : '-'
    endif
    # resolve mapleader now, freezing the prefix so it can't be changed,
    prefix = prefix
        ->substitute('\c' .. '<leader>', g:->get('mapleader', '\\'), "g")

    # Put resolved prefix into config dictionary.
    config_dict.prefix = prefix
    i_log.Log($'PREFIX: {prefix}', 'setting')

    CheckTypeOfSetting('prefix', '-', [ v:t_string ])

    # settings will eventually have list of all possible settings
    var settings = setting_info->keys()
i_log.Log(printf("INITIAL CONFIG_DICT: %s, %s", use_config, config_dict))
    for setting in settings
        var info = setting_info->get(setting)
        # Copy from old location to new.
        if !use_config
            var t = GetFromOrig(setting, false)
            if t != null
                config_dict[setting] = t
            endif
        endif
        config_dict->extend({[setting]: info[1]}, 'keep')
        # TODO: only need to CheckOneOfSetting if setting not in config
        CheckOneOfSetting(setting, info[1], info[0])
    endfor

    # Copy Key Bindings settings from old to new
    var binding_keys = i_keys.GetBindingKeys()->map((_, val) => 'bind_' .. val)
    if !use_config
        for bindkey in binding_keys
            var t = GetFromOrig(bindkey, false)
            if t != null
                config_dict[bindkey] = t
            endif
        endfor
    endif
    lockvar config_dict
i_log.Log(printf("CONFIG_DICT: %s", config_dict))
    # Scan config_dict for any unknown settings
    settings->extend(binding_keys)
    for setting in config_dict->keys()
        if settings->index(setting) < 0
            UnknownSetting(setting)
        endif
    endfor

    return settings_errors
enddef


def TestSettings()
    echo "TESTING..."
    InitSettings()
    echo settings_errors->join("\n")
    echo ' '
    for k in setting_info->keys()
        echo printf("k: %s, v: %s\n", k, config_dict->get(k))
    endfor
enddef