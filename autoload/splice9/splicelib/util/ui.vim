vim9script

var import_autoload = true

if import_autoload
    import autoload '../../splice.vim'
else
    import './splice.vim'
endif

# dismiss on any key
def FilterCloseAnyKey(winid: number, key: string): bool
    popup_close(winid)
    return true
enddef

prop_type_add('popupheading', {highlight: splice.hl_heading})
export def PopupMessage(msg: list<string>, title: string, header_line = -1)

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

    var bnr = popup_create(outmsg, options)->winbufnr()
    if header_line >= 0
        prop_add(header_line, 1,
            {length: len(msg[0]), bufnr: bnr, type: 'popupheading'})
    endif
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
