vim9script

#   If the directory "raelity" exists in the same directory as this file
#   then use it as raelity vim lib; otherwise use the autoload directory.

# for example: "import Rlib('util/strings')"
export def Rlib(raelity_autoload_fname: string): string
    return base_lib_dir .. '/' .. raelity_autoload_fname
enddef

# First look for lib packaged with splice9: autoload/splice9/raelity.
var base_lib_dir: string = fnamemodify(
    getscriptinfo(
        {sid: str2nr(matchstr(expand('<SID>'), '\v\d+'))}
    )[0].name, ':p:h') .. '/rlib/autoload/raelity'

### echomsg '(1)' base_lib_dir
### echomsg '(2)' Rlib('config.vim')

try 
    ### echomsg 'About to import ' Rlib('config.vim')
    # The following import throws if not a local raelity vim lib.
    import Rlib('config.vim')
    # Use the absolute real path (not a possible symbolic link)
    base_lib_dir = config.lib_dir
    ### echomsg '(3) raelities lib_dir:' base_lib_dir
    lockvar base_lib_dir
    ### echomsg 'base_libdir:' base_lib_dir
    finish
catch /E1053/
    echomsg v:exception
    echomsg v:throwpoint
    echomsg 'NOT PACKAGED WITH LIB'
endtry

#set runtimepath^=/src/lib/vim
set runtimepath-=/src/lib/vim

import autoload 'raelity/config.vim' as r_config
base_lib_dir = r_config.lib_dir
lockvar base_lib_dir

### echomsg 'base_libdir:' base_lib_dir
