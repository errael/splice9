vim9script

import autoload './settings.vim' as i_settings
import autoload './init.vim' as i_init
import autoload './hud.vim' as i_hud
import autoload './util/windows.vim'
import autoload './util/bufferlib.vim' as i_bufferlib
import autoload './util/vim_assist.vim'
import autoload './util/log.vim' as i_log
import autoload './util/keys.vim' as i_keys
import autoload './util/search.vim' as i_search

const buffers = i_bufferlib.buffers
const nullBuffer = i_bufferlib.nullBuffer
const Buffer = i_bufferlib.Buffer
const With = vim_assist.With
const DrawHUD = i_hud.DrawHUD
const Setting = i_settings.Setting
const Log = i_log.Log

Log("TOP OF MODE")

export class Mode
    this.id: string
    this._lay_first: string
    this._lay_second: string

    this._number_of_windows: number

    # funcs to do the layout and the diffs: 0 to n-1
    this._layouts: list<func(): void>
    this._diffs: list<func(): void>

    this._current_diff_mode: number
    this._current_layout: number
    this._current_scrollbind: bool

    this._current_buffer: Buffer
    this._current_buffer_first: Buffer
    this._current_buffer_second: Buffer
    this._current_mid_buffer: Buffer

    def new()
    enddef

    def Diff(diffmode: number)
        With(buffers.Remain(), (_) => {
            With(windows.Remain(), (_) => {
                this._diffs[diffmode]()
            })
        })

        # Reset the scrollbind to whatever it was before we diffed.
        if ! diffmode
            this.Scrollbind(this._current_scrollbind)
        endif
    enddef

    # NOTE: diffmode not used
    def Key_diff(diffmode: number = -1)
        var next_diff_mode = (this._current_diff_mode + 1) % len(this._diffs)
        Log(() => $'Key_diff: next_diff_mode: {next_diff_mode}')
        this.Diff(next_diff_mode)
    enddef

    def Diffoff()
        With(windows.Remain(), (_) => {
            for winnr in range(2, 2 + this._number_of_windows - 1)
                windows.Focus(winnr)
                var curbuffer = buffers.Current()
                # TODO: need to check curbuffer == null and quick exit?

                for buffer in buffers.all
                    buffer.Open()
                    :diffoff
                    i_settings.Init_cur_window_wrap()
                endfor

                curbuffer.Open()
            endfor
        })
    enddef


    def Key_diffoff()
        this.Diff(0)
    enddef


    def Scrollbind(enabled: bool)
        if !!this._current_diff_mode
            return
        endif

        var this_this = this
        With(windows.Remain(), (_) => {
            Log("Scrollbind Lambda using this_this")
            this_this._current_scrollbind = enabled #<<<<<<<<<<<<<<<<<<<<<< 

            for winnr in range(2, 2 + this_this._number_of_windows - 1)
                windows.Focus(winnr)
                &scrollbind = enabled
            endfor

            if enabled
                :syncbind
            endif
        })
    enddef

    def Key_scrollbind()
        this.Scrollbind(! this._current_scrollbind)
    enddef


    def Layout(layoutnr: number)
        #getattr(self, '_layout_%d' % layoutnr)()
        this._layouts[layoutnr]()

        this.Diff(this._current_diff_mode)
        this.Redraw_hud()
    enddef

    # TODO: NOTE that _current_layout is not saved here,
    #       it is saved at the target.
    #       Why not save it here, or in Layout above, instead of the several places M_layout_#?
    def Key_layout(diffmode: number = -1) # diffmode not used
        var next_layout = (this._current_layout + 1) % len(this._layouts)
        Log(printf("Key_layout: id: %s, next %d, %s", this.id, next_layout, this._layouts))
        Log(() => $'Mode: Key_layout: next_layout {next_layout}', 'layout')
        this.Layout(next_layout)
    enddef


    def Key_original()
    enddef

    def Key_one()
    enddef

    def Key_two()
    enddef

    def Key_result()
    enddef


    def Key_use()
        Log(() => "Key_use: mode: " .. current_mode.id, 'error')
    enddef

    def Key_use1()
        Log(() => "Key_use1: mode: " .. current_mode.id, 'error')
    enddef

    def Key_use2()
        Log(() => "Key_use2: mode: " .. current_mode.id, 'error')
    enddef


    def Goto_result()
        Log(() => "Goto_result: mode: " .. current_mode.id, 'error')
    enddef


    def S_Activate()
        Log(printf("S_Activate: this._diffs: id: %s, %s", this.id, this._diffs))
        this.Layout(this._current_layout)
        this.Diff(this._current_diff_mode)
        this.Scrollbind(this._current_scrollbind)
    enddef

    def Activate()
        this.S_Activate()
    enddef

    def S_Deactivate()
    enddef
    def Deactivate()
        this.S_Deactivate()
    enddef


    def Key_next()
        this.Goto_result()
        i_search.MoveToConflict(true)
        #vim.command(r'exe "silent! normal! /\\v^\\=\\=\\=\\=\\=\\=\\=*$\<cr>"')
    enddef

    def Key_prev()
        this.Goto_result()
        i_search.MoveToConflict(false)
        #vim.command(r'exe "silent! normal! ?\\v^\\=\\=\\=\\=\\=\\=\\=*$\<cr>"')
    enddef


    def Open_hud(winnr: number)
        # TODO: inline window commands?
        windows.Split()
        windows.Focus(winnr)
        buffers.hud.Open()
        :wincmd K
        this.Redraw_hud()
    enddef

    def Redraw_hud()
        With(windows.Remain(), (_) => {
            windows.Focus(1)

            this.Hud_prep()

            # use the stack trace for why redraw hud called twice per command
            # log_stack(traceback.format_stack(None, 6))

            var mod = this.id
            # baaad programmer
            if mod == 'loup'
                mod = 'loupe'
            elseif mod == 'comp'
                mod = 'compare'
            endif

            DrawHUD(true, mod, this._current_layout,
                [this._lay_first, this._lay_second]->filter((_, v) => v != ''))
        })
    enddef

    def Hud_prep()
    enddef
