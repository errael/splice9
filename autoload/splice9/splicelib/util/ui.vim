vim9script

var standalone_exp = false
if expand('<script>:p') =~ '^/home/err/experiment/vim/splice'
    standalone_exp = true
endif

if ! standalone_exp
    import autoload '../../splice.vim'
else
    import './splice.vim'
endif

# dismiss on any key
def FilterCloseAnyKey(winid: number, key: string): bool
    popup_close(winid)
    return true
enddef

export def PopupMessage(msg: list<string>, title: string)

    var options = {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        border: [],
        padding: [1, 2, 1, 2],
        highlight: splice.hl_popup,
        close: 'click',
        drag: 1,
        #mousemoved: 'any', moved: 'any',
        #moved: [0, 0, 0, 0],
        #mousemoved: [0, 0, 0, 0],
        mapping: false,
        #filter: FilterCloseAnyKey
    }
    if len(title) > 0
        options.title = ' ' .. title .. ' '
    endif
    var outmsg = msg + [ '', '(Click on Popup to Dismiss. Drag Border.)' ]

    popup_create(outmsg, options)
enddef

export def PopupError(msg: list<string>, other: list<any> = [])

    var options = {
        minwidth: 20,
        tabpage: -1,
        zindex: 300,
        border: [],
        padding: [1, 2, 1, 2],
        highlight: splice.hl_alert_popup,
        close: 'click',
        mousemoved: 'any', moved: 'any',
        mapping: false, filter: FilterCloseAnyKey
        }
    if len(other) > 0
        options.title = ' ' .. other[0] .. ' '
    endif

    popup_create(msg, options)
enddef

# vim:ts=8:sts=4:
