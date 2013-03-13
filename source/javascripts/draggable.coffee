###
Simplistic global draggable implementation derived from
    (http://tpstatic.com/_sotc/sites/default/files/61/source/javascript.js)
    (http://tech.pro/tutorial/650/javascript-draggable-elements)

Depends on jQuery, and assumes that all elements will be jQuery elements
Relies on all elements being jQuery objects
###

class Position

    ordinals = ['x', 'y']

    @FromElement = (el) ->
        offset = el.offset()
        new Position(offset.left, offset.top)

    constructor: (x, y) ->
        @x = x
        @y = y

    clone: ->
        new Position(@x, @y)

    add: (p) ->
        res = @clone()
        if not p?
            return
        
        for o in ordinals
            if !isNaN(p[o])
                res[o] += p[o]

        return res

    sub: (p) ->
        res = @clone()
        if not p?
            return res

        for o in ordinals
            if !isNaN(p[o])
                res[o] -= p[o]

        return res

    min: (p) ->
        res = @clone()
        if not p?
            return res

        for o in ordinals
            if !isNaN(p[o]) and this[o] > p[o]
                res[o] = p[o]

        return res

    max: (p) ->
        res = @clone()
        if not p?
            return res

        for o in ordinals
            if !isNaN(p[o]) and this[o] < p[o]
                res[o] = p[o]

        return res

    bound: (lower, upper) ->
        @max(lower).min(upper)

    # return a validified copy of this
    check: ->
        res = @clone()
        for o in ordinals
            if isNaN res[o]
                res[o] = 0
        res

class Draggable
    event_namespace = 'mousetileDraggable'
    defaultRoot = window.document

    defaultMoveCb = (global, start, el) ->
        el.css
        top:  "#{global.y}px"
        left: "#{global.x}px"


    cancelEvent = (evt) ->
        evt.stopPropagation()
        evt.preventDefault()
        return false
     
    findPosition = (evt) ->
        new Position(evt.pageX, evt.pageY)

    # bind a function as `this`
    bind = (fn, obj) ->
        return ->
            fn.apply(obj, arguments)



                       # these are kwargs
    constructor: (el, {lowerBound, upperBound, startCb, moveCb, endCb, handle, root, attachLater}) ->
        @element = el                  # element to move
        @handle = handle || el         # click target

        @root = root || defaultRoot    # mouse move listener

        if lowerBound and upperBound
            @updateBounds(lowerBound, upperBound)

        # event callback
        @startCb = startCb
        @moveCb  = moveCb || defaultMoveCb
        @endCb   = endCb

        @cursorStartPos = null
        @elementStartPos = null

        @dragging = false
        @listening = false
        @disposed = false

        if not attachLater
            @startListening()


    # bind a method as an event handler on an element
    hook: (el, event_name, cb) ->
        bound = bind(cb, this)
        jQuery(el).on("#{event_name}.#{event_namespace}", null, null, bound)
    
    unhook: (el, event_name) ->
        jQuery(el).off("#{event_name}.#{event_namespace}")

    updateBounds: (lowerBound, upperBound) ->
        @lowerBound = lowerBound.min(upperBound)
        @upperBound = lowerBound.max(upperBound)
        console.log("bounds updated on draggable to", @lowerBound.x, @lowerBound.y, @upperBound.x, @upperBound.y)

    dragStart: (evt) ->

        # is this the right event?
        if evt.which != 1
            return 

        console.log(evt)

        return if @dragging or not @listening or @disposed
        console.log "dragStart"

        @dragging = true

        if @startCb
            @startCb(evt, @element)

        @cursorStartPos = new Position(evt.pageX, evt.pageY)
        pos = @element.offset()
        @elementStartPos = (new Position(pos.left, pos.top)).check()

        console.log('start position', @elementStartPos)

        # bind listeners to the root object, which is currently the
        # document.
        @hook(@root, "mousemove", @dragGo)
        @hook(@root, "mouseup", @dragStopHook)

        cancelEvent(evt)

    dragGo: (evt) ->
        return if not @dragging or @disposed

        pos = findPosition(evt)
        # adjust for cursor offset withing element
        pos = pos.add(@elementStartPos).sub(@cursorStartPos)
        # constrain to boundry points
        pos = pos.bound(@lowerBound, @upperBound)

        # Move callback should set the position change!!!!
        if @moveCb
            # abs_pos, abs_start_pos, element
            @moveCb(pos, @elementStartPos, @element)

        cancelEvent(evt)

    dragStop: ->
        return if not @dragging or @disposed

        @unhook(@root, "mousemove")
        @unhook(@root, "mouseup")

        @cursorStartPos = null
        @elementStartPos = null

        if @endCb
            @endCb(@element)

        @dragging = false

    dragStopHook: (evt) ->
        @dragStop()
        cancelEvent(evt)

    dispose: ->
        return if @disposed
        @stopListening(true)
        # possibly unneeded: we're an object now, instead of a closure
        @element = @handle = @lowerBound = @upperBound = @startCb = @endCb = @moveCb = null
        @disposed = true

    startListening: ->
        return if @listening or @disposed
        @listening = true
        @hook(@handle, "mousedown", @dragStart)

    stopListening: (stopCurrentDrag = false) ->
        return if not @listening or @disposed

        @unhook(@handle, "mousedown")
        @listening = false

        if stopCurrentDrag and @dragging
            @dragStop()

exports = {
    'Draggable': Draggable
    'Position':  Position
    'Point':     Position
}

window.Draggable = exports
