vim9script

import autoload 'raelity/config.vim'
import autoload config.Rlib('util/lists.vim') as i_lists
import autoload config.Rlib('util/log.vim') as i_log

var golden_dir = $GOLD_DIR ?? '/src/tools/splice9/testing/golden'

# LayoutWithBufferNames(tabnr = tabpagenr()): list<any>
# LayoutPrettyPrint(layout: list<any>, depth = 0): list<string>

command! -nargs=* AA RunFuncTest('XCmdLayout', <f-args>)
command! -nargs=+ AB RunFuncTest('XCompareLayout', <f-args>)
#command! -nargs=* AA {
#    var args = eval('[ <f-args> ]')
command! -nargs=0 A1 echo g:SpliceCollectModeState()
command! -nargs=0 A2 echo CurModeState()

export def ReportTest(MsgFunc: func(): string)
    var msg = MsgFunc()
    echom msg
    i_log.Log(msg, 'splice_test')
enddef

export def ReportTestError(MsgFunc: func(): string)
    var msg = MsgFunc()
    echom msg
    i_log.Log(msg, 'splice_test_error')
enddef

#def Run1(tid: number)
#    feedkeys("\<CR>")
#    timer_start(1000, Run2)
#enddef
#
#def Run2(tid: number)
#    echom '=== RunTheTest ==='
#enddef

######################################################################
#
# Commands that "use" splice, acting like a Splice user.
# feedkeys
#

# Try to get to normal mode; send an ESC if not in normal mode"
export def CmdNormal()
    def PM(tid: number = 0)
        if tid >= 0
            var vim_mode = mode(true)
            # note there's a state() function; SafeState autocmd
            if vim_mode != 'n'
                i_log.Log(() => printf('CmdNormal: mode: %s, tid: %d', vim_mode, tid), 'splice_test')
                CmdESC()
                CmdESC(false)
            endif
        endif
    enddef
    #PM(-1)
    # Need to wait for idle before testing
    timer_start(0, PM)
enddef

export def CmdESC(wait = true)
    var fk_mode = ''
    if wait
        fk_mode ..= 'x'
    endif
    feedkeys("\<ESC>", fk_mode)
enddef

# TODO: return a class
export def CurModeState(): dict<any>
    var state: dict<any> = g:SpliceCollectModeState()
    var active_state = state[state.current_mode]
    active_state.bufnr = state.bufnr
    active_state.winnr = state.winnr
    active_state.name = bufname(state.bufnr)->ShortName()

    # winnr to bufnr
    var winmap: dict<number>
    getwininfo()->foreach((_, w) => {
        winmap[w.winnr] = w.bufnr
    })
    var winmap_name: dict<string>
    winmap->foreach((k, bnr) => {
        winmap_name[k] = bufname(bnr)->ShortName()
    })

    active_state.winmap = winmap
    active_state.winmap_name = winmap_name
    return active_state
enddef

var ModeKeys = {
    grid:   '-g',
    comp:   '-c',
    loup:   '-l',
    path:   '-p'
}
export def CmdMode(mode: string)
    feedkeys(ModeKeys[mode], 'x')
enddef

# Put Splice into given mode,layout
# mode == '' means no change in mode; layout idx defaults to 0
export def CmdLayout(mode: string = '', layout_idx: number = 0)
    if mode != ''
        CmdMode(mode)
    endif
    var state = CurModeState()
    if state.layout_count <= layout_idx
        assert_true(false)
        throw $'FAIL: {layout_idx} out of range'
    endif
    while state.layout_idx != layout_idx
        feedkeys('- ', 'x')
        state = CurModeState()
    endwhile
enddef

def XCmdLayout(mode: string = '', layout_idx: string = '')
    CmdLayout(mode, str2nr(layout_idx))
enddef

export def FullName(name: string): string
    return name == 'hud' ? '__Splice_HUD__' : 'play/f00-' .. name .. '.txt'
enddef

# TODO: Should the current string be returned if not a match?

export def ShortName(name: string): string
    return name == '__Splice_HUD__' ? 'hud'
        : matchlist(name, '\vplay/f00-(.*).txt')[1]
enddef

export def Convert2ShortLayoutNames(layout: list<any>): list<any>
    LayoutConvertLeaf(layout, (name: string): string => ShortName(name))
    return layout
enddef

######################################################################
#
# FileSelect
#

import golden_dir .. '/comp_xform.vim' as i_comp_xform
const comp_xform_one_two = i_comp_xform.comp_xform_one_two

var FileKeys = {
    orig:   '-o',
    one:    '-1',
    two:    '-2',
    result: '-r'
}

def CarefulWinGoto(winnr: number, MsgFunc: func)
    var winid = win_getid(winnr)
    var err = winid == 0
    if ! err
        win_gotoid(winid) 
    else
        ReportTestError(MsgFunc)
    endif
enddef

