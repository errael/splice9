vim9script

import '../../rlib.vim'
const Rlib = rlib.Rlib

import autoload './windows.vim'
import autoload Rlib('util/log.vim') as i_log
import autoload Rlib('util/with.vim') as i_with

# There are 5 buffers 4 hold merge files, 1 is the HUD.

export class Buffer
    var bufnr: number
    var label: string
    var name: string

    # this.name is set from bufnr
    def new(this.bufnr, this.label)
        #i_log.Log(printf('Buffer.new(%d, %s)', this.bufnr, this._label))
        if bufexists(this.bufnr)
            this.name = bufname(this.bufnr)
        else
            i_log.Log(() => printf('Buffer: %d does not exist', this.bufnr))
            this.bufnr = -1
        endif
    enddef

    # Make this buffer the current buffer.
    def Open(winnr = -1): void
        if winnr >= 0
            windows.Focus(winnr)
            # execute string(winnr) .. 'wincmd w'
        endif
        if this.bufnr >= 0
            # TODO: get rid of "execute"
            execute 'buffer' this.bufnr
        endif
    enddef

    def Winnr(): number
        return bufwinnr(this.bufnr)
    enddef

    ## TODO: "other: Buffer"
    #def Equals(other: any): bool
    #    return this.bufnr is other.bufnr
    #enddef
endclass

# TODO: can this use "null_object"?
export const nullBuffer = Buffer.new(-1, 'NULL_BUFFER')

class BufferList
    # TODO why the compile/runtime errors if ": Buffer" not in the following
    #       Note that if the assignment happens in new(), then it's OK
    #       error occurs on 4th line of init.vim::Process_result
    #TODO: private/public issues
    var original: Buffer = Buffer.new(1, 'Original')
    var one: Buffer = Buffer.new(2, 'One')
    var two: Buffer = Buffer.new(3, 'Two')
    var result: Buffer = Buffer.new(4, 'Result')

    #this.hud = Buffer.new(5, 'HUD')
    var hud: Buffer
    var all: list<Buffer>

    def new()
        #this.hud = Buffer.new(5, 'HUD')
        this.hud = nullBuffer

        const l = [ this.original, this.one, this.two, this.result ]
        this.all = l
    enddef

    def CreateHudBuffer(): void
        if this.hud == nullBuffer
            execute 'new' '__Splice_HUD__'
            this.hud = Buffer.new(bufnr(), 'HUD')
        endif
    enddef

    def Current(): Buffer
        var bnr = bufnr('')
        if bnr >= 1 && bnr <= 4
            return this.all[bnr - 1]
        endif
        # TODO
        return nullBuffer
    enddef

    def Remain(): i_with.WithEE
        # TODO: use KeepWindowEE instead? buffer vs window shouldn't matter here
        return i_with.KeepBufferEE.new()
    enddef

endclass

export final buffers = BufferList.new()