endclass
Log("DEFINED: class Mode")


class GridMode extends Mode
    # Layout 0                 Layout 1                        Layout 2
    # +-------------------+    +--------------------------+    +---------------+
    # |     Original      |    | One    | Result | Two    |    |      One      |
    # |2                  |    |        |        |        |    |2              |
    # +-------------------+    |        |        |        |    +---------------+
    # |  One    |    Two  |    |        |        |        |    |     Result    |
    # |3        |4        |    |        |        |        |    |3              |
    # +-------------------+    |        |        |        |    +---------------+
    # |      Result       |    |        |        |        |    |      Two      |
    # |5                  |    |2       |3       |4       |    |4              |
    # +-------------------+    +--------------------------+    +---------------+

    def new()
        this.id = 'grid'
        this._current_layout = Setting('initial_layout_grid')
        this._current_diff_mode = Setting('initial_diff_grid')
        this._current_scrollbind = Setting('initial_scrollbind_grid')
        Log(() => $"MODES: initial_scrollbind_grid: {this._current_scrollbind}")

        this._layouts = [ () => this.M_layout_0(), () => this.M_layout_1(),
                            () => this.M_layout_2() ]
        this._diffs = [ () => this.M_diff_0(), () => this.M_diff_1() ]
    enddef

    def M_layout_0()
        this._number_of_windows = 4
        this._current_layout = 0

        # Open the layout
        windows.Close_all()
        windows.Split()
        windows.Split()
        windows.Focus(2)
        windows.Vsplit()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        buffers.original.Open()

        windows.Focus(2)
        buffers.one.Open()

        windows.Focus(3)
        buffers.two.Open()

        windows.Focus(4)
        buffers.result.Open()

        this.Open_hud(5)

        windows.Focus(5)
    enddef

    def M_layout_1()
        this._number_of_windows = 3
        this._current_layout = 1

        # Open the layout
        windows.Close_all()
        windows.Vsplit()
        windows.Vsplit()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        buffers.one.Open()

        windows.Focus(2)
        buffers.result.Open()

        windows.Focus(3)
        buffers.two.Open()

        this.Open_hud(4)

        windows.Focus(3)
    enddef

    def M_layout_2()
        this._number_of_windows = 3
        this._current_layout = 2

        # Open the layout
        windows.Close_all()
        windows.Split()
        windows.Split()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        buffers.one.Open()

        windows.Focus(2)
        buffers.result.Open()

        windows.Focus(3)
        buffers.two.Open()

        this.Open_hud(4)

        windows.Focus(3)
    enddef


    def M_diff_0()
        this.Diffoff()
        this._current_diff_mode = 0
    enddef

    def M_diff_1()
        this.Diffoff()
        this._current_diff_mode = 1

        for i in range(2, this._number_of_windows + 2 - 1)
            windows.Focus(i)
            :diffthis
        endfor
    enddef


    def Key_original()
        if this._current_layout == 0
            windows.Focus(2)
        elseif this._current_layout == 1
            return
        elseif this._current_layout == 2
            return
        endif
    enddef

    def Key_one()
        if this._current_layout == 0
            windows.Focus(3)
        elseif this._current_layout == 1
            windows.Focus(2)
        elseif this._current_layout == 2
            windows.Focus(2)
        endif
    enddef

    def Key_two()
        if this._current_layout == 0
            windows.Focus(4)
        elseif this._current_layout == 1
            windows.Focus(4)
        elseif this._current_layout == 2
            windows.Focus(4)
        endif
    enddef

    def Key_result()
        if this._current_layout == 0
            windows.Focus(5)
        elseif this._current_layout == 1
            windows.Focus(3)
        elseif this._current_layout == 2
            windows.Focus(3)
        endif
    enddef


    def M_key_use_0(target: number)
        targetwin = if target == 1 ? 3 : 4

        With(windows.Remain(), (_) => {
            this.Diffoff()

            windows.Focus(5)
            :diffthis

            windows.Focus(targetwin)
            :diffthis
        })
    enddef

    def M_key_use_12(target: number)
        targetwin = if target == 1 ? 2 : 4

        With(windows.Remain(), (_) => {
            this.Diffoff()

            windows.Focus(3)
            :diffthis

            windows.Focus(targetwin)
            :diffthis
        })
    enddef


    def Key_use1()
        var current_diff = this._current_diff_mode

        if this._current_layout == 0
            this.M_key_use_0(1)
        elseif this._current_layout == 1
            this.M_key_use_12(1)
        elseif this._current_layout == 2
            this.M_key_use_12(1)
        endif

        var curbuf = buffers.Current()
        if curbuf == buffers.result
            :diffget
        elseif [buffers.one, buffers.two]->index(curbuf) >= 0
            :diffput
        endif

        this.Diff(current_diff)
    enddef

    def Key_use2()
        var current_diff = this._current_diff_mode

        if this._current_layout == 0
            this.M_key_use_0(2)
        elseif this._current_layout == 1
            this.M_key_use_12(2)
        elseif this._current_layout == 2
            this.M_key_use_12(2)
        endif

        var curbuf = buffers.Current()
        if curbuf == buffers.result
            :diffget
        elseif [buffers.one, buffers.two]->index(curbuf) >= 0
            :diffput
        endif

        this.Diff(current_diff)
    enddef


    def Goto_result()
        var winnr: number
        if this._current_layout == 0
            winnr = 5
        elseif this._current_layout == 1
            winnr = 3
        elseif this._current_layout == 2
            winnr = 3
        endif
        var w2 = buffers.result.Winnr()
        if w2 != winnr
            Log(() => $'mode.goto_result: winnr: {winnr}, w2: {w2}', 'error')
        endif
        Log(() => $'mode.{this.id}.goto_result: winnr: {winnr}, w2: {w2}')

        windows.Focus(winnr)
    enddef


    def Activate()
        i_keys.ActivateGridBindings
        this.S_Activate()
    enddef

    def Deactivate()
        i_keys.DeactivateGridBindings
        this.S_Deactivate()
    enddef


    def Hud_prep()
        this._lay_first = ''
        this._lay_second = ''
    enddef
