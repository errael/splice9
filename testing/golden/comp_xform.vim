vim9script

#
# If compare mode, there is a left and right side file (or top/bottom)
# This list contains all 48 possible selected file xformations in compare
# mode. The 24 keys in comp_xform_one_two which change with the '-1' or '-2'
# commands, plus the 24 by using '-r' and '-o' instean of '-1' and '-2'.
# Each entry looks like:
#       var [focus: number, left: string, right: string, cmd: string]
# Left and right are each one of 'orig', 'one', 'two' or 'result', note that
# some combinations are not possible. Focus is which side is focused 1 or 2
# which is left or right respectively. Cmd is one of '-o', '-1', '-2', '-r'.
#
def CompXformAll(): list<list<any>>
    var ret: list<list<any>>
    var all = ['orig', 'one', 'two', 'result']

    for left in all
        for right in all
            if left == right
                    || left == 'result'
                    || right == 'orig'
                    || left == 'two' && right == 'one'
                continue
            endif

            #echo [left, right]
            # got the left/right now wich
            #for focus in [1, 2]
            for focus in range(2, 3)
                for cmd in ['-o', '-1', '-2', '-r']
                    ret->add([focus, cmd, left, right])
                endfor
            endfor
        endfor
    endfor
    return ret
enddef

export const comp_xform = CompXformAll()
#echo comp_xform->len()

#for [focus, left, right, cmd] in comp_xform
#    echo printf("%d %s %s %s", focus, left, right, cmd)
#endfor
#echo comp_xform->join("\n")

# For testing
export const comp_xform_small_test = [
    [ 2, '-1', 'orig',  'result', ],
    [ 2, '-2', 'orig',  'one',    ],
    [ 3, '-1', 'orig',  'two',    ],

    [ 3, '-2', 'one',   'result', ],
    [ 2, '-2', 'one',   'result', ],

    [ 3, '-o', 'one',   'result', ],
    [ 2, '-r', 'one',   'result', ],

    [ 2, '-1', 'two',   'result', ],
    [ 2, '-2', 'one',   'two',    ],
    [ 3, '-2', 'one',   'two',    ],
]


# This dict maps initial compare mode state to expected compare state,
# after the specified "cmd-1-2" is run. 24 transitions,
#
# The 24 tranistion for '-o' and '-r' eare calculated at runtime.
#
# initial state: [foucus-num-2-3, 'name-1', 'name-2', 'cmd-1-2']
# expected state: [foucus-num-2-3, 'name-1', 'name-2']
#       [2, 'orig', 'result', '-1']: [2, 'one', 'result']
#       [2, 'orig', 'result', '-2']: [2, 'two', 'result']

export const comp_xform_one_two: dict<list<any>> =
{
    [string([ 2, '-1', 'orig',  'result', ])]: [ 2, 'one',  'result'],
    [string([ 2, '-2', 'orig',  'result', ])]: [ 2, 'two',  'result'],
    [string([ 3, '-1', 'orig',  'result', ])]: [ 3, 'orig', 'one'],
    [string([ 3, '-2', 'orig',  'result', ])]: [ 3, 'orig', 'two'],

    [string([ 2, '-1', 'orig',  'one',    ])]: [ 3, 'orig', 'one'],
    [string([ 2, '-2', 'orig',  'one',    ])]: [ 3, 'orig', 'two'],
    [string([ 3, '-1', 'orig',  'one',    ])]: [ 3, 'orig', 'one'],
    [string([ 3, '-2', 'orig',  'one',    ])]: [ 3, 'orig', 'two'],

    [string([ 2, '-1', 'orig',  'two',    ])]: [ 2, 'one',  'two'],
    [string([ 2, '-2', 'orig',  'two',    ])]: [ 3, 'orig', 'two'],
    [string([ 3, '-1', 'orig',  'two',    ])]: [ 3, 'orig', 'one'],
    [string([ 3, '-2', 'orig',  'two',    ])]: [ 3, 'orig', 'two'],

    [string([ 2, '-1', 'one',   'result', ])]: [ 2, 'one',  'result'],
    [string([ 2, '-2', 'one',   'result', ])]: [ 2, 'two',  'result'],
    [string([ 3, '-1', 'one',   'result', ])]: [ 2, 'one',  'result'],
    [string([ 3, '-2', 'one',   'result', ])]: [ 3, 'one',  'two'],

    [string([ 2, '-1', 'two',   'result', ])]: [ 2, 'one',  'result'],
    [string([ 2, '-2', 'two',   'result', ])]: [ 2, 'two',  'result'],
    [string([ 3, '-1', 'two',   'result', ])]: [ 2, 'one',  'result'],
    [string([ 3, '-2', 'two',   'result', ])]: [ 2, 'two',  'result'],

    [string([ 2, '-1', 'one',   'two',    ])]: [ 2, 'one',  'two'],
    [string([ 2, '-2', 'one',   'two',    ])]: [ 3, 'one',  'two'],
    [string([ 3, '-1', 'one',   'two',    ])]: [ 2, 'one',  'two'],
    [string([ 3, '-2', 'one',   'two',    ])]: [ 3, 'one',  'two'],
}
#comp_xform_one_two->foreach((k, v) => {
#    echo printf("%-30s %s", k, v)
#})

