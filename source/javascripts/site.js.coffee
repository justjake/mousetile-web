VERT  = 1
HORIZ = 0

class Frame

    VERT_CLASS  = "vertical"
    HORIZ_CLASS = "horizontal"

    template = jQuery("""<div class="frame"></div>""")

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




    layoutChildren: ->
        for f in @frames
            f.setSize()
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

    removeChild: (node) ->
        idx = @children.indexOf(node)

        if idx == -1
            throw new Error("InvalidRemoval: Node #{node} is not a child of #{this}")

        # Array.delete just sets the element to undefined
        @children.splice(idx, 1)

        # and remove the DOM element from play
        node.element.remove()



    ###
    High-level frame-management funcitons
    should be re-worked
    ###
    appendFrame: (frame) ->
        @addChild(frame)

        # DOM element management
        # insert after all current frames
        f = @frames[@frames.length - 1]
        if f
            f.element.after(frame.element)
        else
            @element.append(frame.element)

        # welcome, child!
        @frames.push(frame)

    addHandle: (handle) ->
        @addChild(handle)
        @handles.push(handle)

    # The sum of all frame widths should be 100%
    fitFrames: ->
        target  = 100
        current = @frames.reduce ((t, s) -> t + s.size), 0
        console.log('calculated size to be', current)
        ratio   = target / current
        console.log('ratio is', ratio)

        for f in @frames
            f.setSize(f.size * ratio)


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

    # reposition this handle
    layout: ->
        if not @parent
            throw new Error("HandleLayoutFailure: cannot lay out a handle without a parent")

        i = @parent.frames.indexOf(@frame)

        if i is -1
            throw new Error("InvalidGraph: frame #{@frame} not included in parent's frame table")

        offset = @parent.frames[0...i].reduce (t, s) -> t + s.size

        if @parent.layout is VERT
            ord = 'left'
        else
            ord = 'top'

        # reset
        @element.css('top', '')
        @element.css('left', '')

        @element.css(ord, "#{offset}%")


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

    empty_child = new Frame()
    full_child =  recursive_tree(dir_selector, depth_remaining - 1)

    root.appendFrame(empty_child)
    root.appendFrame(full_child)
    root.fitFrames()

    return root

exports = {
    'Frame':  Frame
    'Handle': Handle
    'VERT': VERT
    'HORIZ': HORIZ
    'recursive_tree': recursive_tree
    'select_alternate': select_alternate
}

# write out
window.Mousetile = exports










