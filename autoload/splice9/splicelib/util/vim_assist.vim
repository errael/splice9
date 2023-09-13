vim9script

import autoload './log.vim' as i_log

var testing = false

# Strings and lists of strings
#       Pad, IndentLtoS, IndentLtoL
#       Replace, ReplaceBuf
# Dictionary
#       DictUniqueCopy, DictUnique
#       PutIfAbsent (DEPRECATED)
#       Set (DEPRECATED)
# Lists, nested lists
#       ListRandomize
#       FindInList, FetchFromList
# Keystrokes
#       Keys2str
# Text properties
#       PropRemoveIds
# General
#       Scripts
#       EQ, IS
#       Python ripoff: With
#           interface WithEE, With(EE,func), ModifiableEE(bnr)
#       BounceMethodCall,   (WORKAROUND)
#       IsSameType (TEMP WORKAROUND, instanceof on the way)
# ##### HexString

# experimental, would need another version that returns a value
def WrapCall(fcall: string): func
    var x =<< trim eval [CODE]
        g:SomeRandomFunction = () => {{
            {fcall}
            }}
    [CODE]

    execute(x)
    var t = g:SomeRandomFunction    
    unlet g:SomeRandomFunction
    return t
enddef
#var X = WrapCall('inScript.M1("Wrap Lambda")')
#X()

###
### General
###

# Minor error, not worthy of a popup
export def Bell(force = true)
    if force || &errorbells
        normal \<Esc>
    endif
    echohl ErrorMsg
    echomsg "Oops!"
    echohl None
enddef

# Create/update scripts dictionary.
# Example: var fname = Scripts()[SID/SNR]
export def Scripts(scripts: dict<string> = {}): dict<string>
    for info in getscriptinfo()
        if ! scripts->has_key(info.sid)
            scripts[info.sid] = info.name
        endif
    endfor
    return scripts
enddef
#def DumpScripts(scripts: dict<string>)
#    for i in scripts->keys()->sort('N')
#        echo i scripts[i]
#    endfor
#enddef

# https://github.com/vim/vim/issues/10022 (won't fix)
export def EQ(lhs: any, rhs: any): bool
    return type(lhs) == type(rhs) && lhs == rhs
enddef
export def IS(lhs: any, rhs: any): bool
    return type(lhs) == type(rhs) && lhs is rhs
enddef

### Simulate Python's "With"
#
#       WithEE - Interface for context management.
#                Implement this for different contexts.
#       With(ContextClass.new(), (contextClass) => { ... })
#
#       Usage example - modify a buffer where &modifiable might be false
#           ModifyBufEE implements WithEE
#           With(ModifyBufEE.new(bnr), (_) => {
#               # modify the buffer
#           })
#           # &modifiable is same state as before "With(ModifyBufEE.new(bnr)"

# Note that Enter can be empty, and all the "Enter" work done in constructor.
export interface WithEE
    def Enter(): void
    def Exit(): void
endinterface

# TODO: test how F can declare/cast ee to the right thing
#
export def With(ee: WithEE, F: func(WithEE): void)
    ee.Enter()
    defer ee.Exit()
    F(ee)
enddef

# Save/restore '&modifiable' if needed
export class ModifyBufEE implements WithEE
    this._bnr: number
    this._is_modifiable: bool

    def new(this._bnr)
        #echo 'ModifyBufEE: new(arg):' this._bnr
    enddef

    def Enter()
        this._is_modifiable = getbufvar(this._bnr, '&modifiable')
        #echo 'ModifyBufEE: Enter:' this._bnr
        if ! this._is_modifiable
            #echo 'ModifyBufEE: TURNING MODIFIABLE ON'
            setbufvar(this._bnr, '&modifiable', true)
        endif
    enddef

    def Exit(): void
        #echo 'ModifyBufEE: Exit'
        if ! this._is_modifiable
            #echo 'ModifyBufEE: RESTORING MODIFIABLE OFF'
            setbufvar(this._bnr, '&modifiable', false)
        endif
        #echo 'ModifyBufEE: Exit: restored window:'
    enddef
endclass

# Keep window, topline, cursor as possible
export class KeepWindowEE implements WithEE
    this._w: dict<any>
    this._pos: list<number>

    def new()
    enddef

    def Enter(): void
        this._w = win_getid()->getwininfo()[0]
        this._pos = getpos('.')
    enddef

    def Exit(): void
        this._w.winid->win_gotoid()
        if setpos('.', [0, this._w.topline, 0, 0]) == 0
            execute("normal z\r")
            setpos('.', this._pos)
        endif
        #execute('normal z.')
    enddef
endclass