finish
######################################################################

# This has identical ->keys() to comp_xform_one_two.
# The value is the key as a list to avoid eval
export const comp_xform_one_two_key_as_list: dict<list<any>> =
{
    [string([ 1, 'orig',  'result',  '-1'])]: [ 1, 'orig',  'result',  '-1'],
    [string([ 1, 'orig',  'result',  '-2'])]: [ 1, 'orig',  'result',  '-2'],
    [string([ 2, 'orig',  'result',  '-1'])]: [ 2, 'orig',  'result',  '-1'],
    [string([ 2, 'orig',  'result',  '-2'])]: [ 2, 'orig',  'result',  '-2'],

    [string([ 1, 'orig',  'one',     '-1'])]: [ 1, 'orig',  'one',     '-1'],
    [string([ 1, 'orig',  'one',     '-2'])]: [ 1, 'orig',  'one',     '-2'],
    [string([ 2, 'orig',  'one',     '-1'])]: [ 2, 'orig',  'one',     '-1'],
    [string([ 2, 'orig',  'one',     '-2'])]: [ 2, 'orig',  'one',     '-2'],

    [string([ 1, 'orig',  'two',     '-1'])]: [ 1, 'orig',  'two',     '-1'],
    [string([ 1, 'orig',  'two',     '-2'])]: [ 1, 'orig',  'two',     '-2'],
    [string([ 2, 'orig',  'two',     '-1'])]: [ 2, 'orig',  'two',     '-1'],
    [string([ 2, 'orig',  'two',     '-2'])]: [ 2, 'orig',  'two',     '-2'],

    [string([ 1, 'one',   'result',  '-1'])]: [ 1, 'one',   'result',  '-1'],
    [string([ 1, 'one',   'result',  '-2'])]: [ 1, 'one',   'result',  '-2'],
    [string([ 2, 'one',   'result',  '-1'])]: [ 2, 'one',   'result',  '-1'],
    [string([ 2, 'one',   'result',  '-2'])]: [ 2, 'one',   'result',  '-2'],

    [string([ 1, 'two',   'result',  '-1'])]: [ 1, 'two',   'result',  '-1'],
    [string([ 1, 'two',   'result',  '-2'])]: [ 1, 'two',   'result',  '-2'],
    [string([ 2, 'two',   'result',  '-1'])]: [ 2, 'two',   'result',  '-1'],
    [string([ 2, 'two',   'result',  '-2'])]: [ 2, 'two',   'result',  '-2'],

    [string([ 1, 'one',   'two',     '-1'])]: [ 1, 'one',   'two',     '-1'],
    [string([ 1, 'one',   'two',     '-2'])]: [ 1, 'one',   'two',     '-2'],
    [string([ 2, 'one',   'two',     '-1'])]: [ 2, 'one',   'two',     '-1'],
    [string([ 2, 'one',   'two',     '-2'])]: [ 2, 'one',   'two',     '-2'],
}

#export const comp_xform_one_two_keys = comp_xform_one_two->keys()

finish
######################################################################
vim9script

var all = ['orig', 'one', 'two', 'result']

for left in all
    for right in all
        if left == right
                || left == 'result'
                || right == 'orig'
                || left == 'two' && right == 'one'
            continue
        endif
        #echo [left, right]
        for cmd in ['-o', '-1', '-2', '-r']
            for focus in [1, 2]
                echo [focus, left, right, cmd]
            endfor
        endfor
    endfor
endfor
######################################################################

  compare mode is the most complex mode in response to -o/-1/-2/-r

     (* - focused)
     initial state                           final state

  left        right           cmd         left        right

  *F1         *F2             -o         *orig         F2
  *F1         *F2             -r           F1        *result

 *orig        result          -1         *one         result
 *orig        result          -2         *two         result
  orig       *result          -1          orig       *one
  orig       *result          -2          orig       *two

 *orig        one             -1          orig       *one         (focus only change)
 *orig        one             -2          orig       *two
  orig       *one             -1          orig       *one         (no change)
  orig       *one             -2          orig       *two

 *orig        two             -1         *one         two
 *orig        two             -2          orig       *two         (focus only change)
  orig       *two             -1          orig       *one
  orig       *two             -2          orig       *two         (no change)

 *one         result          -1         *one         result      (no change)
 *one         result          -2         *two         result
  one        *result          -1         *one         result      (focus only change)
  one        *result          -2          one        *two

 *two         result          -1         *one         result
 *two         result          -2         *two         result      (no change)
  two        *result          -1         *one         result
  two        *result          -2         *two         result      (focus only change)

 *one         two             -1         *one         two         (no change
 *one         two             -2          one        *two         (focus only change)
  one        *two             -1         *one         two         (focus only change)
  one        *two             -2          one        *two         (no change)

