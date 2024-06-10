vim9script

# test_override('autoload', 1)
# test_override('defcompile', 1)

echomsg 'ABOUT TO IMPORT'

import './rlib.vim'
const Rlib = rlib.Rlib

# ============================================================================
# HISTORIC NOTE. Steve Losh does not maintain this vim9 Splice9.
# Steve wrote the original Splice which is written in python.
# File:        splice.vim
# Description: vim global plugin for resolving three-way merge conflicts
# Maintainer:  Steve Losh <steve@stevelosh.com>
# License:     MIT X11
# ============================================================================

# import keys.vim, without "as", causes keys() usage to get an error
import autoload './splicelib/util/keys.vim' as i_keys
import autoload Rlib('util/log.vim') as i_log
import autoload './splicelib/util/search.vim'
import autoload './splicelib/hud.vim'
import autoload './splicelib/init.vim' as i_init
import autoload './splicelib/settings.vim'
import autoload './splicelib/modes.vim' as i_modes

# bounce HACK
export def GetStatusDiffScrollbind(): list<bool>
    return i_modes.GetStatusDiffScrollbind()
enddef
export def GetDiffLabels(): list<string>
    return i_modes.GetDiffLabels()
enddef

def InitHighlights()
    export const hl_label       = settings.Setting('hl_label')
    export const hl_sep         = settings.Setting('hl_sep')
    export const hl_command     = settings.Setting('hl_command')
    export const hl_rollover    = settings.Setting('hl_rollover')
    export const hl_active      = settings.Setting('hl_active')
    export const hl_alert_popup = settings.Setting('hl_alert_popup')
    export const hl_popup       = settings.Setting('hl_popup')
    export const hl_diff        = settings.Setting('hl_diff')
    export const hl_heading     = settings.Setting('hl_heading')
enddef

highlight SpliceCommand term=bold cterm=bold gui=bold
highlight SpliceLabel term=underline ctermfg=6 guifg=DarkCyan
highlight SpliceUnderline term=underline cterm=underline gui=underline

# Some startup peculiarities
#       - The function "SpliceBoot" is caled only to load this file
#         and trigger script (not function) execution for initialization.
#       - during the initial script execution fatal errors may be found
#         and "finish" executed. Errors are recorded in a list, and 
#         the finish prevents most of this file from being executed.
#       - SpliceBoot gets control after the initial script execution,
#         typically from SpliceInit. If there are startup errors,
#         a popup is displayed with instructions to exit.
#         Otherwise the initialization code is executed.
#
# NOTE: if startup_error_msgs is not empty, there has been a fatal error

var startup_error_msgs: list<string>

# Logging initialization. Get, check and use the config info directly.
# TODO: loggin configuration validation.

var fname = settings.GetFromOrig('log_file')
i_log.SetExcludeCategories(settings.GetFromOrig('logging_exclude_categories'))
if settings.GetFromOrig('log_enable')
    i_log.LogInit(fname)
endif

# First define functions that are used during boot.

export def RecordBootFailure(msgs: list<string>)
    # There no insert list at beginning so fiddle about
    var t = msgs->copy()
    t->extend(startup_error_msgs)
    startup_error_msgs = t
enddef

def SpliceDidNotLoad()
    var winid = popup_dialog(startup_error_msgs, {
        filter: 'popup_filter_yesno',
        callback: (_, v: number) => {
            if v == 0 | return | endif
            cq
            }
        })
enddef

def SpliceBootError()
    command! -nargs=0 SpliceInit SpliceDidNotLoad()
    var instrs =<< trim END

        Since the merge can not be completed, the merge
        should be aborted so it can be completed later.

        NOTE: the vim command ":cq" aborts the merge.

        Quit now and abort the merge: Yes/No

    END
    startup_error_msgs->extend(instrs)
    for msg in startup_error_msgs
        i_log.Log(msg, 'error')
    endfor
    SpliceDidNotLoad()
enddef

var Main: func

export def SpliceBoot()
    i_log.Log('SpliceBoot')
    if startup_error_msgs->empty()
        Main()
        return
    endif

    # A FATAL ERROR
    SpliceBootError()
enddef

#
# Examine stuff looking for problems.
# This is invoked just before SpliceInit
#
# These are typically not fatal errors.
# 

# NOTE: reuse startup_error_msgs

def FilterFalse(winid: number, key: string): bool
    return false
enddef

def UserConfigError(msg: list<string>)

    var contents =<< trim END
        Problem with vimrc Splice configuration

        Not a fatal problem. You can dismiss popup and
        continue with merge, or abort merge and retry later.
    END

    contents->extend(msg)
    contents->extend([ '', '(Click on popup to dismiss. Drag border.)' ])

    var winid = popup_create(contents, {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        drag: 1,
        border: [],
        padding: [1, 2, 1, 2],
        close: 'click',
        #mousemoved: 'any', moved: 'any',
        mapping: false, filter: FilterFalse
        })

    var bufnr = winbufnr(winid)
enddef

def ReportStartupIssues()
    if startup_error_msgs != []
        # TODO: timer_start, 200ms?
        #       avoids vim width issue (I think that was it)
        UserConfigError(startup_error_msgs)
        startup_error_msgs = null_list
    endif
enddef

def SpliceInit9()
    i_log.Log('SpliceInit')
    set guioptions+=l
    # startup_error_msgs should already be empty
    startup_error_msgs = settings.InitSettings()
    InitHighlights()
    i_keys.InitializeBindings()
    ReportStartupIssues()
    i_log.Log('starting splice')

    i_init.Init()
enddef


Main = SpliceInit9

