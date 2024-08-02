vim9script

enum LogCategories
    diffopts,
    error,
    layout,
    result,
    setting

    def string(): string
        return this.name
    enddef
endenum

export const DIFFOPTS = LogCategories.diffopts
export const ERROR = LogCategories.error
export const LAYOUT = LogCategories.layout
export const RESULT = LogCategories.result
export const SETTING = LogCategories.setting