# Get Splice to the given state
export def SelectAndFocusCompFiles(comp_init: list<any>)
    var [focus: number, left: string, right: string; rest] = comp_init

    # First get in 'comp' mode, layout 0.
    CmdLayout('comp', 0)

    # Select windows so that left/right are as indicated, this can be tricky.
    # If 'orig' or 'result' are present, assume 'orig' is left, 'result' is right.
    # other_side is the side that's not orig/result. 1 - left, 2 - right
    var other_side: number
    var count = 0
    if left == 'orig'
        other_side = 2                  # change the right side
        count += 1                      # count 'orig'
        feedkeys(FileKeys[left], 'x')   # do '-o' command
    endif
    if right == 'result'
        other_side = 1                  # change the left side
        count += 1                      # count 'result'
        feedkeys(FileKeys[right], 'x')  # do '-r' command
    endif
    # if only 1 of 'orig'/'result', then need to setup the other side: other_side.
    if count == 1
        CarefulWinGoto(other_side + 1,
            () => printf("SelectAndFocusCompFiles: other_side %d", other_side))
        feedkeys(FileKeys[comp_init[other_side]], 'x')
    endif
    if count == 0
        # No 'orig' or 'result'; must be left 'one', right 'two'.

        # Bring up 'orig', it's always on the left;
        # this gives a known starting position for the 'two' and 'one' commands.
        feedkeys(FileKeys['orig'], 'x')
        # Select 'two' on the right, then 'one' on the left.
        CarefulWinGoto(3, () => printf("SelectAndFocusCompFiles: right"))
        feedkeys(FileKeys['two'], 'x')
        CarefulWinGoto(2, () => printf("SelectAndFocusCompFiles: left"))
        feedkeys(FileKeys['one'], 'x')
    endif

    # use focus, 1/2 - left/right, recall hud is window 1
    CarefulWinGoto(focus + 1, () => printf("SelectAndFocusCompFiles: wnr %d", focus + 1))

    var state = CurModeState()
    # ReportTest(() => printf("SelFocCompFile: EXIT: %s", state))
    # ReportTest(() => printf("SelFocCompFile: EXIT: %s", [focus, left, right]))
    assert_equal(focus, state.winnr - 1, "comp_init focus")
    assert_equal(left, state.winmap_name[2], "comp_init left")
    assert_equal(right, state.winmap_name[3], "comp_init right")
enddef

# comp_xform has been applied. Now check the results.
export def CheckCompFileSelect(comp_xform: list<any>)
    var state: any
    state = CurModeState()
    # ReportTest(() => printf("CheckCompSel: ENTER: %s", state))

    #var cmd = comp_xform[3]
    var [_, in_left: string, in_right: string, cmd: string] = comp_xform
    # Determine the expectations.
    # If cmd '-o' or '-r' that's the only change, focus ends up on 'orig' or 'result'
    var focus: number
    var left: string
    var right: string
    if cmd == '-o'
        focus = 1
        left = 'orig'
        right = in_right
    elseif cmd == '-r'
        focus = 2
        right = 'result'
        left = in_left
    else
        # Not '-o' or '-r', so lookup expected result
        #var [focus: number, left: string, right: string] = comp_xform_one_two[string(comp_xform)]
        [focus, left, right] = comp_xform_one_two[string(comp_xform)]
    endif

    ReportTest(() => printf("CheckCompSel: EXPECT: %s", [focus, left, right]))
    # layout doesn't matter, the window numbers are the same
    assert_equal('comp', state.id, "comp_check id")
    assert_equal(focus, state.winnr - 1, "comp_check focus")
    assert_equal(left, state.winmap_name[2], "comp_check left")
    assert_equal(right, state.winmap_name[3], "comp_check right")
enddef

######################################################################
#
# "CompareLayout"
#
# "Collect*Layout*" - to create golden files
#

import golden_dir .. '/layouts.vim' as i_layouts

#
# Check that current mode/layout is as specified
# The files in windows is assumed to be default.
#
export def CompareLayout(mode: string, layout_idx: number)
    var state = CurModeState()
    assert_equal(mode, state.id)
    assert_equal(layout_idx, state.layout_idx)
    var l = eval('i_layouts.' .. mode .. '_layout_' .. string(layout_idx))
    assert_equal(l, LayoutWithBufferNames())
enddef

def XCompareLayout(mode: string, layout_idx: string)
    CompareLayout(mode, str2nr(layout_idx))
enddef

#
# Collect all the layouts for all the modes
#
# These functions build text can be used put into
# a file and imported; it is based on LayoutWithBufferNames().
# The text defines lists that look like winlayout() output
# with buffer names rather that winid.
#
# These lists can be saved as golden, then imported and the
# golden lists compared to current values.
#
export def CollectAllLayouts()
    var data: list<string>
    data->add('vim9script')
    data->add('')

    CollectModeLayouts('grid', data)
    CollectModeLayouts('loup', data)
    CollectModeLayouts('comp', data)
    CollectModeLayouts('path', data)

    writefile(data, $RESULT_DIR .. '/layouts.vim')
enddef

#
# Collect all the layouts for the given mode
#
def CollectModeLayouts(mode: string, data: list<string>)
    CmdLayout(mode)
    for i in range(CurModeState().layout_count)
        var result = CollectLayout()
        data->extend(result)
        data->add('')
        feedkeys('- ', 'x')
    endfor