endclass
Log("DEFINED: class GridMode")


class LoupeMode extends Mode
    def new()
        this.id = 'loup'
        this._current_layout = Setting('initial_layout_loupe')
        this._current_diff_mode = Setting('initial_diff_loupe')
        this._current_scrollbind = Setting('initial_scrollbind_loupe')
        Log(() => $"MODES: 'initial_scrollbind_loupe: {this._current_scrollbind}")

        this._layouts = [ () => this.M_layout_0() ]
        this._diffs = [ () => this.M_diff_0() ]

        this._current_buffer = buffers.result
    enddef


    def M_diff_0()
        this.Diffoff()
        this._current_diff_mode = 0
    enddef


    def M_layout_0()
        this._number_of_windows = 1
        this._current_layout = 0

        # Open the layout
        windows.Close_all()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        this._current_buffer.Open()

        this.Open_hud(2)

        windows.Focus(2)
    enddef


    def Key_original()
        windows.Focus(2)
        buffers.original.Open()
        this._current_buffer = buffers.original
        this.Redraw_hud()
    enddef

    def Key_one()
        windows.Focus(2)
        buffers.one.Open()
        this._current_buffer = buffers.one
        this.Redraw_hud()
    enddef

    def Key_two()
        windows.Focus(2)
        buffers.two.Open()
        this._current_buffer = buffers.two
        this.Redraw_hud()
    enddef

    def Key_result()
        windows.Focus(2)
        buffers.result.Open()
        this._current_buffer = buffers.result
        this.Redraw_hud()
    enddef


    # TODO: don't display "use unk" in loupe mode
    #def Key_use()
    #    # BUG? this should use superclass
    #    Log('warn', "Loupe: Key_use: mode: " .. current_mode.id)
    #enddef


    def Goto_result()
        this.Key_result()
    enddef


    def Hud_prep()
        #this._lay_first = buffers.labels[this._current_buffer.name]
        this._lay_first = this._current_buffer.label
        this._lay_second = ''
    enddef
