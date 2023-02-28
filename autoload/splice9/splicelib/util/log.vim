vim9script

var standalone_exp = false
if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
    standalone_exp = true
endif

if ! standalone_exp
    # TODO: bad import
    #import autoload '../../splice.vim'
    import autoload './ui.vim'
    import autoload './vim_assist.vim'
else
    #import './splice.vim'
    import './ui.vim'
    import './vim_assist.vim'
endif

# export Log, LogInit

const IndentLtoS = vim_assist.IndentLtoS
const Scripts = vim_assist.Scripts

#
# Logging
#
# LogInit(fname) - enables logging, if first call output time stamp
# Log(string) - append string to Log if logging enabled
#
# NOTE: the log file is never trunctated, persists, grows without limit
#

# TODO: put this somewhere else: maybe copy it to g:loggin_exclude
#
g:splice_logging_exclude = [ 'focus', 'result', 'setting' ]
#
#g:splice_logging_exclude = []

var fname: string
var logging_enabled: bool = false

# TODO: popup?
def Logging_problem(s: string)
    Log(s, 'internal_error', true, '')
    echomsg expand("<stack>")
    echomsg s
enddef

#
# Conditionally log to a file based on enable and optional category.
# The message is split by "\n" and passed to writefile()
# Output example: "The log msg"
# Output example: "CATEGORY: The log msg"
# NOTE: category is checked with ignore case, output as upper case
#
#   - Log(msg: string [, category = ''[, stack = true[, command = '']]])
#   - Log(func(): string [, category = ''[, stack = true[, command = '']]])
#
# If optional stack is true, the stacktrace from where Log is called
# is output to the log.
#
# If optional command, the command is run using execute() and the command
# output is output to the log.
#
export def Log(msgOrFunc: any, category: string = '',
        stack: bool = false, command: string = '')
    if ! logging_enabled
        return
    endif
    if !!category && g:splice_logging_exclude->index(category, 0, true) >= 0
        return
    endif

    var msg: string
    if !!category
        msg = category->toupper() .. ': '
    endif

    var msg_type = type(msgOrFunc)
    if msg_type == v:t_string 
        msg ..= <string>msgOrFunc
    elseif msg_type == v:t_func
        try
            var F: func = msgOrFunc
            msg ..= F()
        catch /.*/
            Logging_problem(printf("LOGGING USAGE BUG: FUNC: %s, caught %s.",
                typename(msg), v:exception))
            return
        endtry
    else
            Logging_problem(printf("LOGGING USAGE BUG: msg TYPE: %s.", typename(msgOrFunc)))
            return
    endif

    if stack
        msg ..= "\n  stack:"
        var stack_info = StackTrace()->slice(1)
        msg ..= "\n" .. IndentLtoS(stack_info)
    endif

    if !!command
        msg ..= "\n" .. "  command '" .. command .. "' output:"
        try
            msg ..= "\n" .. execute(command)->split("\n")->IndentLtoS()
        catch /.*/
            Logging_problem(printf("LOGGING USAGE BUG: command : %s, caught: %s.",
                command, v:exception))
            return
        endtry
    endif

    writefile(msg->split("\n"), fname, 'a')
enddef

#
# TODO: integrate into Log(msg, cat, cmd, stack)
#
# Run a command, and put it into the log.
# Optionally include stacktrace, optionally specify logging category
# NOTE: this implementation builds a string and minimizes direct list
#       manipulation, I think this a performance improvement,
#       for example, IndentLtoS(list<string>) uses list->join("\n    ").
##### export def LogCmd(msg: string, category: string = '',
#####         cmd: string = '', do_stack: bool = false)
#####     var accum = msg
#####     if do_stack
#####         accum ..= "\n  stack:"
#####         var stack = StackTrace()->slice(1)
#####         accum ..= "\n" .. IndentLtoS(stack)
#####     endif
#####     if !!cmd
#####         accum ..= "\n" .. "  command '" .. cmd .. "' output"
#####         accum ..= "\n" .. execute(cmd)->split("\n")->IndentLtoS()
#####     endif
#####     Log(category, accum)
##### enddef

# Run a comand and log it. Optionally include a stack trace
#export def LogCmd(tag: string, cmd: string, do_stack: bool = false)
#    echo tag
#    if !!do_stack
#        echo '  stack:'
#        var stack = StackTrace()->slice(1)
#        echo IndentLtoS(stack)
#    endif
#    echo "  '" .. cmd .. "' output"
#    echo execute(cmd)->split("\n")->IndentLtoS()
#enddef

# return list of stack frame titles, TOS first, don't include StackTrace()
# optionally convert <SNR>##_ to file name
#export def StackTrace(do_fname: bool = false): list<string>
#    # slice(1) to remove this function from the trace
#    # TODO: using Scripts do filename
#    return expand('<stack>')->split('\.\.')->reverse()->slice(1)
#enddef
var scripts_cache = Scripts()
export def StackTrace(): list<string>
    # slice(1): don't include this function in trace
    var stack = expand('<stack>')->split('\.\.')->reverse()->slice(1)
    stack->map((_, frame) => {
        return FixStackFrame(frame)
    })
    return stack
enddef
def FixStackFrame(frame: string): string
    # nPath is the number of path components to include
    const nPath = 2
    var m = matchlist(frame, '\v\<SNR\>(\d+)_')
    if !!m
        for _ in [1, 2]
            var path = scripts_cache->get(m[1], '')
            if !!path
                var p = path->split('[/\\]')[- nPath : ]->join('/')
                return substitute(frame, '\v\<SNR\>\d+_', p .. '::', '')
            endif
            Scripts(scripts_cache) # executes first iteration, 2nd breaks
        endfor
    elseif frame->stridx('#') >= 0
        var path = frame->split('#')
        var function = path->remove(-1)
        return '#' .. path[- nPath : ]->join('/') .. '.vim::' .. function
    endif
    return frame
enddef

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