enddef

#
# Collect the layout
# create variables like grid_layout_2
def CollectLayout(): list<string>
    var state = CurModeState()
    var data: list<string>
    data->add(printf("export const %s_layout_%d: list<any> = ",
        state.id, state.layout_idx))
    data->extend(LayoutWithBufferNames()->LayoutPrettyList(4))
    return data
enddef

######################################################################
#
# winlayout structure manipulation
#
# LayoutWithBufferNames(tabnr = tabpagenr()): list<any>
# LayoutConvertLeaf(layout : list<any>, ConvertLeaf: func(any): any)
# ConvertWinidToBufferName(winid : number): string
#
# LayoutPrettyList(layout : list<any>, indent = 0): list<string>
# LayoutPrettyPrint(layout : list<any>, depth = 0): list<string>
#

# Return layout for current, or specified, tabpage with leaf buffer names

# TODO: Use short names

export def LayoutWithBufferNames(tabnr = tabpagenr()): list<any>
    return LayoutConvertLeaf(winlayout(tabnr), ConvertWinidToBufferShortName)
enddef

export def ConvertWinidToBufferShortName(winid: number): string
    return getwininfo(winid)[0].bufnr->bufname()->ShortName()
enddef

export def ConvertWinidToBufferFullName(winid: number): string
    # bufname is FullName
    return getwininfo(winid)[0].bufnr->bufname()
enddef

# Convert Leaf nodes in place; use deepcopy first if needed
export def LayoutConvertLeaf(layout_: list<any>, ConvertLeaf_: func(any): any): list<any>
    def LayoutConvertLeafRecur(layout: list<any>, ConvertLeaf: func(any): any)
        if layout[0] == 'leaf'
            layout[1] = ConvertLeaf(layout[1])
            return
        endif
        for node_val in layout[1]
            LayoutConvertLeafRecur(node_val, ConvertLeaf)
        endfor
    enddef

    LayoutConvertLeafRecur(layout_, ConvertLeaf_)
    return layout_
enddef

export def LayoutPrettyList(layout_: list<any>, indent_ = 0): list<string>
    def LayoutPrettyListRecur(layout: list<any>, indent: number,
                                            result: list<string>, level: number)
        var pad = repeat(' ', indent)
        if layout[0] == 'leaf'
            result->add(printf("%s['leaf', %s],", pad, string(layout[1])))
            return
        endif
        
        result->add(printf("%s['%s', [", pad, layout[0]))
        for node_val in layout[1]
            LayoutPrettyListRecur(node_val, indent + 3, result, level + 1)
        endfor
        result->add(printf("%s]]%s", pad, level == 0 ? '' : ','))
    enddef

    var result: list<string>
    LayoutPrettyListRecur(layout_, indent_, result, 0)
    return result
enddef

export def LayoutPrettyPrint(layout_: list<any>, depth_ = 0): list<string>
    def LayoutPrettyPrintRecur(layout: list<any>, depth: number, result: list<string>)
        if layout[0] == 'leaf'
            result->add(repeat(' ', depth) .. 'leaf: ' .. string(layout[1]))
            return
        endif
        result->add(repeat(' ', depth) .. layout[0] .. ':')
        for node_val in layout[1]
            LayoutPrettyPrintRecur(node_val, depth + 3, result)
        endfor
    enddef

    var result: list<string>
    LayoutPrettyPrintRecur(layout_, depth_, result)
    return result
enddef

finish
######################################################################

def LocalTest()
    LocalTest3()
enddef

def LocalTest4()
    var layout = LayoutWithBufferNames()
    echo LayoutPrettyList(layout)->join("\n")
enddef

def LocalTest3()
    var layout = zlayout
    #var layout = winlayout()
    #var layout = LayoutWithBufferNames()
    echo layout
    LayoutConvertLeaf(layout, TestConvertLeaf)
    #echo layout
    echo LayoutPrettyPrint(layout)->join("\n")
    #echo LayoutPrettyList(layout)->join("\n")
enddef

def LocalTest2()
    echo LayoutWithBufferNames()
enddef

def TestConvertLeaf(winid: number): string
    #return 'b' .. string(winid)[3 : ]
    return string(winid)[2 : ]
enddef
def LocalTest1()
    var inlayout = ylayout
    #var inlayout = winlayout()
    echo inlayout
    LayoutConvertLeaf(inlayout, TestConvertLeaf)
    echo inlayout
enddef

var zlayout =
    ['col', [
        ['leaf', 1002],
        ['row', [
            ['leaf', 1003],
            ['leaf', 1001],
        ]],
        ['leaf', 1000],
    ]]

var xlayout =
    ['col', [
        ['leaf', 1002],
        ['leaf', 1000]
        ]
    ]

var ylayout = [
    'col', [
        ['leaf', 1002],
        ['row', [
            ['leaf', 1003],
            ['leaf', 1001]]],
        ['leaf', 1000]]]

LocalTest()