endclass
Log("DEFINED: class LoupeMode")


class CompareMode extends Mode
    def new()
        this.id = 'comp'
        this._current_layout = Setting('initial_layout_compare')
        this._current_diff_mode = Setting('initial_diff_compare')
        this._current_scrollbind = Setting('initial_scrollbind_compare')
        Log(() => $"MODES: 'initial_scrollbind_compare: {this._current_scrollbind}")

        this._layouts = [ () => this.M_layout_0(), () => this.M_layout_1() ]
        this._diffs = [ () => this.M_diff_0(), () => this.M_diff_1() ]

        this._current_buffer_first = buffers.original
        this._current_buffer_second = buffers.result
    enddef


    def M_diff_0()
        this.Diffoff()
        this._current_diff_mode = 0
    enddef

    def M_diff_1()
        this.Diffoff()
        this._current_diff_mode = 1

        windows.Focus(2)
        :diffthis

        windows.Focus(3)
        :diffthis
    enddef


    def M_layout_0()
        this._number_of_windows = 2
        this._current_layout = 0

        # Open the layout
        windows.Close_all()
        windows.Vsplit()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        this._current_buffer_first.Open()

        windows.Focus(2)
        this._current_buffer_second.Open()

        this.Open_hud(3)

        windows.Focus(3)
    enddef

    def M_layout_1()
        this._number_of_windows = 2
        this._current_layout = 1

        # Open the layout
        windows.Close_all()
        windows.Split()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        this._current_buffer_first.Open()

        windows.Focus(2)
        this._current_buffer_second.Open()

        this.Open_hud(3)

        windows.Focus(3)
    enddef


    def Key_original()
        windows.Focus(2)
        buffers.original.Open()
        this._current_buffer_first = buffers.original
        this.Diff(this._current_diff_mode)

        this.Redraw_hud()
    enddef

    def Key_one()
        def Open_one(winnr: number)
            buffers.one.Open(winnr)
            if winnr == 2
                this._current_buffer_first = buffers.one
            else
                this._current_buffer_second = buffers.one
            endif
            this.Diff(this._current_diff_mode)
            this.Redraw_hud()
        enddef

        var curwindow = windows.Currentnr()
        if curwindow == 1
            curwindow = 2
        endif

        # If file one is showing, go to it.
        windows.Focus(2)
        if buffers.Current() == buffers.one
            return
        endif

        windows.Focus(3)
        if buffers.Current() == buffers.one
            return
        endif

        # If both the original and result are showing, open file one in the
        # current window.
        windows.Focus(2)
        if buffers.Current() == buffers.original
            windows.Focus(3)
            if buffers.Current() == buffers.result
                Open_one(curwindow)
                return
            endif
        endif

        # If file two is in window 1, then we open file one in window 1.
        windows.Focus(2)
        if buffers.Current() == buffers.two
            Open_one(2)
            return
        endif

        # Otherwise, open file one in the current window.
        Open_one(curwindow)
    enddef

    def Key_two()
        def Open_two(winnr: number)
            buffers.two.Open(winnr)
            if winnr == 2
                this._current_buffer_first = buffers.two
            else
                this._current_buffer_second = buffers.two
            endif
            this.Diff(this._current_diff_mode)
            this.Redraw_hud()
        enddef

        var curwindow = windows.Currentnr()
        if curwindow == 1
            curwindow = 2
        endif

        # If file two is showing, go to it.
        windows.Focus(2)
        if buffers.Current() == buffers.two
            return
        endif

        windows.Focus(3)
        if buffers.Current() == buffers.two
            return
        endif

        # If both the original and result are showing, open file two in the
        # current window.
        windows.Focus(2)
        if buffers.Current() == buffers.original
            windows.Focus(3)
            if buffers.Current() == buffers.result
                Open_two(curwindow)
                return
            endif
        endif

        # If file one and the result are showing, then we open file two in the
        # current window.
        windows.Focus(2)
        if buffers.Current() == buffers.one
            windows.Focus(3)
            if buffers.Current() == buffers.result
                Open_two(curwindow)
                return
            endif
        endif

        # If file one is in window 2, then we open file two in window 2.
        windows.Focus(3)
        if buffers.Current() == buffers.two
            Open_two(3)
            return
        endif

        # Otherwise, open file two in window 2.
        Open_two(3)
    enddef

    def Key_result()
        windows.Focus(3)
        buffers.result.Open()
        this._current_buffer_second = buffers.result
        this.Diff(this._current_diff_mode)

        this.Redraw_hud()
    enddef


    def Key_use()
        var active = [this._current_buffer_first, this._current_buffer_second]

        if active->index(buffers.result) < 0
            return
        endif

        if active->index(buffers.one) < 0 && active->index(buffers.two) < 0
            return
        endif

        var current_diff = this._current_diff_mode
        With(windows.Remain(), (_) => {
            this.M_diff_1()  # diff the windows
        })

        var curbuf = buffers.Current()
        if curbuf == buffers.result
            :diffget
        elseif [buffers.one, buffers.two]->index(curbuf) >= 0
            :diffput
        endif

        this.Diff(current_diff)
    enddef


    def Goto_result()
        this.Key_result()
    enddef


    def Hud_prep()
        #this._lay_first = buffers.labels[this._current_buffer_first.name]
        #this._lay_second = buffers.labels[this._current_buffer_second.name]
        this._lay_first = this._current_buffer_first.label
        this._lay_second = this._current_buffer_second.label
    enddef
