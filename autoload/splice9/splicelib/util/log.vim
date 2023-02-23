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

g:splice_logging_exclude = [ 'focus', 'result' ]
#g:splice_logging_exclude = []

var fname: string
var logging_enabled: bool = false

# TODO: popup
def Logging_problem(s: string)
    echomsg expand("<stack>")
    echomsg s
enddef

#
# Invoked as either
#       - Log(msg)
#       - Log(func(): string)
#       - Log(category, msg)
#       - Log(category, func(): string)
# Check to see if category should be logged.
# NOTE: category is checked with ignore case
#
export def Log(...args: list<any>)
    if ! logging_enabled
        return
    endif
    var len = args->len()
    if len < 1 || len > 2
        Logging_problem(printf("LOGGING ARGS PROBLEM (PLEASE REPORT): %s.", args))
        return
    endif
    var category: any
    var MsgOrFunc: any
    if len == 1
        category = ''
        MsgOrFunc = args[0]
    else
        [ category, MsgOrFunc ] = args
        if type(category) != v:t_string
            Logging_problem(printf("LOGGING CATEGORY PROBLEM (PLEASE REPORT): %s.", category))
            category = ''
        endif
    endif
    if g:splice_logging_exclude->index(category, 0, true) >= 0
        return
    endif
    var msg_type = type(MsgOrFunc)
    var msg: string
    if msg_type == v:t_string 
        msg = MsgOrFunc
    elseif msg_type == v:t_func
        try
            msg = MsgOrFunc()
        catch /.*/
            Logging_problem(printf("LOGGING ARG FUNC PROBLEM (PLEASE REPORT): %s.", args))
            return
        endtry
    else
            Logging_problem(printf("LOGGING ARG TYPE PROBLEM (PLEASE REPORT): %s.", args))
            return
    endif

    if !!category
        category = category->toupper() .. ': '
    endif

    msg = category .. msg

    writefile([ msg ], fname, 'a')
enddef
### #
### # Invoked as either Log(msg) or Log(category, msg).
### # Check to see if category should be logged.
### #
### export def Log(arg1: string, arg2: string = null_string)
###     if ! logging_enabled
###         return
###     endif
###     # typical case one arg; arg1 is msg
###     var msg = arg1
###     if arg2 != null
###         # category is arg1
###         if g:splice_logging_exclude->index(arg1) >= 0
###             return
###         endif
###         msg = arg2
###     endif
### 
###     writefile([ msg ], fname, 'a')
### enddef

export def LogStack(tag: string = '')
    Log(tag .. ': ' .. expand('<stack>'))
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
