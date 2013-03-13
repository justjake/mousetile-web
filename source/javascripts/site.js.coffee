
VERT  = 1
HORIZ = 0

BEFORE = true
AFTER  = false

Array_remove = (ary, el_or_idx) ->
    if (typeof el_or_index) == 'number'
        # index sanity check
        index = el_or_index

        # wrap-around indexing
        if index < 0
            index = ary.length + index

        if not (index > -1 and index < ary.length)
            throw new Error("InvalidRemoval: index #{index} out of bounds")

        el = ary[index]

    else

        el = frame_or_index
        index = ary.indexOf(el)
        if index == -1
            throw new Error("InvalidRemoval: #{el} not found in #{ary}")

    ary.splice(index, 1)
    el

# bind a function as `this`
bind = (fn, obj) ->
    return ->
        fn.apply(obj, arguments)

throttle = (wait, fn) ->
    timer = null
    return ->
        context = this
        args = arguments
        clearTimeout(timer)
        timer = setTimeout (-> fn.apply(context, args)), wait


# is this element currently in the DOM
in_dom = (el) ->
    !!(el.closest(document.documentElement).length)


class Frame

    VERT_CLASS  = "vertical"
    HORIZ_CLASS = "horizontal"

    @MIN_PIXEL_WIDTH = 10

    template = jQuery("""<section class="frame"></section>""")

    constructor: (size = 100, layout = VERT) ->
        @element = template.clone()

        # graph
        @children = []
        @parent   = null

        @frames  = []
        @handles = []

        # layout
        @setSize(size)
        @setLayout(layout)

        # the handle that manages this frame
        @handle = null

    ###
    DOM layout shenanigans
    ###
    setLayout: (layout) ->
        @layout = layout
        
        @element.removeClass(VERT_CLASS).removeClass(HORIZ_CLASS)
        if layout is VERT
            @element.removeClass(HORIZ_CLASS).addClass(VERT_CLASS)
        else if layout is HORIZ
            @element.removeClass(VERT_CLASS).addClass(HORIZ_CLASS)
        else
            throw new Error("layout can only be set to VERT or HORIZ")

        @layoutChildren()
        this

    
    # set to a target size, or just reset the dimensions after a layout
    setSize: (percent = @size) ->
        @size = percent

        # Is this the right place to do the actual resizing?
        if @parent
            if @parent.layout is VERT
                dim = 'width'
            else
                dim = 'height'

            # unset
            @element.css('width',  '')
            @element.css('height', '')

            @element.css(dim, "#{percent}%")

        this


    layoutChildren: (recurse = false) ->
        not_first = false
        for f in @frames
            f.setSize()
            # add handles if we need them
            if not f.handle and not_first
                f.handle = new Handle(f)
                @addHandle(f.handle)
            not_first = true

            if recurse
                f.layoutChildren(true)

        for h in @handles
            h.layout()

    ###
    Graph management
    ###

    #TODO: should we do some sort of DOM manipulation here?
    addChild: (node, dom_insert = true) ->
        # manage graph
        @children.push(node)
        node.parent = this

        # TODO is this propper?
        if dom_insert
            @element.append(node.element)

        node

    removeChild: (node) ->
        idx = @children.indexOf(node)

        if idx == -1
            throw new Error("InvalidRemoval: Node #{node} is not a child of #{this}")

        # Array.delete just sets the element to undefined
        @children.splice(idx, 1)

        # and remove the DOM element from play
        node.element.remove()

        node



    ###
    High-level frame-management funcitons
    should be re-worked
    ###
    appendFrame: (frame) ->
        @insertFrame(frame, @frames.length)

    insertFrame: (frame, idx = @frames.length, side = BEFORE) ->
        @addChild(frame)

        # insert frame adds elements BEFORE the existing element at
        # `idx` by default.
        # Shift by 1 to add elements after
        if side is AFTER
            idx += 1

        # check for sane insertion idx
        if idx > @frames.length
            throw new Error("InvalidInsertion: target index out of bounds")

        # get a frame next to the insertion index to use as an anchor in
        # the dom
        f = @frames[idx - 1]
        if f
            f.element.after(frame.elememnt)
        else
            # We are going to be the only frame in the array
            @element.prepend(frame.element)

        @frames.splice(idx, 0, frame)

    removeFrame: (frame_or_index) ->
        frame = Array_remove(@frames, frame_or_index)

        @removeHandle(frame.handle) if frame.handle
        @removeChild(frame)

    addHandle: (handle) ->
        @addChild(handle)
        @handles.push(handle)
        handle

    removeHandle: (handle) ->
        @removeChild(handle)
        Array_remove(handle)


    # The sum of all frame widths should be 100%
    resizeFramesFit: ->
        target  = 100
        current = @frames.reduce ((t, s) -> t + s.size), 0
        ratio   = target / current

        for f in @frames
            f.setSize(f.size * ratio)

    # make all frames equal size
    resizeFramesEqual: ->
        size = 100 / @frames.length
        for f in @frames
            f.setSize(size)

    resizeFrames: ->
        @resizeFramesEqual()


