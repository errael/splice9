vim9script

var standalone_exp = false
if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
    standalone_exp = true
endif

if ! standalone_exp
    import autoload '../../splice.vim'
    import autoload './ui.vim'
else
    import './splice.vim'
    import './ui.vim'
endif

# export Log, LogInit

#
# Logging
#
# LogInit(fname) - enables logging, if first call output time stamp
# Log(string) - append string to Log if logging enabled
#
# NOTE: the log file is never trunctated, persists, grows without limit
#

#
# global for simple access from python
# TODO: AddExclude/AddInclude methods then these can forward to python
#       and won't need global
#
g:splice_logging_exclude = [ 'focus' ]

var fname: string
var logging_enabled: bool = false
#
# Invoked as either Log(msg) or Log(category, msg).
# Check to see if category should be logged.
#
export def Log(arg1: string, arg2: string = null_string)
    if ! logging_enabled
        return
    endif
    # typical case one arg; arg1 is msg
    var msg = arg1
    var category: string = null_string
    if arg2 != null
        category = arg1
        msg = arg2
    endif

    writefile([ msg ], fname, 'a')
enddef

var log_init = false
export def LogInit(_fname: string)
    if !log_init
        fname = _fname
        logging_enabled = true
        writefile([ '', '', '=== ' .. strftime('%c') .. ' ===' ], fname, "a")
        log_init = true
    endif
enddef

# TODO: may add some kind of "how to close" info in E
#       make E dict<dict<any>>
const E = {
    ENOTFILE: ["Current buffer, '%s', doesn't support '%s'", 'Command Issue'],
    ENOCONFLICT: ["No more conflicts"],
}


export def SplicePopup(e_idx: string, ...extra: list<any>)
    var err = E[e_idx]
    var msg = call('printf', [ err[0] ] + extra)
    Log(msg)
    ui.PopupError([msg], err[ 1 : ])
enddef

#defcompile
