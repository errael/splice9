vim9script

#   If the directory "raelity" exists in the same directory as this file
#   then use it as raelity vim lib; otherwise use the autoload directory.

# for example: "import Rlib('util/strings')"
export def Rlib(raelity_auto_file: string): string
    return base_lib_dir .. '/' .. raelity_auto_file
enddef

# First look for lib packaged with splice9.
var base_lib_dir: string = fnamemodify(
    getscriptinfo(
        {sid: str2nr(matchstr(expand('<SID>'), '\v\d+'))}
    )[0].name, ':p:h') .. '/raelity'

try 
    import Rlib('/config.vim')
    lockvar base_lib_dir
    #echo 'base_libdir:' base_lib_dir
    finish
catch /E1053/
    #echo 'NOT PACKAGED WITH LIB'
endtry

#set runtimepath^=/src/lib/vim
set runtimepath-=/src/lib/vim

import autoload 'raelity/config.vim' as r_config
base_lib_dir = r_config.lib_dir
lockvar base_lib_dir

#echo 'base_libdir:' base_lib_dir
