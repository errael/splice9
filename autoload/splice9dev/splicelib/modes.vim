vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload './result.vim' as i_result
import autoload './settings.vim' as i_settings
import autoload './hud.vim' as i_hud
import autoload './util/windows.vim'
import autoload './util/bufferlib.vim' as i_buflib
import autoload Rlib('util/vim_extra.vim') as i_extra
import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/with.vim') as i_with
import autoload Rlib('util/strings.vim') as i_strings
import autoload './util/keys.vim' as i_keys
import autoload './util/search.vim' as i_search
import autoload './util/ui.vim' as i_ui

type Buffer = i_buflib.Buffer
const buffers = i_buflib.buffers

# indexed by bnr
var last_buf_pos: dict<list<number>>

#
# Could use "is" instead of "==" when comparing buffers,
# but there's use of list->index(curbuf) as well, so why bother.
#

# i_log.Log("TOP OF MODE")

class Mode
    var id: string
    var _lay_first: string
    var _lay_second: string

    var _number_of_windows: number

    # funcs to do the layout and the diffs: 0 to n-1
    var _layouts: list<func(): void>
    var _diffs: list<func(): void>

    var _current_diff_mode: number
    var _diff_off_mode: number
    var _current_layout: number
    var _current_scrollbind: bool

    var _current_buffer: Buffer
    var _current_buffer_first: Buffer
    var _current_buffer_second: Buffer
    var _current_mid_buffer: Buffer

    def new()
    enddef

    def Diff(diffmode: number)
        i_with.With(buffers.Remain(), (_) => {
            i_with.With(windows.Remain(), (_) => {
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
        i_log.Log(() => $'Key_diff: next_diff_mode: {next_diff_mode}')
        this.Diff(next_diff_mode)
    enddef

    def Diffoff()
        i_log.Log(() => printf("=== Diffoff %s, nWind %d", this.id, this._number_of_windows - 1))
        i_with.With(windows.Remain(), (_) => {
            for winnr in range(2, 2 + this._number_of_windows - 1)
                windows.Focus(winnr)
                var curbuffer = buffers.Current()

                i_log.Log(() => printf("    WNR %d, BNR %d", winnr, curbuffer.bufnr), 'diffopts')
                # Note the "!" removes hidden buffers from the list of diff'd.
                :diffoff!
                i_settings.Set_cur_window_wrap()

                #for buffer in buffers.all
                #    buffer.Open()
                #    i_log.Log(() => printf("    WNR %d, BNR %d", winnr, buffer.bufnr), 'diffopts')
                #    :diffoff
                #    i_settings.Set_cur_window_wrap()
                #endfor

                curbuffer.Open()
            endfor
        })
    enddef


    def Key_diffoff()
        # Toggle between off and previous mode.
        var next_mode: number = this._diff_off_mode
        i_log.Log(() => printf("Key_diffoff: current_diff_mode %d,  diff_off_mode %d",
            this._current_diff_mode, this._diff_off_mode))
        this._diff_off_mode = this._current_diff_mode
        
        this.Diff(next_mode)
    enddef


    def Scrollbind(enabled: bool)
        if !!this._current_diff_mode
            return
        endif

        i_with.With(windows.Remain(), (_) => {
            this._current_scrollbind = enabled

            for winnr in range(2, 2 + this._number_of_windows - 1)
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
        this._layouts[layoutnr]()

        this.Diff(this._current_diff_mode)
        this.Redraw_hud()
    enddef

    # TODO: NOTE that _current_layout is not saved here,
    #       it is saved at the target.
    #       Why not save it here, or in Layout above, instead of the several places M_layout_#?
    def Key_layout(diffmode: number = -1) # diffmode not used
        var next_layout = (this._current_layout + 1) % len(this._layouts)
        i_log.Log(() => printf("Key_layout: id: %s, next %d, this.layouts %s",
            this.id, next_layout, this._layouts), 'layout')
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


    # The default implementation of the UseHunk commands ring the bell
    def Key_use()
        i_extra.Bell()
    enddef

    def Key_use0()
        i_extra.Bell()
    enddef

    def Key_use1()
        i_extra.Bell()
    enddef

    def Key_use2()
        i_extra.Bell()
    enddef


    def Goto_result()
        i_log.Log(() => "Goto_result: mode: " .. current_mode.id, 'error')
    enddef


    def RestorePosition(winnr: number)
        var bnr = winbufnr(winnr)
        if bnr > 0
            var pos: list<number> = last_buf_pos->get(bnr, null_list)
            if pos != null
                setcursorcharpos(pos[1 :])
            endif
        endif
    enddef

    def Activate()
        #i_log.Log(printf("Activate: this._diffs: id: %s, %s", this.id, this._diffs))
        this.Layout(this._current_layout)
        this.Diff(this._current_diff_mode)
        this.Scrollbind(this._current_scrollbind)

        # Don't use windows.Remain(), we're setting position of everything
        var winid = win_getid()

        windows.Focus(i_buflib.buffers.result.Winnr())
        i_search.HighlightConflict()

        # restore the cursor positions
        var bnr: number
        for winnr in range(2, 2 + this._number_of_windows - 1)
            windows.Focus(winnr)
            this.RestorePosition(winnr)
        endfor

        win_gotoid(winid)

        i_log.Log(() => $"CURRENT_MODE: {this.id}")
    enddef

    def Deactivate()
        for winnr in range(2, 2 + this._number_of_windows - 1)
            var bnr = winbufnr(winnr)
            if bnr > 0
                last_buf_pos[bnr] = getcursorcharpos(winnr)
            endif
        endfor
        i_log.Log(() => printf("Deactivate: saved_buffer_positions: %s", last_buf_pos))
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


    # Open_hud only called from M_layout_*
    # which is only called from Layout,
    # and Layout ends with Redraw_hud,
    # so don't Redraw_hud here.
    def Open_hud(winnr: number)
        # TODO: inline window commands?
        :split
        windows.Focus(winnr)
        buffers.hud.Open()
        :wincmd K
        # this.Redraw_hud()
    enddef

    def Redraw_hud()
        i_with.With(windows.Remain(), (_) => {
            windows.Focus(1)

            this.Hud_prep()

            var mod = this.id
            # baaad programmer
            if mod == 'loup'
                mod = 'loupe'
            elseif mod == 'comp'
                mod = 'compare'
            endif

            i_hud.DrawHUD(mod, this._current_layout,
                [this._lay_first, this._lay_second]->filter((_, v) => v != ''))
        })
    enddef

    def Hud_prep()
    enddef

    def IsDiffsOn(): bool
        return !!this._current_diff_mode
    enddef

    def IsScrollbindOn(): bool
        return this._current_scrollbind || !!this._current_diff_mode
    enddef

    # return the labels for the buffers in diffmode.
    def GetDiffLabels(): list<string>
        var rc: list<string>
        i_with.With(windows.Remain(), (_) => {
            for i in range(2, this._number_of_windows + 2 - 1)
                windows.Focus(i)
                if &diff
                    rc->add(buffers.Current().label)
                endif
            endfor
        })
        return rc
    enddef
endclass
# i_log.Log("DEFINED: class Mode")


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
        this._current_layout = i_settings.Setting('initial_layout_grid')
        this._current_diff_mode = i_settings.Setting('initial_diff_grid')
        this._current_scrollbind = i_settings.Setting('initial_scrollbind_grid')
        i_log.Log(() => $"MODES: initial_scrollbind_grid: {this._current_scrollbind}")

        this._layouts = [ () => this.M_layout_0(), () => this.M_layout_1(),
                            () => this.M_layout_2() ]
        this._diffs = [ () => this.M_diff_0(), () => this.M_diff_1() ]
    enddef

    def M_layout_0()
        this._number_of_windows = 4
        this._current_layout = 0

        # Open the layout
        windows.Close_all()
        :split
        :split
        windows.Focus(2)
        :vsplit

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
        :vsplit
        :vsplit

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
        :split
        :split

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
        var targetwin = target == 1 ? 3 : 4

        i_with.With(windows.Remain(), (_) => {
            this.Diffoff()

            windows.Focus(5)
            :diffthis

            windows.Focus(targetwin)
            :diffthis
        })
    enddef

    def M_key_use_12(target: number)
        var targetwin = target == 1 ? 2 : 4

        i_with.With(windows.Remain(), (_) => {
            this.Diffoff()

            windows.Focus(3)
            :diffthis

            windows.Focus(targetwin)
            :diffthis
        })
    enddef


    # both side of conflict
    def Key_use0()
        # Following checks that in Result on conflict
        i_result.RestoreOriginalConflictText()
        # TODO: this.Diff(current_diff) or some other setup/fixup?
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
            i_log.Log(() => $'mode.goto_result: winnr: {winnr}, w2: {w2}', 'error')
        endif
        i_log.Log(() => $'mode.{this.id}.goto_result: winnr: {winnr}, w2: {w2}')

        windows.Focus(winnr)
    enddef


    def Activate()
        i_keys.ActivateGridBindings()
        super.Activate()
    enddef

    def Deactivate()
        i_keys.DeactivateGridBindings()
        super.Deactivate()
    enddef


    def Hud_prep()
        this._lay_first = ''
        this._lay_second = ''
    enddef
endclass
# i_log.Log("DEFINED: class GridMode")


class LoupeMode extends Mode
    def new()
        this.id = 'loup'
        this._current_layout = i_settings.Setting('initial_layout_loupe')
        this._current_diff_mode = i_settings.Setting('initial_diff_loupe')
        this._current_scrollbind = i_settings.Setting('initial_scrollbind_loupe')
        i_log.Log(() => $"MODES: 'initial_scrollbind_loupe: {this._current_scrollbind}")

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

    def Goto_result()
        this.Key_result()
    enddef


    def Hud_prep()
        #this._lay_first = buffers.labels[this._current_buffer.name]
        this._lay_first = this._current_buffer.label
        this._lay_second = ''
    enddef
endclass
# i_log.Log("DEFINED: class LoupeMode")


class CompareMode extends Mode
    def new()
        this.id = 'comp'
        this._current_layout = i_settings.Setting('initial_layout_compare')
        this._current_diff_mode = i_settings.Setting('initial_diff_compare')
        this._current_scrollbind = i_settings.Setting('initial_scrollbind_compare')
        i_log.Log(() => $"MODES: 'initial_scrollbind_compare: {this._current_scrollbind}")

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
        :vsplit

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
        :split

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

        var curwindow = winnr()
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

        var curwindow = winnr()
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

        # TODO: alert "result" with "one" or "two"
        if active->index(buffers.result) < 0
                || active->index(buffers.one) < 0 && active->index(buffers.two) < 0
            # Center the lines.
            var s = i_strings.Pad(['"Result" required', 'with either "One" or "Two".',
                '(look at "Layout")'], "c")

            i_ui.SplicePopupMessage(s, 'Use Hunk')
            return
        endif

        #if active->index(buffers.one) < 0 && active->index(buffers.two) < 0
        #    return
        #endif

        var current_diff = this._current_diff_mode
        i_with.With(windows.Remain(), (_) => {
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
# i_log.Log("DEFINED: class CompareMode")


class PathMode extends Mode
    def new()
        this.id = 'path'
        this._current_layout = i_settings.Setting('initial_layout_path')
        this._current_diff_mode = i_settings.Setting('initial_diff_path')
        this._current_scrollbind = i_settings.Setting('initial_scrollbind_path')
        i_log.Log(() => $"MODES: 'initial_scrollbind_path: {this._current_scrollbind}")

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
        :vsplit
        :vsplit

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
        :split
        :split

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

    def Key_result()
        windows.Focus(4)
    enddef


    def Key_use()
        if buffers.Current() == i_buflib.nullBuffer
            var bname = buffers.hud.bufnr == bufnr() ? 'Splice_HUD' : bufname()
            # TODO: test
            i_ui.SplicePopupKey('ENOTFILE', bname, 'UseHunk')
            return
        endif

        var current_diff = this._current_diff_mode
        i_with.With(windows.Remain(), (_) => {
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
# i_log.Log("DEFINED: class PathMode")

var modes: dict<Mode> = {
    grid:    GridMode.new(),
    loupe:   LoupeMode.new(),
    compare: CompareMode.new(),
    path:    PathMode.new(),
}
lockvar 1 modes

var current_mode: Mode

export def ActivateInitialMode(initial_mode: string)
    i_log.Log(() => $"INIT: inital mode: '{initial_mode}'")
    if initial_mode != 'grid'
        i_keys.DeactivateGridBindings()
    endif
    current_mode = modes[initial_mode]
    current_mode.Activate()
enddef

# TODO: Directly access variables after makeing more stuff read-only
export def GetStatusDiffScrollbind(): list<bool>
    # Report the splice settings; but user might manually override,
    # not worth handling that now; at your own risk. Could scan the windows...
    # Note: in diff mode, vim turns on scrollbiund
    return [ current_mode.IsDiffsOn(), current_mode.IsScrollbindOn() ]
enddef

export def GetDiffLabels(): list<string>
    return current_mode.GetDiffLabels()
enddef

def Key_grid()
    Change2Mode('grid')
enddef

def Key_loupe()
    Change2Mode('loupe')
enddef

def Key_compare()
    Change2Mode('compare')
enddef

def Key_path()
    Change2Mode('path')
enddef

def SpliceQuit()
    :wa
    :qa
enddef
def SpliceCancel()
    :cq
enddef

def Change2Mode(modeName: string): void
    var m: Mode = modes->get(modeName, null_object)
    if m != null
        i_log.Log(() => printf("Change2Mode: '%s' %s",  modeName, typename(m)))
        current_mode.Deactivate()
        current_mode = m
        current_mode.Activate()
    else
        i_log.Log(() => $"Change2Mode: unknown mode '{modeName}'", 'error', true)
    endif
enddef

const dispatch: dict<func(): void> = {
    SpliceGrid:         () => Key_grid(),
    SpliceLoupe:        () => Key_loupe(),
    SpliceCompare:      () => Key_compare(),
    SplicePath:         () => Key_path(),

    SpliceOriginal:     () => current_mode.Key_original(),
    SpliceOne:          () => current_mode.Key_one(),
    SpliceTwo:          () => current_mode.Key_two(),
    SpliceResult:       () => current_mode.Key_result(),

    SpliceDiff:         () => current_mode.Key_diff(),
    SpliceDiffOff:      () => current_mode.Key_diffoff(),
    SpliceScroll:       () => current_mode.Key_scrollbind(),
    SpliceLayout:       () => current_mode.Key_layout(),
    SpliceNext:         () => current_mode.Key_next(),
    SplicePrevious:     () => current_mode.Key_prev(),
    SpliceUseHunk:      () => current_mode.Key_use(),
    SpliceUseHunk1:     () => current_mode.Key_use1(),
    SpliceUseHunk2:     () => current_mode.Key_use2(),
    SpliceUseHunk0:     () => current_mode.Key_use0(),

    SpliceQuit:         () => SpliceQuit(),
    SpliceCancel:       () => SpliceCancel(),
}

export def ModesDispatch(op: string)
    if current_mode == null_object
        i_log.Log(() => printf("NULL current_mode: %s: %s", op, current_mode.id))
        return
    endif

    i_log.Log(() => printf('===EXECUTE COMMAND===: %s mode: %s', op, current_mode.id))
    dispatch->get(op, () => i_log.Log("Dispatch: unknown op: " .. op, 'error', true))()
    i_hud.UpdateHudStatus()
enddef