# Keep buffer, cursor as possible
export class KeepBufferEE implements WithEE
    this._bnr: number
    this._pos: list<number>

    def new()
    enddef

    def Enter(): void
        this._bnr = bufnr('%')
        this._pos = getpos('.')
    enddef

    def Exit(): void
        execute 'buffer' this._bnr
        setpos('.', this._pos)
    enddef
endclass

# The following saves/restores focused window
# to get the specified buffer current,
# it also does modifiable juggling.
# Not needed since can use [gs]etbufvar.
#class ModifiableEEXXX extends WithEE
#    this._bnr: number
#    this._prevId = -1
#    this._restore: bool
#    def new(this._bnr)
#        #echo 'ModifiableEE: new(arg):' this._bnr
#    enddef
#
#    def Enter(): number
#        #echo 'ModifiableEE: Enter:' this._bnr
#        # first find a window that holds this buffer, prefer current window
#        var curId = win_getid()
#        var wins = win_findbuf(this._bnr)
#        if wins->len() < 1
#            throw "ModifiableEE: buffer not in a window"
#        endif
#        var idx = wins->index(curId)
#        if idx < 0
#            # need to switch windows
#            #echo 'ModifiableEE: SWITCHING WINDOWS'
#            this._prevId = curId
#            if ! win_gotoid(wins[0])
#                throw "ModifiableEE: win_gotoid failed"
#            endif
#        endif
#        if ! &modifiable
#            #echo 'ModifiableEE: TURNING MODIFIABLE ON'
#            &modifiable = true
#            this._restore = true
#        endif
#        return this._bnr
#    enddef
#
#    def Exit(resource: number): void
#        #echo 'ModifiableEE: Exit'
#        if this._restore
#            #echo 'ModifiableEE: RESTORING MODIFIABLE OFF'
#            &modifiable = false
#        endif
#        if this._prevId < 0
#            #echo 'ModifiableEE: Exit: same window'
#            return
#        endif
#        if ! win_gotoid(this._prevId)
#            throw "ModifiableEE:Exit: win_gotoid failed"
#        endif
#        #echo 'ModifiableEE: Exit: restored window:' this._prevId
#    enddef
#endclass

###
### Dictionary
###

# Remove the common key/val from each dict.
# Note: the dicts are modified
export def DictUnique(d1: dict<any>, d2: dict<any>)
    # TODO: use items() from the smallest dict
    for [k2, v2] in d2->items()
        if d1->has_key(k2) && d1[k2] == d2[k2]
            d1->remove(k2)
            d2-> remove(k2)
        endif
    endfor
enddef

# return list of dicts with unique elements,
# returned dicts start as shallow copies
export def DictUniqueCopy(d1: dict<any>, d2: dict<any>): list<dict<any>>
    var d1_copy = d1->copy()
    var d2_copy = d2->copy()
    DictUnique(d1_copy, d2_copy)
    return [ d1_copy, d2_copy ]
enddef

###
### working with lists
###

def ListRandomize(l: list<any>): list<any>
    srand()
    var v_list: list<func> = l->copy()
    var random_order_list: list<any>
    while v_list->len() > 0
        random_order_list->add(v_list->remove(rand() % v_list->len()))
    endwhile
    return random_order_list
enddef

###
### working with nested lists
###     A path is used to traverse the nested list, see FetchFromList.
###

# FindInList: find target in list using '==' (not 'is'), return false if not found
# Each target found is identified by a list of indexes into the search list,
# and that is added to path (if path is provided).
export def FindInList(target: any, l: list<any>, path: list<list<number>> = null_list): bool
    var path_so_far: list<number> = []
    var found = false
    def FindInternal(lin: list<any>)
        var i = 0
        var this_one: any
        while i < len(lin)
            this_one = lin[i]
            if EQ(this_one, target)
                if path != null
                    path->add(path_so_far + [i])
                endif
                found = true
            elseif type(this_one) == v:t_list
                path_so_far->add(i)
                FindInternal(this_one)
                path_so_far->remove(-1)
            endif
            i += 1
        endwhile
    enddef
    if EQ(l, target)
        path->add([])
        return true
    endif
    FindInternal(l)
    return found
enddef

export def FetchFromList(path: list<number>, l: list<any>): any
    var result: any = l
    for idx in path
        result = result[idx]
    endfor
    return result
enddef

###
### Text properties
###

# not correctly implememnted, if it should be...
#export def DeleteHighlightType(type: string, d: dict<any> = null_dict)
#    prop_remove({type: prop_command, bufnr: hudbufnr, all: true})
#enddef

