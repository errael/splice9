vim9script

#
# Return the full path to use for an import from raelity lib.
# All raelity lib imports should use this function.
# For example do: "import Rlib('util/strings')"
#
export def Rlib(raelity_autoload_fname: string): string
    return rlib_dir .. '/' .. raelity_autoload_fname
enddef

var rlib_dir: string

echomsg '(1)' getscriptinfo({sid: str2nr(matchstr(expand('<SID>'), '\v\d+'))})[0].name    

#   Find the full path of the "raelity" lib for use in import statements.
#   First check if the library is included with splice9, then try autoload.
#   Use the path from the imported config.vim for the rlib imports.
try 
    # First check if the lib is packaged with splice9:
    # Import throws if not a local raelity vim lib.
    import './rlib/autoload/raelity/config.vim'
    # TODO???: import rlib_dir .. '/config.vim'

    # Use the absolute real path (not a possible symbolic link)
    rlib_dir = config.lib_dir
    echomsg '(2) raelity''s rlib_dir:' rlib_dir
    lockvar rlib_dir
    finish
catch /E1053/
    echomsg v:exception
    echomsg v:throwpoint
    echomsg 'NOT PACKAGED WITH LIB'
endtry

#&runtimepath->split(',')->sort()->foreach((_, v) => {
#    echom v
#})

##### DEBUG
#set runtimepath^=/src/lib/vim
set runtimepath-=/src/lib/vim
#####

import autoload 'raelity/config.vim'
rlib_dir = config.lib_dir
lockvar rlib_dir

echomsg '(3) rlib_dir:' rlib_dir
