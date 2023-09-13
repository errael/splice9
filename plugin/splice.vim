" ============================================================================
" File:        splice.vim
" Description: vim global plugin for resolving three-way merge conflicts
" Maintainer:  Steve Losh <steve@stevelosh.com>
" License:     MIT X11
" ============================================================================

" Init

" Vim version check

if ! has('vim9script') || v:versionlong < 9000000 + 1880
    let s:patch = 1880
    let s:minver = 9000000 + s:patch

    " TODO: if vim >= 9 then do popup 

    echomsg 'The installed Splice Merge Tool plugin requires vim9script'
    echomsg 'and vim version 9.0 with patch level ' .. s:patch .. '.'
    echomsg ' '
    echomsg 'Check Vim and Splice versions and configurations.'
    "echomsg ' '
    "echomsg 'Since the merge can not be completed, the merge'
    "echomsg 'should be aborted so it can be completed later.'
    "echomsg ' '
    "echomsg 'NOTE: the vim command ":cq" aborts the merge.'
    echomsg ' '
    echomsg ' '

    finish
endif

vim9script

g:splice9_string_version = "0.9-RC2"

# TODO: SHOULD THERE BE A SPLICE COMMAND IF VERSION PREVENTS RUNNING?

# Setting up splice9Dev
# Create shadow tree symlink to dev sources
# in ~/.vim/pack/random-packages/start/splice-vim-dev/autoload
#       cp -as /src/tools/splice.vim/autoload/splice9/ splice9Dev
# Tweaks: "splice9" --> "splice9Dev" (which should go away with vim9 only)
#       autoload/splice9/splice.py
#                       also: log.Log('SpliceBoot DEV')
#       autoload/splice9/splice.vim
#

# call test_override('autoload', 1)

var dev = false
if dev
    import autoload '/home/err/.vim/pack/random-packages/start/splice-vim-dev/autoload/splice9Dev/splice.vim'
    command! -nargs=0 SpliceInitDev call splice.SpliceBoot()
else
    import autoload '../autoload/splice9/splice.vim'
    command! -nargs=0 Splice9Init call splice.SpliceBoot()
endif

#var patch = 4932
#var longv = 8020000 + patch

#if v:versionlong < longv
#    splice.RecordBootFailure(
#        ["Splice unavailable: requires Vim 8.2." .. patch])
#    finish
#endif

# TODO: wonder what this condition is all about, seems to have been optimized away
var loaded_splice: number
if !exists('g:splice_debug') && (exists('g:splice_disable') || loaded_splice > 0 || &cp)
    finish
endif
loaded_splice = 1

