vim9script
# ============================================================================
# File:        splice.vim
# Description: vim global plugin for resolving three-way merge conflicts
# Maintainer:  Steve Losh <steve@stevelosh.com>
# License:     MIT X11
# ============================================================================

# import keys.vim, without "as", causes keys() usage to get an error
import autoload './splicelib/util/keys.vim' as i_keys
import autoload './splicelib/util/log.vim'
import autoload './splicelib/util/search.vim'
import autoload './splicelib/util/vim_assist.vim'
import autoload './splicelib/hud.vim'
import autoload './splicelib/init.vim'
import autoload './splicelib/settings.vim'

var Log = log.Log

#
# TODO: higlights from settings
#
export var hl_label = 'SpliceLabel'
export var hl_sep = 'SpliceLabel'
export var hl_command = 'SpliceCommand'
export var hl_rollover = 'Pmenu'
export var hl_active = 'Keyword'
export var hl_alert_popup = 'Pmenu'
export var hl_popup = 'ColorColumn'

highlight SpliceCommand term=bold cterm=bold gui=bold
highlight SpliceLabel term=underline ctermfg=6 guifg=DarkCyan


#export final UNIQ = []

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

# assume the worst
var has_supported_python = 0
var splice_pyfile: string

var startup_error_msgs: list<string>

# user can enable/disable, specify log file
# default is no logging, ~/SPLICELOG
# NOTE: the log file is never trunctated, persists, grows without limit
var fname = g:->get('splice_log_file', $HOME .. '/SPLICE_LOG')
if g:->get('splice_log_enable', v:false)
    log.LogInit(fname)
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
        log.Log('ERROR: ' .. msg)
    endfor
    if has_supported_python != 0
        delcommand SplicePython
    endif
    SpliceDidNotLoad()
enddef

var Main: func

var startup_col: number
def Trampoline(id: number)
    if startup_col != &co
        Log(printf("COLUMN MISMATCH: after pause: startup_col: %d, col: %d",
            startup_col, &co))
        &columns = startup_col
    endif
    Main()
enddef

export def SpliceBoot()
    log.Log('SpliceBoot')
    log.Log('SpliceBoot DEV')
    if !!has_supported_python && startup_error_msgs->empty()
        startup_col = &columns
        timer_start(50, Trampoline)
        return
    endif

    # A FATAL ERROR
    SpliceBootError()
enddef

# Now the boot/startup functions are defined,
# check if we've got a usable python.
# And it's ok to finish

if has('python3')
    has_supported_python = 3
    splice_pyfile = 'py3file'
    command! -nargs=1 SplicePython python3 <args>
elseif has('python')
    has_supported_python = 2
python << trim ENDPYTHON
    import sys, vim
    if sys.version_info[:2] < (2, 5):
        vim.command('has_supported_python = 0')
ENDPYTHON
    splice_pyfile = 'pyfile'
    command! -nargs=1 SplicePython python <args>
endif

if has_supported_python == 0
    startup_error_msgs += [ "Splice requires Vim to be compiled with Python 2.5+" ]
    finish
endif

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
    #echo 'winid:' winid 'bufer:' bufnr
    #setbufline(bufnr, 2, "HOW COOL")
enddef

def ReportStartupIssues()
    if startup_error_msgs != []
        # TODO: timer_start, 200ms?
        #       avoids vim width issue (I think that was it)
        UserConfigError(startup_error_msgs)
    endif
enddef


def SetupSpliceCommands()
    command! -nargs=0 SpliceGrid     SplicePython SpliceGrid()
    command! -nargs=0 SpliceLoupe    SplicePython SpliceLoupe()
    command! -nargs=0 SpliceCompare  SplicePython SpliceCompare()
    command! -nargs=0 SplicePath     SplicePython SplicePath()

    command! -nargs=0 SpliceOriginal SplicePython SpliceOriginal()
    command! -nargs=0 SpliceOne      SplicePython SpliceOne()
    command! -nargs=0 SpliceTwo      SplicePython SpliceTwo()
    command! -nargs=0 SpliceResult   SplicePython SpliceResult()

    command! -nargs=0 SpliceDiff     SplicePython SpliceDiff()
    command! -nargs=0 SpliceDiffOff  SplicePython SpliceDiffOff()
    command! -nargs=0 SpliceScroll   SplicePython SpliceScroll()
    command! -nargs=0 SpliceLayout   SplicePython SpliceLayout()
    command! -nargs=0 SpliceNext     SplicePython SpliceNext()
    command! -nargs=0 SplicePrevious SplicePython SplicePrev()
    command! -nargs=0 SpliceUseHunk  SplicePython SpliceUse()
    command! -nargs=0 SpliceUseHunk1 SplicePython SpliceUse1()
    command! -nargs=0 SpliceUseHunk2 SplicePython SpliceUse2()

    command! -nargs=0 SpliceQuit i_keys.SpliceQuit()
    command! -nargs=0 SpliceCancel i_keys.SpliceCancel()

    # The ISxxx come in from python
    command! -nargs=0 ISpliceActivateGridBindings i_keys.ActivateGridBindings()
    command! -nargs=0 ISpliceDeactivateGridBindings i_keys.DeactivateGridBindings()
    command! -nargs=? ISpliceNextConflict search.MoveToConflict(<args>)
    command! -nargs=0 ISpliceAllConflict search.HighlightConflict()
    command! -nargs=* ISpliceDrawHUD hud.DrawHUD(<args>)

    command! -nargs=* ISplicePopup log.SplicePopup(<args>)
enddef

def SpliceInit9()
    log.Log('SpliceInit')
    set guioptions+=l
    # startup_error_msgs should already be empty
    startup_error_msgs = settings.InitSettings()
    var python_module = fnameescape(globpath(&runtimepath, 'autoload/splice9Dev/splice.py'))
    echom python_module
    exe splice_pyfile python_module
    SetupSpliceCommands()
    i_keys.InitializeBindings()
    ReportStartupIssues()
    log.Log('starting splice')

    init.Init()
    SplicePython SpliceInit()
enddef

Main = SpliceInit9

#TestSettings()
