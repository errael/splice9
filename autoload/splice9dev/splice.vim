vim9script

#test_override('autoload', 1)
#test_override('defcompile', 1)

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

import autoload './splicelib/util/keys.vim' as i_keys
import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/ui.vim') as i_ui
import autoload './splicelib/util/search.vim' as i_search
import autoload './splicelib/result.vim' as i_result
import autoload './splicelib/settings.vim' as i_settings

export const hl_label        = i_settings.Setting('hl_label')
export const hl_sep          = i_settings.Setting('hl_sep')
export const hl_command      = i_settings.Setting('hl_command')
export const hl_rollover     = i_settings.Setting('hl_rollover')
export const hl_active       = i_settings.Setting('hl_active')
export const hl_diff         = i_settings.Setting('hl_diff')
export const hl_alert_popup  = i_settings.Setting('hl_alert_popup')
export const hl_popup        = i_settings.Setting('hl_popup')
export const hl_heading      = i_settings.Setting('hl_heading')
export const hl_conflict     = i_settings.Setting('hl_conflict')
export const hl_cur_conflict = i_settings.Setting('hl_cur_conflict')
export const hl_cursor_line  = i_settings.Setting('hl_cursor_line')
export const hl_flash_cursor = i_settings.Setting('hl_flash_cursor')

# NOTE: the Splice* highlights are defined in settings.vim

def ConfigureUiHighlights()
    i_ui.ConfigureUiHighlights({
        heading: hl_heading,
        popup: hl_popup,
        alert_popup: hl_alert_popup,
    })
enddef

# If non empty during startup, splice9 aborts with these strings in popup.
var startup_error_msgs: list<string>

# This is only used to report recoverable issues, typically configuration.
def ReportConfigIssues(issues: list<string>)
    if issues->empty()
        return
    endif
    var contents =<< trim END
        Problem with vimrc Splice configuration

        Not a fatal problem. You can dismiss popup and
        continue with merge, or abort merge and retry later.
    END

    contents->extend(issues)
    contents->extend([ '', '(Click on popup to dismiss. Drag border.)' ])

    i_ui.PopupAlert(contents, ' Splice Configuration ', {center: false, modal: false})
enddef

import './splice_boot.vim'

# This is the entry point for startup, logging/settings have been initialized.
#
var boot_complete: bool
export def SpliceInit9(settings_issues: list<string>)
    if boot_complete
        return
    endif
    boot_complete = true

    try
        i_log.Log('SpliceInit')
        set guioptions+=l

        ConfigureUiHighlights()
        i_keys.InitializeBindings()
    catch
        var failures: list<string>
        failures->extend(startup_error_msgs)
        failures->add(v:exception)
        splice_boot.SpliceBootError(failures, v:throwpoint)
        return
    endtry

    if ! startup_error_msgs->empty()
        splice_boot.SpliceBootError(startup_error_msgs)
        return
    endif
    startup_error_msgs = null_list

    # non-fatal, we have a go for lift-off
    ReportConfigIssues(settings_issues)

    i_result.Init()
    i_search.Init()

    i_log.Log('Splice started.')
enddef