###
Handles

These super-special objects bind to frames and derive thier position from them.
They allow dragging to resize thier frames
###

class Handle
    template = $("""<div class="handle"></div>""")

    constructor: (frame) ->
        @frame   = frame
        @parent  = null
        @element = template.clone()
        @draggable = new Draggable.Draggable(@element,
            moveCb: bind(@dragCallback, this),
            endCb: bind(@dropCallback, this))

        @pos = null # used for calculating drag deltas

    # reposition this handle to its frame
    layout: ->
        if not @parent
            throw new Error("HandleLayoutFailure: cannot lay out a handle without a parent")

        i = @parent.frames.indexOf(@frame)

        if i is -1
            throw new Error("InvalidGraph: frame #{@frame} not included in parent's frame table")

        offset = @parent.frames[0...i].reduce ((t, s) -> t + s.size), 0
        @setOffset(offset)


    setOffset: (offset = @offset) ->
        @offset = offset

        if @parent.layout is VERT
            ord = 'left'
        else
            ord = 'top'

        # reset
        @element.css('top', '')
        @element.css('left', '')

        @element.css(ord, "#{offset}%")

    to_percent: (px) ->
        s = @parent.element.width() if @parent.layout is VERT
        s = @parent.element.height() if @parent.layout is HORIZ
        (px * 100) / s

    from_percent: (percent) ->
        s = @parent.element.width() if @parent.layout is VERT
        s = @parent.element.height() if @parent.layout is HORIZ
        (percent / 100) * s


    dragCallback: (dest, start) ->

        if not @pos
            @pos = start

        delta = dest.sub(@pos)
        @pos = dest

        # constrain to the correct orientation
        if @parent.layout is VERT
            ord = 'x'
        else
            ord = 'y'

        delta = @to_percent(delta[ord])

        # resize things
        right = @frame
        left  = @parent.frames[@parent.frames.indexOf(@frame) - 1]

        left_intention = left.size + delta
        right_intention = right.size - delta

        # guard exceeding limits
        if @from_percent(left_intention) < Frame.MIN_PIXEL_WIDTH or @from_percent(right_intention) < Frame.MIN_PIXEL_WIDTH
            return false

        left.setSize(left_intention)
        right.setSize(right_intention)

        @setOffset(@offset + delta)
   
    dropCallback: ->
        @pos = null





other = (dir) ->
    if dir is VERT
        HORIZ
    else
        VERT

select_alternate = (initial) ->
    prev = other(initial)
    return ->
        prev = other(prev)
        return prev

recursive_tree = (dir_selector, depth_remaining) ->
    if depth_remaining == 0
        return new Frame()

    root = new Frame(100, dir_selector())

    a = (new Frame()).setSize(1)
    b = (new Frame()).setSize(1)
    full_child =  recursive_tree(dir_selector, depth_remaining - 1).setSize(2)

    root.appendFrame(a)
    root.appendFrame(full_child)
    root.appendFrame(b)

    root.resizeFramesFit()
    root.layoutChildren()

    return root

exports = {
    'Frame':  Frame
    'Handle': Handle
    'VERT': VERT
    'HORIZ': HORIZ
    'recursive_tree': recursive_tree
    'select_alternate': select_alternate
    'throttle': throttle
}

# write out
window.Mousetile = exports










