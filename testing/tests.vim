vim9script

import autoload 'raelity/config.vim'
import autoload config.Rlib('util/lists.vim') as i_lists
import autoload config.Rlib('util/log.vim') as i_log

import './test_lib.vim'
const CmdLayout = test_lib.CmdLayout
const CmdNormal = test_lib.CmdNormal
const CompareLayout = test_lib.CompareLayout

command -nargs=? RunTheSpliceTest RunTheTest(<f-args>)

export def RunTheTest()
    #timer_start(1000, Run1)
    RunFuncTest($SPLICE_TEST_NAME)
    CmdNormal()
enddef

def RunFuncTest(F: any, ...args: list<any>)
    v:errors = ['foo']
    if true || !v:errors->empty()
        i_log.Log(() => printf('RunFuncTest ENTRY %s: %s', F, v:errors), 'splice_test_error')
        echom printf('RunFuncTest ENTRY %s: %s', F, v:errors)
        v:errors = []
    endif
    call(F, args)
    if !v:errors->empty()
        i_log.Log(() => printf('RunFuncTest EXIT: %s', v:errors), 'splice_test_error')
        i_log.Log(() => printf('FAIL: RunFuncTest: %s(%s)', F, args), 'splice_test_error')
        echom printf('RunFuncTest EXIT: %s', v:errors)
        throw printf('FAIL: RunFuncTest: %s(%s)', F, args)
    endif
enddef

var all_layouts = [
    ['grid', 0],
    ['grid', 1],
    ['grid', 2],
    ['loup', 0],
    ['comp', 0],
    ['comp', 1],
    ['path', 0],
    ['path', 1],
]

var golden_dir = $GOLD_DIR ?? '/src/tools/splice9/testing/golden'
import golden_dir .. '/layouts' as i_layouts

# TODO: option to not randomize

def TestAllLayouts()
    for t in i_lists.ListRandomize(all_layouts)
    echom printf('TestAllLayouts: %s', t)
    i_log.Log(() => printf('TestAllLayouts: %s', t), 'splice_test')
    CmdLayout(t[0], t[1])
    CompareLayout(t[0], t[1])
    endfor
enddef


