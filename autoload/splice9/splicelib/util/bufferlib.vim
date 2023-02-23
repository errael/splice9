vim9script

#var testing = false

import autoload './windows.vim'
import autoload './log.vim'
import autoload './vim_assist.vim'
const Log = log.Log

#const BaseEE = vim_assist.BaseEE

#var KeepWindowEE = vim_assist.KeepWindowEE
var SpliceKeepBufferEE = vim_assist.SpliceKeepBufferEE
# TODO
var nullo = null_object

# There are 5 buffers 4 hold merge files, 1 is the HUD.

export class Buffer
    this._bufnr: number
    this._label: string

    # TODO: "): Buffer"
    #           TODO: static referencing class privates
    #static def Get(bnr: number, lbl: string): any
    #    var o = new(bnr, lbl)
    #    if o._bunfr < 0
    #        return null_object
    #    endif
    #    return o
    #enddef

    def new(this._bufnr, this._label)
        #Log(printf('Buffer.new(%d, %s)', this._bufnr, this._label))
        if ! bufexists(this._bufnr)
            Log(printf('Buffer: %d does not exist', this._bufnr))
            this._bufnr = -1
        endif
    enddef

    # Make this buffer the current buffer.
    def Open(winnr = -1): void
        if winnr >= 0
            windows.focus(winnr)
            # execute string(winnr) .. 'wincmd w'
        endif
        if this._bufnr >= 0
            #execute string(this._bufnr) .. 'buffer'
            execute 'buffer' this._bufnr
        endif
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
    this.didHudInitBuf = false

    def new()
        this.original = Buffer.new(1, 'Original')
        this.one = Buffer.new(2, 'One')
        this.two = Buffer.new(3, 'Two')
        this.result = Buffer.new(4, 'Result')
        #this.hud = Buffer.new(5, 'HUD')

        const l = [ this.original, this.one, this.two, this.result ]
        this.all = l
    enddef

    def InitHudBuffer()
        # TODO: start this.hud as null_object
        if this.didHudInitBuf
            return
        endif
        this.hud = Buffer.new(5, 'HUD')
        this.didHudInitBuf = true
    enddef

    # TODO
    #def Current(): Buffer
    def Current(): any
        var bnr = bufnr('')
        if bnr >= 1 && bnr <= 4
            return this.all[bnr - 1]
        endif
        # TODO
        #return null_object
        return nullo
    enddef

    #def Remain(): BaseEE
    def Remain(): any
        #return RemainEE.new()
        # TODO: use KeepWindowEE instead buffer vs window, shouldn't matter here
        return SpliceKeepBufferEE.new()
    enddef

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

endclass

export final buffers = BufferList.new()

echo buffers.all
echo buffers.Remain()
echo "current: " buffers.Current()

#echo null_object
#echo type(null_object)
#echo typename(null_object)
#echo buffers.Current()

