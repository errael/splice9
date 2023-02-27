vim9script

import autoload './windows.vim'
import autoload './log.vim'
import autoload './vim_assist.vim'

const Log = log.Log
#const BaseEE = vim_assist.BaseEE

#var KeepWindowEE = vim_assist.KeepWindowEE
const SpliceKeepBufferEE = vim_assist.SpliceKeepBufferEE
# TODO

# There are 5 buffers 4 hold merge files, 1 is the HUD.

export class Buffer
    this.bufnr: number
    this.label: string
    this.name: string

    # TODO: "): Buffer"
    #           TODO: static referencing class privates
    #static def Get(bnr: number, lbl: string): any
    #    var o = new(bnr, lbl)
    #    if o._bunfr < 0
    #        return null_object
    #    endif
    #    return o
    #enddef

    # this.name is set from bufnr
    def new(this.bufnr, this.label)
        #Log(printf('Buffer.new(%d, %s)', this.bufnr, this._label))
        if bufexists(this.bufnr)
            this.name = bufname(this.bufnr)
        else
            Log(printf('Buffer: %d does not exist', this.bufnr))
            this.bufnr = -1
        endif
    enddef

    # Make this buffer the current buffer.
    def Open(winnr = -1): void
        if winnr >= 0
            windows.focus(winnr)
            # execute string(winnr) .. 'wincmd w'
        endif
        if this.bufnr >= 0
            #execute string(this.bufnr) .. 'buffer'
            execute 'buffer' this.bufnr
        endif
    enddef

    def Winnr()
        return bufwinnr(this.bufnr)
    enddef

    ## TODO: "other: Buffer"
    #def Equals(other: any): bool
    #    return this.bufnr is other.bufnr
    #enddef
endclass

#var b = Buffer.new(10, "foo_lbl")
#echo b
#finish

#class RemainEE implements BaseEE
#    this._buf: number
#    this._pos: list<number>
#
#    def new()
#    enddef
#
#    def Enter()
#        this._curbuf = bufnr()
#        this._pos = getpos('.')
#    enddef
#
#    def Exit()
#        execute string(this._buf) .. 'buffer'
#        setpos('.', this._pos)
#    enddef
#endclass

export const nullBuffer = Buffer.new(-1, 'NULL_BUFFER')

class BufferList
    # TODO
    #this.original = Buffer.new(1, 'Original')
    #this.one = Buffer.new(2, 'One')
    #this.two = Buffer.new(3, 'Two')
    #this.result = Buffer.new(4, 'Result')
    #this.hud = Buffer.new(5, 'HUD')
    this.original: Buffer
    this.one: Buffer
    this.two: Buffer
    this.result: Buffer
    this.hud: Buffer
    this.all: list<Buffer>

    def new()
        this.original = Buffer.new(1, 'Original')
        this.one = Buffer.new(2, 'One')
        this.two = Buffer.new(3, 'Two')
        this.result = Buffer.new(4, 'Result')
        #this.hud = Buffer.new(5, 'HUD')
        this.hud = nullBuffer

        const l = [ this.original, this.one, this.two, this.result ]
        this.all = l
    enddef

    def InitHudBuffer(bnr: number)
        if this.hud == nullBuffer
            this.hud = Buffer.new(bnr, 'HUD')
        endif
    enddef

    # TODO
    #def Current(): Buffer
    def Current(): Buffer
        var bnr = bufnr('')
        if bnr >= 1 && bnr <= 4
            return this.all[bnr - 1]
        endif
        # TODO
        return nullBuffer
    enddef

    #def Remain(): BaseEE
    def Remain(): any
        #return RemainEE.new()
        # TODO: use KeepWindowEE instead buffer vs window, shouldn't matter here
        return SpliceKeepBufferEE.new()
    enddef

endclass

export final buffers = BufferList.new()

#echo buffers.all
#echo buffers.Remain()
#echo "current: " buffers.Current()


#echo null_object
#echo type(null_object)
#echo typename(null_object)
#echo buffers.Current()





    #def all(): list<Buffer>
    #    const l = [ this.original, this.one, this.two, this.result ]
    #    return l
    #enddef

    #this._buflist: list<Buffer>

    # TODO: is this better?
    #final this.one: Buffer

    #def new()
    #    this._buflist = [
    #        Buffer.new(1, 'Original'), Buffer.new(2, 'One'),
    #        Buffer.new(3, 'Two'), Buffer.new(4, 'Result'),
    #        Buffer.new(5, 'HUD')
    #    ]
    #enddef

    #def original(): Buffer
    #    return this._buflist.get(0)
    #enddef

    #def one(): Buffer
    #    return this._buflist.get(1)
    #enddef

    #def two(): Buffer
    #    return this._buflist.get(2)
    #enddef

    #def result(): Buffer
    #    return this._buflist.get(3)
    #enddef

    #def hud(): Buffer
    #    return this._buflist.get(4)
    #enddef

    #def current(): Buffer
    #    return this._buflist.get(bufnr('%'))
    #enddef

    #def all(): list<Buffer>
    #    return this._buflist->copy()[:-1]
    #enddef

