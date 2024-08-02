vim9script

#test_override('autoload', 1)
#test_override('defcompile', 1)

# TODO: make this autoload
import './rlib.vim'
const Rlib = rlib.Rlib
import autoload Rlib('util/log.vim') as i_log

import autoload './splicelib/settings.vim' as i_settings
import autoload './splice.vim' as i_splice

import './splicelib/util/log_categories.vim'
const ERROR = log_categories.ERROR

#
# This file initializes log.vim and settings.vim.
# The idea is avoid any dependency problems.
#
# log.vim is in an external lib, so there are no dependency problems.
# settings.vim autoloads keys.vim, but doesn't really use it during startup.
#

# With logging and settings, invoke "splice.SpliceInit9" to complete initialization.

def InitLogging()
    if i_settings.GetFromOrig('log_enable')
        i_log.LogInit(i_settings.GetFromOrig('log_file'),
                      i_settings.GetFromOrig('log_exclude_categories'),
                      i_settings.GetFromOrig('log_add_exclude_categories'),
                      i_settings.GetFromOrig('log_remove_exclude_categories'))
    endif
enddef

var failures: list<string>

var started_boot: bool
export def SpliceBoot()
    if started_boot
        return
    endif
    started_boot = true
    var settings_errors: list<string>
    try
        InitLogging()
        i_log.Log(printf("SpliceBoot. Logging exclude: %s", i_log.GetExcludeCategories()))
        # i_splice.SpliceInit9(i_settings.InitSettings()) fails: #15137
        # The key point is to initialize settings before initializing splice.
        settings_errors = i_settings.InitSettings()
        # This is the first entry/invocation of splice.vim
        i_splice.SpliceInit9(settings_errors)
    catch
        failures->add(v:exception)
        AddStack(i_log.throwpoint ?? v:throwpoint)
        SpliceBootError2()
    endtry
enddef

export def SpliceBootError(startup_failures: list<string>, stack: string = '')
    failures = startup_failures
    AddStack(stack)
    SpliceBootError2()
enddef

def SpliceDidNotLoad()
    popup_dialog(failures, {
        title: ' Startup ',
        close: 'click',
        filter: 'popup_filter_yesno',
        callback: (_, v: number) => {
            :cq
        }
    })
enddef

def AddStack(stack: string)
    var l = stack->split('\.\.')->map((_, v) => '    ' .. v)
    failures->extend(l)
enddef

var boot_error: bool
def SpliceBootError2()
    if boot_error
        return
    endif
    boot_error = true
    command! -nargs=0 SpliceInit SpliceDidNotLoad()
    var instrs =<< trim END

        The merge can not be completed; the merge must be
        aborted. Correct the problem and complete the
        merge later. For example, with mercurial enter
        "hg resolve --all" when ready to try again.

        Click popup or enter 'y'/'n' to abort the merge.
    END
    failures->extend(instrs)
    if i_log.IsEnabled()
        for msg in failures
            i_log.Log(msg, ERROR)
        endfor
    endif
    SpliceDidNotLoad()
enddef

