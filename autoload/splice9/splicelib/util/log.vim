vim9script

var import_autoload = true
#if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
#    import_autoload = false
#endif

if import_autoload
    import autoload './ui.vim'
    import autoload './vim_assist.vim'
else
    import './ui.vim'
    import './vim_assist.vim'
endif

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

var fname: string
var logging_enabled: bool = false
var logging_exclude: list<string>

# Maybe AddExclude/RemoveExclude methods in here.
export def SetExcludeCategories(excludes: list<string>)
    logging_exclude = excludes
enddef

# TODO: popup?
def Logging_problem(s: string)
    Log(s, 'internal_error', true, '')
    echomsg expand("<stack>")
    echomsg s
enddef

#
# Conditionally log to a file based on logging enabled and optional category.
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
    if !!category && logging_exclude->index(category, 0, true) >= 0
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
# TODO: This should not be in log.vim, either import or put popup elsewhere
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


