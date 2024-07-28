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
const ReportTest = test_lib.ReportTest
const ReportTestError = test_lib.ReportTestError

const SelectAndFocusLoupFiles   = test_lib.SelectAndFocusLoupFiles
const CheckLoupFileSelect       = test_lib.CheckLoupFileSelect
const SelectAndFocusPathFiles   = test_lib.SelectAndFocusPathFiles
const CheckPathFileSelect       = test_lib.CheckPathFileSelect
const SelectAndFocusGrid0Files  = test_lib.SelectAndFocusGrid0Files
const CheckGrid0FileSelect      = test_lib.CheckGrid0FileSelect
const SelectAndFocusGrid1Files  = test_lib.SelectAndFocusGrid1Files
const CheckGrid1FileSelect      = test_lib.CheckGrid1FileSelect

const SelectAndFocusCompFiles   = test_lib.SelectAndFocusCompFiles
const CheckCompFileSelect       = test_lib.CheckCompFileSelect


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
    catch /^FAIL:/
    catch /^SUCCESS:/
        # Note, using 'x' in the following leaves things in a screwy situation
        echom 'MODE after done with tests:' mode(true)
    catch
        ReportTestError(() => printf("%s", v:exception))
        ReportTestError(() => printf("%s", v:throwpoint))
        ReportTestError(() => printf('Test failed with random exception'))
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
import golden_dir .. '/xform.vim' as i_xform
#const comp_xform_one_two = i_comp_xform.comp_xform_one_two
const comp_xform = i_comp_xform.comp_xform
const comp_xform_small_test = i_comp_xform.comp_xform_small_test
const loup_xform = i_xform.loup_xform
const path_xform = i_xform.path_xform
const grid0_xform = i_xform.grid0_xform
const grid1_xform = i_xform.grid1_xform

def TestAllFileSelect(F: any, args: list<any>)
    # Put all the tests in a single list. Each list element looks like
    #       ['grid' args_list]
    # The first list item is used to select the fuction to perform the test.
    var file_select_tests: list<any>

    file_select_tests->extend(comp_xform->mapnew((_, test_args) => ['Comp', test_args]))
    file_select_tests->extend(loup_xform->mapnew((_, test_args) => ['Loup', test_args]))
    file_select_tests->extend(path_xform->mapnew((_, test_args) => ['Path', test_args]))
    file_select_tests->extend(grid0_xform->mapnew((_, test_args) => ['Grid0', test_args]))
    file_select_tests->extend(grid1_xform->mapnew((_, test_args) => ['Grid1', test_args]))

    for [cap_mode, test_args] in i_lists.ListRandomize(file_select_tests)
        echom cap_mode string(test_args)
        TestAnyFileSelect(cap_mode, test_args, F, args)
    endfor

    ReportTest(() => printf('TestFileSelectCount: %s', file_select_test_count))
enddef

var funcs: dict<func> = {
    SelectAndFocusLoupFiles:    function(SelectAndFocusLoupFiles),
    CheckLoupFileSelect:        function(CheckLoupFileSelect),
    SelectAndFocusPathFiles:    function(SelectAndFocusPathFiles),
    CheckPathFileSelect:        function(CheckPathFileSelect),
    SelectAndFocusGrid0Files:   function(SelectAndFocusGrid0Files),
    CheckGrid0FileSelect:       function(CheckGrid0FileSelect),
    SelectAndFocusGrid1Files:   function(SelectAndFocusGrid1Files),
    CheckGrid1FileSelect:       function(CheckGrid1FileSelect),
    SelectAndFocusCompFiles:    function(SelectAndFocusCompFiles),
    CheckCompFileSelect:        function(CheckCompFileSelect),
}

var file_select_test_count: dict<number> =
{
    Grid0:  0,
    Grid1:  0,
    Comp:   0,
    Path:   0,
    Loup:   0,
}

def TestAnyFileSelect(cap_mode: string, xform: list<any>, F: any, args: list<any>)
    Run1Test(F, args, () => {
        ReportTest(() => printf('Test%sFileSelect: XFORM: %s', cap_mode, xform))
        file_select_test_count[cap_mode] += 1

        # call('SelectAndFocus' .. cap_mode .. 'Files', [xform])
        funcs['SelectAndFocus' .. cap_mode .. 'Files'](xform)

        # ReportTest(() => printf("%sSel: before feedkeys: %s", cap_mode, CurModeState()))
        # Apply the command, like '-1', '-r'.
        feedkeys(xform[1], 'x')

        #call('Check' .. cap_mode .. 'FileSelect', [xform])
        funcs['Check' .. cap_mode .. 'FileSelect'](xform)
    })
enddef

