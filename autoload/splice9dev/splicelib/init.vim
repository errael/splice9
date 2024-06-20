vim9script

import '../rlib.vim'
const Rlib = rlib.Rlib

import autoload '../splice.vim'
import autoload './modes.vim' as i_modes
import autoload './settings.vim' as i_settings

import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/stack.vim') as i_stack
import autoload './util/windows.vim'
import autoload './util/bufferlib.vim'

const buffers = bufferlib.buffers
type Buffer = bufferlib.Buffer

const CONFLICT_MARKER_START = '<<<<<<<'
const CONFLICT_MARKER_MARK  = '======='
const CONFLICT_MARKER_END   = '>>>>>>>'

var CONFLICT_MARKER_START_PATTERN = '^' .. CONFLICT_MARKER_START
var CONFLICT_MARKER_MARK_PATTERN  = '^' .. CONFLICT_MARKER_MARK
var CONFLICT_MARKER_END_PATTERN   = '^' .. CONFLICT_MARKER_END

def Process_result()
    i_log.Log('Process_result()', '', true, ':ls')
    windows.Close_all()
    i_log.Log('Process_result() after Close_all', '', true, ':ls')
    buffers.result.Open()
    i_log.Log('Process_result() after Open', '', true, ':ls')

    var lines = []
    var in_conflict = false
    for line in getline(1, '$')
        i_log.Log(line, 'result')
        if in_conflict
            if line =~ CONFLICT_MARKER_MARK_PATTERN
                lines->add(line)
            endif
            if line =~ CONFLICT_MARKER_END_PATTERN
                in_conflict = false
            endif
            i_log.Log(() => 'DISCARD1: ' .. line, 'result')
            continue
        endif

        if line =~ CONFLICT_MARKER_START_PATTERN
            in_conflict = true
            i_log.Log(() => 'DISCARD2: ' .. line, 'result')
            continue
        endif

        lines->add(line)
    endfor

    deletebufline('', 1, '$')
    setbufline('', 1, lines)
enddef

def Setlocal_fixed_buffer(b: Buffer, filetype: string)
    b.Open()
    # the following are buffer local
    &swapfile = false
    &modifiable = false
    &filetype = filetype
    # wrap is window local
    i_settings.Set_cur_window_wrap()
enddef

def Setlocal_buffers()
    buffers.result.Open()
    var filetype = &filetype

    Setlocal_fixed_buffer(buffers.original, filetype)
    Setlocal_fixed_buffer(buffers.one, filetype)
    Setlocal_fixed_buffer(buffers.two, filetype)

    buffers.result.Open()
    i_settings.Set_cur_window_wrap()
enddef

export def Init()
    Process_result()
    i_log.Log('Init() after Process_result', '', true, ':ls')

    # funny dance, can't do CreateHudBuffer until after Process_result()
    buffers.CreateHudBuffer()
    i_log.Log('Init() after buffers.CreateHudBuffer()', '', true, ':ls')

    Setlocal_buffers()
    i_log.Log('Init() after Setlocal_buffers()', '', true, ':ls')
    &hidden = true

    var initial_mode = i_settings.Setting('initial_mode')->tolower()
    i_modes.ActivateInitialMode(initial_mode)
enddef