endclass
Log("DEFINED: class CompareMode")


class PathMode extends Mode
    def new()
        this.id = 'path'
        this._current_layout = Setting('initial_layout_path')
        this._current_diff_mode = Setting('initial_diff_path')
        this._current_scrollbind = Setting('initial_scrollbind_path')
        Log(() => $"MODES: 'initial_scrollbind_path: {this._current_scrollbind}")

        this._layouts = [ () => this.M_layout_0(), () => this.M_layout_1() ]
        this._diffs = [ () => this.M_diff_0(), () => this.M_diff_1(),
            () => this.M_diff_2(), () => this.M_diff_3(),
            () => this.M_diff_4() ]

        this._current_mid_buffer = buffers.one
    enddef


    def M_diff_0()
        this.Diffoff()
        this._current_diff_mode = 0
    enddef

    def M_diff_1()
        this.Diffoff()
        this._current_diff_mode = 1

        windows.Focus(2)
        :diffthis

        windows.Focus(4)
        :diffthis
    enddef

    def M_diff_2()
        this.Diffoff()
        this._current_diff_mode = 2

        windows.Focus(2)
        :diffthis

        windows.Focus(3)
        :diffthis
    enddef

    def M_diff_3()
        this.Diffoff()
        this._current_diff_mode = 3

        windows.Focus(3)
        :diffthis

        windows.Focus(4)
        :diffthis
    enddef

    def M_diff_4()
        this.Diffoff()
        this._current_diff_mode = 4

        windows.Focus(2)
        :diffthis

        windows.Focus(3)
        :diffthis

        windows.Focus(4)
        :diffthis
    enddef


    def M_layout_0()
        this._number_of_windows = 3
        this._current_layout = 0

        # Open the layout
        windows.Close_all()
        windows.Vsplit()
        windows.Vsplit()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        buffers.original.Open()

        windows.Focus(2)
        this._current_mid_buffer.Open()

        windows.Focus(3)
        buffers.result.Open()

        this.Open_hud(4)

        windows.Focus(4)
    enddef

    def M_layout_1()
        this._number_of_windows = 3
        this._current_layout = 1

        # Open the layout
        windows.Close_all()
        windows.Split()
        windows.Split()

        # Put the buffers in the appropriate windows
        windows.Focus(1)
        buffers.original.Open()

        windows.Focus(2)
        this._current_mid_buffer.Open()

        windows.Focus(3)
        buffers.result.Open()

        this.Open_hud(4)

        windows.Focus(4)
    enddef


    def Key_original()
        windows.Focus(2)
    enddef

    def Key_one()
        windows.Focus(3)
        buffers.one.Open()
        this._current_mid_buffer = buffers.one
        this.Diff(this._current_diff_mode)
        windows.Focus(3)
        this.Redraw_hud()
    enddef

    def Key_two()
        windows.Focus(3)
        buffers.two.Open()
        this._current_mid_buffer = buffers.two
        this.Diff(this._current_diff_mode)
        windows.Focus(3)
        this.Redraw_hud()
    enddef

    # TODO: WAS: def Key_result(this) BUT NO ERROR
    #                                 AT LEAST NOT DIRECTLY ABOUT THIS
    def Key_result()
        windows.Focus(4)
    enddef


    def Key_use()
        if buffers.Current() == nullBuffer
            var bname = buffers.hud.bufnr == bufnr() ? 'Splice_HUD' : bufname()
            # TODO: test
            i_log.SplicePopup('ENOTFILE', bname, 'UseHunk')
            return
        endif

        var current_diff = this._current_diff_mode
        With(windows.Remain(), (_) => {
            this.M_diff_3()  # diff the middle and result windows
        })

        var curbuf = buffers.Current()
        if curbuf == buffers.result
            :diffget
        elseif [buffers.one, buffers.two]->index(curbuf) >= 0
            :diffput
        endif

        this.Diff(current_diff)
    enddef


    def Goto_result()
        windows.Focus(4)
    enddef


    def Hud_prep()
        var buf: string
        if this._current_mid_buffer == buffers.one
            buf = 'One'
        else
            buf = 'Two'
        endif
        this._lay_first = buf
        this._lay_second = ''
    enddef
