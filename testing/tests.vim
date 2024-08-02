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


# This command is executed as part of gvi startup.
# RunTheTest is the main loop.
command -nargs=? RunTheSpliceTest RunTheTest(<f-args>)

var some_error: bool
export def RunTheTest()

    &more = false

    # To create the text for all layouts.
    # test_lib.CollectAllLayouts()

    try
        var items = split($SPLICE_TEST_NAME)
        # NOTE: RunFuncTest throws a result, so nothing comes after it.
        RunFuncTest(items[0], items[1 : ])
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
    if $SPLICE_WAIT_AFTER_TEST->empty()
        :cq
    endif
enddef

def RunFuncTest(F: any, args: list<any>)
    #v:errors = ['foo', 'bar']
    if !v:errors->empty()
        #i_log.Log(() => printf('RunFuncTest ENTRY %s: %s', F, v:errors), 'splice_test_error')
        #echom printf('RunFuncTest ENTRY %s: %s', F, v:errors)
        ReportTestError(() => printf('RunFuncTest ENTRY %s: %s', F, v:errors))
        v:errors = []
    endif

    some_error = false
    call(F, [F, args])
    ReportFileSelectCount() # does nothing if no tests were run
    CheckReportTestErrors(F, args)

    if some_error
        echom printf('RunFuncTest EXIT: %s', v:errors)
        throw printf('FAIL: RunFuncTest: %s(%s)', F, args)
    endif
    echom printf("Finished %s", F)
    throw printf('SUCCESS:')
enddef

# "TheTest" is typically a lambda and any args can be provided
# where the lambda is defined.
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

import golden_dir .. '/xform.vim' as i_xform

def TestAllFileSelect(F: any, args: list<any>)
    if !args->empty()
        TestGroupFileSelect(F, args)
        return
    endif

    # Put all the tests in a single list. Each list element looks like
    #       ['Path' args_list]
    # The first list item is used to select the fuction to perform the test.
    var tests: list<any>

    tests->extend(i_xform.comp_xform->mapnew((_, targs) => ['Comp', targs]))
    tests->extend(i_xform.loup_xform->mapnew((_, targs) => ['Loup', targs]))
    tests->extend(i_xform.path_xform->mapnew((_, targs) => ['Path', targs]))
    tests->extend(i_xform.grid0_xform->mapnew((_, targs) => ['Grid0', targs]))
    tests->extend(i_xform.grid1_xform->mapnew((_, targs) => ['Grid1', targs]))

    for [cap_mode, test_args] in i_lists.ListRandomize(tests)
        TestAnyFileSelect(cap_mode, test_args, F, args)
    endfor
enddef

def TestGroupFileSelect(F: any, args: list<any>)
    var cap_mode = args[0]
    execute('g:SpliceXformListGlobalTemp = i_xform.' .. tolower(cap_mode) .. '_xform')
    var tests = g:SpliceXformListGlobalTemp
    unlet g:SpliceXformListGlobalTemp
    for test_args in i_lists.ListRandomize(tests)
        TestAnyFileSelect(cap_mode, test_args, F, args)
    endfor
enddef

def ReportFileSelectCount()
    if file_select_test_count->values()->reduce((acc, val) => acc + val) != 0
        ReportTest(() => printf('TestFileSelectCount: %s', file_select_test_count))
    endif
enddef

var file_select_test_count: dict<number> =
{
    Grid0:  0,
    Grid1:  0,
    Comp:   0,
    Path:   0,
    Loup:   0,
}

####################
#
# FileSelect is the execution of '-o', '-1', '-2', '-r'. Any of these commands
# may change a file in a window and/or the window that is focused. Each test
# has two methods, the first to initialize and the second to test the outcom
# seperated by the FileSelect command.
#
# There are 5 modes to test, Grid is split into two; the functions are
# similarly named so the mode 
#

def TestAnyFileSelect(cap_mode: string, xform: list<any>, F: any, args: list<any>)
    Run1Test(F, args, () => {
        ReportTest(() => printf('%s: Test%sFileSelect: XFORM: %s', cap_mode, cap_mode, xform))
        file_select_test_count[cap_mode] += 1

        call('test_lib.SelectAndFocus' .. cap_mode .. 'Files', [xform])
        # ReportTest(() => printf("%sSel: before feedkeys: %s", cap_mode, CurModeState()))

        # Apply the command, like '-1', '-r'.
        feedkeys(xform[1], 'x')

        call('test_lib.Check' .. cap_mode .. 'FileSelect', [xform])
    })
enddef

