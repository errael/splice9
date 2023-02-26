vim9script

import autoload '../splice.vim'
import autoload './modes.vim' as i_modes
import autoload './settings.vim' as i_settings

import autoload './util/log.vim'
import autoload './util/windows.vim'
import autoload './util/bufferlib.vim'

const buffers = bufferlib.buffers
const Buffer = bufferlib.Buffer
const Log = log.Log
const LogCmd = log.LogCmd
const Mode = i_modes.Mode

const CONFLICT_MARKER_START = '<<<<<<<'
const CONFLICT_MARKER_MARK  = '======='
const CONFLICT_MARKER_END   = '>>>>>>>'

var CONFLICT_MARKER_START_PATTERN = '^' .. CONFLICT_MARKER_START
var CONFLICT_MARKER_MARK_PATTERN  = '^' .. CONFLICT_MARKER_MARK
var CONFLICT_MARKER_END_PATTERN   = '^' .. CONFLICT_MARKER_END

def Process_result()
    LogCmd('Process_result()', '', ':ls', true)
    windows.Close_all()
    LogCmd('Process_result() after Close_all', '', ':ls', true)
    buffers.result.Open()
    LogCmd('Process_result() after Open', '', ':ls', true)

    var lines = []
    var in_conflict = false
    for line in getline(1, '$')
        Log('result', line)
        if in_conflict
            if line =~ CONFLICT_MARKER_MARK_PATTERN
                lines->add(line)
            endif
            if line =~ CONFLICT_MARKER_END_PATTERN
                in_conflict = false
            endif
            Log('result', 'DISCARD1: ' .. line)
            continue
        endif

        if line =~ CONFLICT_MARKER_START_PATTERN
            in_conflict = true
            Log('result', 'DISCARD2: ' .. line)
            continue
        endif

        lines->add(line)
    endfor

    deletebufline('', 1, '$')
    setbufline('', 1, lines)
enddef

export def Init_cur_window_wrap()
    var setting = i_settings.Setting('wrap')
    if setting != null
        &wrap = setting == 'wrap' ? true : false
        Log('&wrap set to ' .. &wrap)
    endif
enddef

def Setlocal_fixed_buffer(b: Buffer, filetype: string)
    b.Open()
    &swapfile = false
    &modifiable = false
    &filetype = filetype
    Init_cur_window_wrap()
enddef

def Setlocal_buffers()
    buffers.result.Open()
    var filetype = &filetype

    Setlocal_fixed_buffer(buffers.original, filetype)
    Setlocal_fixed_buffer(buffers.one, filetype)
    Setlocal_fixed_buffer(buffers.two, filetype)

    buffers.result.Open()
    Init_cur_window_wrap()

    Log("SKIPPING LOCAL HUD INIT")
enddef

export def Init()
    Process_result()
    LogCmd('Init() after Process_result', '', ':ls', true)

    # There's a funny dance, can't do the "new" until after Process_result()
    execute 'new' '__Splice_HUD__'
    buffers.InitHudBuffer(bufnr())
    LogCmd('Init() after buffers.InitHudBuffer()', '', ':ls', true)

    Setlocal_buffers()

    #vim.options['hidden'] = True
    &hidden = true

    var initial_mode = i_settings.Setting('initial_mode')->tolower()

    #modes.current_mode = getattr(modes, initial_mode)
    i_modes.SetInitialMode(initial_mode)
    # TODO: report/check following failed with "Exxx dictionary required"
    #           before class Mode was imported
    i_modes.current_mode.Activate()
enddef