endclass
Log("DEFINED: class PathMode")

final grid = GridMode.new()
final loupe = LoupeMode.new()
final compare = CompareMode.new()
final path = PathMode.new()

var modes: dict<Mode> = {
    grid: grid,
    loupe: loupe,
    compare: compare,
    path: path
}


# TODO: don't export, provide a getter
export var current_mode: Mode


export def SetInitialMode(initial_mode: string)
    Log(() => $"INIT: inital mode: '{initial_mode}'")
    current_mode = modes[initial_mode]
    Log(() => $"CURRENT_MODE: {string(current_mode)}")
enddef

def Change2Mode(modeName: string): void
    # Following fails can't type because null_object not handled well
    #var m: Mode = modes->get(modeName, null_object)
    var m = modes->get(modeName, null)
    if m != null
        Log(() => printf("Change2Mode: '%s' %s",  modeName, typename(m)))
        current_mode.Deactivate()
        current_mode = m
        current_mode.Activate()
    else
        Log(() => $"Change2Mode: unknown mode '{modeName}'", 'error', true)
    endif
enddef

export def Key_grid()
    Change2Mode('grid')
enddef

export def Key_loupe()
    Change2Mode('loupe')
enddef

export def Key_compare()
    Change2Mode('compare')
enddef

export def Key_path()
    Change2Mode('path')
enddef

const dispatch = {
    SpliceOriginal: () => current_mode.Key_original(),
    SpliceOne:      () => current_mode.Key_one(),
    SpliceTwo:      () => current_mode.Key_two(),
    SpliceResult:   () => current_mode.Key_result(),

    SpliceDiff:     () => current_mode.Key_diff(),
    SpliceDiffOff:  () => current_mode.Key_diffoff(),
    SpliceScroll:   () => current_mode.Key_scrollbind(),
    SpliceLayout:   () => current_mode.Key_layout(),
    SpliceNext:     () => current_mode.Key_next(),
    SplicePrev:     () => current_mode.Key_prev(),
    SpliceUse:      () => current_mode.Key_use(),
    SpliceUse1:     () => current_mode.Key_use1(),
    SpliceUse2:     () => current_mode.Key_use2(),
}

export def ModesDispatch(op: string)
    if current_mode == null_object
        Log(() => printf("NULL current_mode: %s: %s", op, current_mode.id))
        return
    endif

    Log(() => printf("%s: %s", op, current_mode.id))
    var F = dispatch->get(op, null_function)
    if F != null
        Log(printf('dispatching %s', op), 'layout')
        F()
        Log(printf('returned %s', op), 'layout')
    else
        Log(() => "ModesDispatch: unknown operation: " .. op, 'error', true)
    endif
enddef



