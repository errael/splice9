" ============================================================================
" File:        splice.vim
" Description: vim global plugin for resolving three-way merge conflicts
" Maintainer:  Ernie Rael <errael@sraelity.com>
" License:     MIT X11
" ============================================================================

" Init

" Vim version check

if ! has('vim9script') || v:versionlong < 9010000 + 0369
    let s:patch = 0369
    let s:minver = 9010000 + s:patch

    " TODO: if vim >= 9 then do popup 

    "echomsg 'The installed Splice Merge Tool plugin'
    "echomsg 'requires vim9script and vim version 9.1'

    echomsg 'The installed Splice Merge Tool plugin requires vim9script'
    echomsg 'and vim version 9.1 with patch level ' .. s:patch .. '.'
    echomsg ' '
    echomsg 'Check Vim and Splice versions and configurations.'
    echomsg 'Running version: ' .. v:version
    echomsg ' '
    echomsg ' '
    command! -nargs=0 Splice9Init :cq

    "echomsg ' '
    "echomsg 'Since the merge can not be completed, the merge'
    "echomsg 'should be aborted so it can be completed later.'
    "echomsg ' '
    "echomsg 'NOTE: the vim command ":cq" aborts the merge.'

    finish
endif

vim9script

# NOTE: The following is grabbed by shell to label the release zip
export const splice9_string_version = "1.0.0-beta1-dev"

# TODO: SHOULD THERE BE A SPLICE COMMAND IF VERSION PREVENTS RUNNING?

# call test_override('autoload', 1)

var ReleaseFlag = false

if ReleaseFlag
    # For release
    import autoload '../autoload/splice9/splice.vim'
    command! -nargs=0 Splice9Init call splice.SpliceBoot()
else
    # For development
    import autoload '../autoload/splice9dev/splice.vim'
    command! -nargs=0 Splice9DevInit call splice.SpliceBoot()
endif


# Multiple versions of splice9 can be made available. An additional version
# must have a unique directory name under autoload, for example
#       splice9/autoload/splice9_0_9_RC2
# and modify splice9/plugin/splice.vim (this file) as follows
#       var tag = "0.9-RC2"->substitute('[-\.]', '_', 'g')
#       import autoload '../autoload/splice9_' .. tag .. '/splice.vim'
#       command! -nargs=0 Splice9VersionInit call splice.SpliceBoot()
# and do `gvim -c Splice9VersionInit ...`



# TODO: wonder what this condition is all about, seems to have been optimized away
var loaded_splice: number
if !exists('g:splice_debug') && (exists('g:splice_disable') || loaded_splice > 0 || &cp)
    finish
endif
loaded_splice = 1

