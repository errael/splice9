vim9script

import autoload 'raelity/config.vim'
import autoload config.Rlib('util/lists.vim') as i_lists
import autoload config.Rlib('util/log.vim') as i_log

# LayoutWithBufferNames(tabnr = tabpagenr()): list<any>
# LayoutPrettyPrint(layout: list<any>, depth = 0): list<string>

command! -nargs=* AA RunFuncTest('XCmdLayout', <f-args>)
command! -nargs=+ AB RunFuncTest('XCompareLayout', <f-args>)
#command! -nargs=* AA {
#    var args = eval('[ <f-args> ]')
command! -nargs=0 A1 echo g:SpliceCollectModeState()
command! -nargs=0 A2 echo CurModeState()

def Run1(tid: number)
    feedkeys("\<CR>")
    timer_start(1000, Run2)
enddef

def Run2(tid: number)
    echom '=== RunTheTest ==='
enddef

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
                CmdESC()
            endif
        endif
    enddef
    #PM(-1)
    # Need to wait for idle before testing
    timer_start(0, PM)
enddef

export def CmdESC()
    feedkeys("\<ESC>", 'x')
enddef

export def CurModeState(): dict<any>
    var state: dict<any> = g:SpliceCollectModeState()
    var curState = state[state.current_mode]
    curState.bufnr = state.bufnr
    curState.winnr = state.winnr
    var full_name = bufname(state.bufnr)
    curState.name = ShortName(full_name)
    return curState
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
# "TestAllLayouts"
# "CompareLayout"
#
# "Collect*Layout*" - to create golden files
#

var golden_dir = $GOLD_DIR ?? '/src/tools/splice9/testing/golden'
import golden_dir .. '/layouts' as i_layouts

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

    writefile(data, $RESULT_DIR .. '/layouts')
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
export def LayoutWithBufferNames(tabnr = tabpagenr()): list<any>
    #var layout = winlayout(tabnr)
    return LayoutConvertLeaf(winlayout(tabnr), ConvertWinidToBufferName)
enddef

export def ConvertWinidToBufferName(winid: number): string
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

