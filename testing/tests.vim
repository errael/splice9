vim9script

import autoload 'raelity/config.vim'
import autoload config.Rlib('util/lists.vim') as i_lists
import autoload config.Rlib('util/log.vim') as i_log

var golden_dir = $GOLD_DIR ?? '/src/tools/splice9/testing/golden'

import './test_lib.vim'
const CmdLayout = test_lib.CmdLayout
const CmdNormal = test_lib.CmdNormal
const CurModeState = test_lib.CurModeState
const CompareLayout = test_lib.CompareLayout
const SelectAndFocusCompFiles = test_lib.SelectAndFocusCompFiles
const CheckCompFileSelect = test_lib.CheckCompFileSelect
const ReportTest = test_lib.ReportTest
const ReportTestError = test_lib.ReportTestError


# This command is executed as part of gvi startup.
# RunTheTest is the main loop.
command -nargs=? RunTheSpliceTest RunTheTest(<f-args>)

var some_error: bool
export def RunTheTest()

    &more = false

    #test_lib.CollectAllLayouts()

    #timer_start(1000, Run1)
    try
        RunFuncTest($SPLICE_TEST_NAME)
    catch
        # Note, using 'x' in the following leaves things in a screwy situation
        echom 'MODE after done with tests:' mode(true)
    endtry
    CmdNormal()
    if $SPLICE_QUIT_AFTER_TEST != ''
        :cq
    endif
enddef

def RunFuncTest(F: any, ...args: list<any>)
    # v:errors = ['foo', 'bar']
    if !v:errors->empty()
        i_log.Log(() => printf('RunFuncTest ENTRY %s: %s', F, v:errors), 'splice_test_error')
        echom printf('RunFuncTest ENTRY %s: %s', F, v:errors)
        v:errors = []
    endif
    some_error = false
    call(F, [F, args])
    CheckReportTestErrors(F, args)
    if some_error
        echom printf('RunFuncTest EXIT: %s', v:errors)
        throw printf('FAIL: RunFuncTest: %s(%s)', F, args)
    endif
    echom printf("Finished %s", F)
    throw printf('SUCCESS:')
enddef

def Run1Test(F: any, args: list<any>, TheTest: func)
    TheTest()
    CheckReportTestErrors(F, args)
enddef

def CheckReportTestErrors(F: any, args: list<any>)
    if !v:errors->empty()
        v:errors->foreach((_, error) => {
            i_log.Log(() => printf('RunFuncTest: %s', error), 'splice_test_error')
        })
        i_log.Log(() => printf('RunFuncTest FAIL: %s(%s)', F, args), 'splice_test_error')
        some_error = true
        v:errors = []
    endif
enddef

######################################################################
#
# The major tests, bulk of work typically done in test_lib.vim
#

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

# TODO: option to not randomize

def TestAllLayouts(F: any, args: list<any>)
    for [mode, layout_idx] in i_lists.ListRandomize(all_layouts)
        Run1Test(F, args, () => {
            ReportTest(() => printf('TestAllLayouts: %s', [mode, layout_idx]))
            CmdLayout(mode, layout_idx)
            CompareLayout(mode, layout_idx)
        })
    endfor
enddef

import golden_dir .. '/comp_xform.vim' as i_comp_xform
#const comp_xform_one_two = i_comp_xform.comp_xform_one_two
const comp_xform_all = i_comp_xform.comp_xform_all

def TestAllFileSelect()
    TestAllCompFileSelect()
enddef

var test_stuff = [
    [ 1, 'orig',  'result',  '-1'],
    [ 1, 'orig',  'one',     '-2'],
    [ 2, 'orig',  'two',     '-1'],

    [ 2, 'one',   'result',  '-2'],
    [ 1, 'one',   'result',  '-2'],

    [ 2, 'one',   'result',  '-o'],
    [ 1, 'one',   'result',  '-r'],

    [ 1, 'two',   'result',  '-1'],
    [ 1, 'one',   'two',     '-2'],
    [ 2, 'one',   'two',     '-2'],
]

def TestAllCompFileSelect(F: any, args: list<any>)
    #var [focus: number, left: string, right: string, cmd: string] = comp_xform
    #for comp_xform in test_stuff
    #for comp_xform in i_lists.ListRandomize(flattennew([comp_xform_all, test_stuff], 1))
    for comp_xform in i_lists.ListRandomize(comp_xform_all)
        Run1Test(F, args, () => {
            ReportTest(() => printf('TestAllCompFileSelect: XFORM: %s', comp_xform))
            SelectAndFocusCompFiles(comp_xform)
            var state: any
            # ReportTest(() => printf("CompSel: before feedkeys: %s", CurModeState()))
            # Apply the command, like '-1', '-r'.
            feedkeys(comp_xform[3], 'x')

            CheckCompFileSelect(comp_xform)
        })
    endfor
enddef

