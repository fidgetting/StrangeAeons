
################################################################################
### Utility ####################################################################
################################################################################

callbacks = [ ]

push       = (pass)     -> callbacks.push(pass)
delay      = (ms, func) -> setTimeout(func, ms)
log        = (args...)  -> console.log.apply console, args if console.log?
complete   =            -> call() for call in callbacks
sum        = (list)     -> list.reduce (t, s) -> t + s

trace = ->
  e = new Error("dump");
  s = e.stack.replace(/^[^\(]+?[\n$]/gm, '')
      .replace(/^\s+at\s+/gm, '')
      .replace(/^Object.<anonymous>\s*\(/gm, '{anonymous}()@')
      .split('\n')
  console.log.apply console, s if console.log?

normalize = (base) ->
  if Array.isArray(base)
    total = (base.reduce (a, b) -> a = a + b)
    (value / total for value in base)
  else if typeof base == "object"
    total = ((value for _, value of base).reduce (a, b) -> a = a + b)
    (base[name] = value / total for name, value of base)
    base
  else
    base

zip = () ->
  lenArr = (arr.length for arr in arguments)
  length = Math.min(lenArr...)
  for i in [0...length]
    arr[i] for arr in arguments

the_flip = (a) ->
  parsed = (/((The|the) )?(.+)/).exec(a)
  if parsed[1] then "#{parsed[3]}, The" else a

arRemove = (arr) ->
  a = arguments
  l = a.length

  while l > 1 and arr.length
    what = a[--l]

    while ((ax = arr.indexOf(what)) != -1)
      arr.splice(ax, 1)

  arr

delGame = =>
  confirm("Delete Game?")

################################################################################
### Used when disabling the main screen ########################################
################################################################################

date      = new Date()
time      = date.getTime()

saveClick  = ->
  to_cover = $("#character_sheet")
  cover    = $("#cover")
  cover.css("height", to_cover.height())
  cover.css("width" , to_cover.width())

  cover.fadeIn()
  time = date.getTime()

saveFinish = ->
  now = date.getTime()
  if now - time < 1000
    delay 1000, -> $("#cover").fadeOut()
  else
    $("#cover").fadeOut()

################################################################################
### Used for tooltips ##########################################################
################################################################################

class Cover
  constructor: (@elem) ->
    position = elem.position()
    @cover = $("<div class=\"busy\" style=\"
      top: #{position.top}px;
      left: #{position.left}px;
      height: #{elem.height()}px;
      width: #{elem.width() - 20}px;\">")
    elem.after(@cover)
  clear: =>
    @cover.remove()

fromString = (string) => $($.parseHTML(string)[0])

class ToolTip
  constructor: (@ev, @base, @onEnter, @onDelete, elems...) ->
    @entbtn = $("""<button class="icon enter" ></button>""")
    @delbtn = $("""<button class="icon delete"></button>""")

    @entbtn.click (ev) => @onEnter(ev)
    @delbtn.click (ev) => @onDelete(ev)

    @topr = $("""<div class="topright">""")
    @html = $("""<div class="textE" style="left: #{@ev.pageX - 218}px; top:#{ev.pageY - 43}px;">""")

    @inner = $("""<div id="inner" class="surroundw">""")

    @addClass(elems)

    @topr.append @entbtn
    @topr.append @delbtn

    @html.append @topr
    @html.append @inner
    @base.append @html

  addClass: (elems) =>
    for elem in elems
      if Array.isArray(elem)
        @addClass(elem)
      else
        elem.addClass "tooltip"
        elem.keyup @onKey
        @inner.append elem

  onKey: (ev) =>
    if ev.keyCode is 13
      @onEnter()
    else if ev.keyCode is 27
      @onDelete()

  append: (elems...) =>
    @addClass(elems)

  remove: =>
    @html.remove()

Tooltip = (ev, mobv, inner...) ->
  [res, html] = makeToolTip(ev, mobv)
  for elem in inner
    elem.addClass("tooltip")
    html.append(elem)
  res

makeToolTip = (ev, mobv) ->
  inner = fromString """
  <div id="inner" class="#{ if mobv then "surroundw" else "surround" }">
  </div>"""

  res = fromString """
  <div class="textE" style="left: #{ev.pageX - 218}px; top: #{ev.pageY - 43}px;">
    <div class="topright">
      <button class="icon enter" ></button>
      <button class="icon delete"></button>
    </div>
  </div>"""

  res.append(inner)

  [res, inner]

getSelect = (list) =>
  ret = $ """<select size="10" class="select">"""

  if Array.isArray(list)
    for name in list
      ret.append($ """<option value="#{name}">#{name}</option>""")
  else
    for from in (name for name, _ of list).sort()
      ret.append($ """<option value="#{list[from]}">#{from}</option>""")

  ret

################################################################################
### Cover dialogs ##############################################################
################################################################################

overall_container = $ "#main"
overall_window    = $ window
class AlertDialog
  constructor: (@inner) ->
    @html  = $ """<div class="dialog"></div>"""
    @alert = $ """<div class="alert"></div>"""
    @cover = $ """<div class="pageCover"></div>"""

    @cover.css "height", overall_window.height
    @cover.css "width" , overall_window.width

    @alert.append @inner.html
    @html.append @alert
    @html.append @cover

    overall_container.append(@html)
    log "called"

