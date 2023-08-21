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
# TODO: if following line is taken out, weird errors,
#       "Dictionary required"
const Mode = i_modes.Mode

const CONFLICT_MARKER_START = '<<<<<<<'
const CONFLICT_MARKER_MARK  = '======='
const CONFLICT_MARKER_END   = '>>>>>>>'

var CONFLICT_MARKER_START_PATTERN = '^' .. CONFLICT_MARKER_START
var CONFLICT_MARKER_MARK_PATTERN  = '^' .. CONFLICT_MARKER_MARK
var CONFLICT_MARKER_END_PATTERN   = '^' .. CONFLICT_MARKER_END

def Process_result()
    Log('Process_result()', '', true, ':ls')
    windows.Close_all()
    Log('Process_result() after Close_all', '', true, ':ls')
    buffers.result.Open()
    Log('Process_result() after Open', '', true, ':ls')

    var lines = []
    var in_conflict = false
    for line in getline(1, '$')
        Log(line, 'result')
        if in_conflict
            if line =~ CONFLICT_MARKER_MARK_PATTERN
                lines->add(line)
            endif
            if line =~ CONFLICT_MARKER_END_PATTERN
                in_conflict = false
            endif
            Log(() => 'DISCARD1: ' .. line, 'result')
            continue
        endif

        if line =~ CONFLICT_MARKER_START_PATTERN
            in_conflict = true
            Log(() => 'DISCARD2: ' .. line, 'result')
            continue
        endif

        lines->add(line)
    endfor

    deletebufline('', 1, '$')
    setbufline('', 1, lines)
enddef

def Setlocal_fixed_buffer(b: Buffer, filetype: string)
    b.Open()
    &swapfile = false
    &modifiable = false
    &filetype = filetype
    i_settings.Init_cur_window_wrap()
enddef

def Setlocal_buffers()
    buffers.result.Open()
    var filetype = &filetype

    Setlocal_fixed_buffer(buffers.original, filetype)
    Setlocal_fixed_buffer(buffers.one, filetype)
    Setlocal_fixed_buffer(buffers.two, filetype)

    buffers.result.Open()
    i_settings.Init_cur_window_wrap()

    Log("SKIPPING LOCAL HUD INIT")
enddef

export def Init()
    Process_result()
    Log('Init() after Process_result', '', true, ':ls')

    # There's a funny dance, can't do the "new" until after Process_result()
    execute 'new' '__Splice_HUD__'
    buffers.InitHudBuffer(bufnr())
    Log('Init() after buffers.InitHudBuffer()', '', true, ':ls')

    Setlocal_buffers()

    #vim.options['hidden'] = True
    &hidden = true

    var initial_mode = i_settings.Setting('initial_mode')->tolower()

    #modes.current_mode = getattr(modes, initial_mode)
    i_modes.SetInitialMode(initial_mode)
    # TODO: report/check following failed with "Exxx dictionary required"
    #       before class Mode was imported at the top
    Log(() => printf("INIT I_MODES CURRENT_MODE %s", i_modes.current_mode))
    i_modes.current_mode.Activate()
enddef