export def PropRemoveIds(ids: list<number>, d: dict<any> = null_dict)
    var props: dict<any> = { all: true }
    props->extend(d)
    ids->filter( (_, v) => {
        props['id'] = v
        prop_remove(props)
        return false
        })
enddef

###
### Keystrokes
###

#
# if a character is > 0xff, this will probably fail
# There's experiment/vim/Keys2Str.vim with tests
#
def StripCtrlV(k: string): list<number>
    var result: list<number>
    var i = 0
    var l = str2list(k)
    while i < len(l)
        var n = l[i]
        if false
            var c = k[i]
            var l = str2list(c)
            echo 'c: ' c 'list:' l 'hex:' printf("%x", l[0])
                        \'n:' n 'char:' nr2char(l[0])
        endif
        if n == 0x16
            # Skip ^v. If it's the last char, then keep it
            if i + 1 < len(l)
                i += 1
                n = l[i]
            endif
        endif
        result->add(n)
        i += 1
    endwhile
    return result
enddef

const up_arrow_nr: number = char2nr('^')
const back_slash_nr: number = char2nr('\')

export def Keys2Str(k: string, do_escape = true): string
    def OneChar(x: number): string
        if x == 0x20
            return '<Space>'
        elseif do_escape && x == up_arrow_nr
            return '\^'
        elseif do_escape && x == back_slash_nr
            return '\\'
        elseif x < 0x20
            return '^' .. nr2char(x + 0x40)
        endif
        return nr2char(x)
    enddef

    var result: string
    var l = StripCtrlV(k)
    for n in l
        if n < 0x80
            result = result .. OneChar(n)
        else
            result = result .. '<M-' .. OneChar(n - 0x80) .. '>'
        endif
    endfor
    return result
enddef

###
### Strings and lists of strings
###


# Overwrite characters in string, if doesn't fit print error, do nothing.
# Return new string, input string not modified.
# NOTE: col starts at 0
export def Replace(s: string, col0: number, newtext: string): string
    if col0 + len(newtext) > len(s)
            echoerr 'Replace: past end' s col0 newtext
            return s->copy()
    endif
    return col0 != 0
        ? s[ : col0 - 1] .. newtext .. s[col0 + len(newtext) : ]
        : newtext .. s[len(newtext) : ]
enddef
#export def Replace(s: string,
#        pos1: number, pos2: number, newtext: string): string
#    return pos1 != 0
#        ? s[ : pos1 - 1] .. newtext .. s[pos2 + 1 : ]
#        : newtext .. s[pos2 + 1 : ]
#enddef

# NOTE: setbufline looses text properties.

# Overwrite characters in a buffer, if doesn't fit print error and do nothing.
# NOTE: col starts at 1
export def ReplaceBuf(bnr: number, lino: number,
        col: number, newtext: string)
    if bnr != bufnr()
        echoerr printf('ReplaceBuf(%d): different buffer: curbuf %d', bnr, bufnr())
        return
    endif
    if col - 1 + len(newtext) > len(getbufoneline(bnr, lino))
            echoerr printf(
                "ReplaceBuf: past end: bnr %d, lino %d '%s', col %d '%s'",
                bnr, lino, getbufoneline(bnr, lino), col, newtext)
            return
    endif
    setpos('.', [bnr, lino, col, 0])
    execute('normal R' .. newtext)
enddef


# Indent each element of list<string>, return a single string
export def IndentLtoS(l: list<string>, nIndent: number = 4): string
    if !l
        return ''
    endif
    var indent = repeat(' ', nIndent)
    l[0] = indent .. l[0]
    return l->join("\n" .. indent)
enddef

# indent each element of l in place
def IndentLtoL(l: list<string>, nIndent: number = 4): list<string>
    if !l
        return l
    endif
    var indent = repeat(' ', nIndent)
    return l->map((_, v) => indent .. v)
enddef

#export def MaxW(l: list<string>): number
#    return max(l->mapnew((_, v) => len(v)))
#enddef

# The list is transformed, do a copy first if you want the original
# a - alignment (first char), 'l' - left (default), 'r' - right, 'c' - center
# w - width, default 0 means width of longest string
# ret_off - only centering, if not null, the calculated offsets returned
# can be used with chaining
export def Pad(l: list<string>, a: string = 'l',
        _w: number = 0,
        ret_off: list<number> = null_list): list<string>
    # TODO: only need one map statement, could conditionalize calculation
    var w = !!_w ? _w : max(l->mapnew((_, v) => len(v)))
    if a[0] != 'c'
        var justify = a[0] == 'r' ? '' : '-'
        return l->map((_, v) => printf("%" .. justify .. w .. "s", v))
    else
        return l->map((_, v) => {
            if len(v) > w
                throw "Pad: string '" .. v .. "' larger that width '" .. w .. "' "
            endif
            var _w1 = (w - len(v)) / 2
            var _w2 = w - len(v) - _w1
            if ret_off != null | ret_off->add(_w1) | endif
            #like: printf("%-15s%5s", str, '')
            return printf("%" .. (_w1 + len(v)) .. "s%" .. _w2 .. "s", v, '')
            })
    endif
enddef

#for l1 in Pad(['x', 'dd', 'sss', 'eeee', 'fffff', 'gggggg'], 'c', 12)
#    echo l1
#endfor
#for l1 in Pad(['x', 'dd', 'sss', 'eeee', 'fffff', 'gggggg', 'ccccccc'], 'c', 12)
#    echo l1
#endfor

###
### Expected to be deprecated, 
###

export def IsSameType(o: any, type: string): bool
    return type(o) == v:t_object && type == typename(o)[7 : -2]
    #return type(o) == v:t_object && type == string(o)->split()[2]
enddef

### BounceMethodCall
#
# The idea is to do invoke an object method with args where the
# args and method are passed in as a single string. Using execute, the
# local context is not available, put the object in a script variable "bounce_obj".
# (see https://github.com/vim/vim/issues/12054)
#
# If a constructed string is not required, better to
# use a lambda that invokes the object and method, "() => obj.method",
# There could be problem if arguments use BounceMethodCall (directly/indirectly)
# since bounce_obj is not on the stack. Maybe could save/restore bounce_obj,
# not worth verifying that works at this time.
#
# Hoping to deprecate at some point, not sure what needs to be done
#       
var count = 0
var bounce_obj: any = null_object
export def BounceMethodCall(obj: any, method_and_args: string)
    if bounce_obj != null_object
        throw "BounceMethodCall: bounce_obj not null " .. typename(bounce_obj)
    endif
    var i = count + 1
    count = i
    #i_log.Log(() => printf("BounceMethodCall-%d '%s' '%s' [%s]",
    #    i, typename(obj), method_and_args, typename(bounce_obj)))
    bounce_obj = obj
    execute "bounce_obj." .. method_and_args
    #i_log.Log(() => printf("BounceMethodCall-%d finish", i))
    bounce_obj = null_object
enddef
# Example:
# class C
#     def M1(s: string)
#         echo s
#     enddef
# endclass
# 
# def F()
#     var inDef = C.new()
#     # run inDef.M1('xxx') where method name is created dynamically
#     BounceMethodCall(inDef, "M" .. 1 .. "('compiled bounce')")
# enddef
# F()


###
### deprecated, 
###

#DEPRECATED: use d->extend({[k]: v}, "keep")
#def PutIfAbsent(d: dict<any>, k: string, v: any)
#    if ! d->has_key(k)
#        d[k] = v
#    endif
#enddef

#DEPRECATED: 8.2.4589 can now do g:[key] = val
#def Set(d: dict<any>, k: string, v: any)
#    d[k] = v
#enddef

#finish

# just use echo 
#export def HexString(in: string, space: bool = false, quot: bool = false): string
#    var out: string
#    for c in str2list(in)
#        if space
#            if out != '' | out ..= ' ' | endif
#        endif
#        out ..= printf('%2x', c)
#    endfor
#    return quot ? "'" .. out .. "'" : out
#enddef

if  !testing
    finish
endif

############################################################################
############################################################################
############################################################################

# With these 3 lines in a buffer (starting with 0) source this from that buffer
# -->12345678
# -->12345678
# -->12345678
# -->12345678

def RepStr(inp: string, col: number, repStr: string)
    var rv = Replace(inp, col, repStr)
    echo printf("col %d '%s', '%s' --> '%s'", col, repStr, inp, rv)
enddef

def T1()
    var inp = '12345678'
    RepStr(inp, 3, 'foo')
    RepStr(inp, 5, 'foo')
    RepStr(inp, 6, 'foo') # one char too many
enddef

def T2()
    ReplaceBuf(bufnr(), 1, 3, 'foo') # somewhere in the middle
    ReplaceBuf(bufnr(), 2, 6, 'foo') # fits, to end of line
    ReplaceBuf(bufnr(), 3, 7, 'foo') # overlaps end of line
    ReplaceBuf(bufnr(), 3, 6, 'X')
    ReplaceBuf(bufnr(), 3, 6, 'Z')
    ReplaceBuf(bufnr(), 3, 0, 'Y') # there is no column 0, ends up at 1

enddef

T1()

# vim:ts=8:sts=4:
