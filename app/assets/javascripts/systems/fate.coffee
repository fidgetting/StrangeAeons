

################################################################################
### Controller #################################################################
################################################################################

class Across
  constructor: (subs...) ->
    @html = $ """<div></div>"""

    for sub in subs
      sub.html.css("display", "inline-block")
      @html.append sub.html

class Section
  constructor: (@name, @onAdd = undefined, @onDel = undefined) ->
    @html = $ """<div class="section"></div>"""
    @vals = $ """<div class="secbody #{@name}"></div>"""
    @head = $ """<div class="sechead"></div>"""

    @head.append """<span>#{@name}</span>"""
    @html.append @head
    @html.append @vals

    if @onAdd
      @add = $ """<button class="icon plus add"></button>"""
      @add.click (ev) => @onAdd(ev, @add)
      @head.append @add

    if @onDel
      @del = $ """<button class="icon delete del"></button>"""
      @del.click (ev) => @onDel(ev, @del)
      @head.append @del

class TextIn
  constructor: (html, classes, start, valid) ->
    @input = $ """<input type="text" class="#{classes}" value="#{start}">"""

    @input.focusout (ev) =>
      @input.remove()
      html.show()

    @input.keyup (ev) =>
      if ev.keyCode is 27 or ev.keyCode is 13
        if ev.keyCode is 13
          html.html(if @input.val() then @input.val() else "<br>")
          valid(@input.val())
        @input.remove()
        html.show()

    html.hide()
    html.after @input
    @input.focus();

################################################################################
### Aspects and Skills #########################################################
################################################################################

class Aspects extends Section
  constructor: (@values) ->
    super("Aspects")

    for idx, aspect of @values
      do (idx, aspect) =>
        cont = $ """<div class="aspect">#{if aspect == "" then "<br>" else aspect }</div>"""
        cont.click (ev) => @change(ev, cont, idx)

        @vals.append cont

  change: (ev, cont, idx) =>
    input = new TextIn cont, "aspectIn", @values[idx], (value) =>
      @values[idx] = value
    if idx is "4"
      log input
      input.input.css("margin-bottom", "4px")

class Skills extends Section
  constructor: (@values) ->
    super("Skills")

    @width    = Math.max(5, (elem.length for elem in @values)...)
    @rows     = [ ]
    @selected = { html: undefined, i: 0, j: 0, timer: false}

    log @values

    for i, name of addAmt.reverse()
      do (i, name) =>
        i = parseInt(i)

        header = $ """<div class="sheader">#{name} (+#{5 - i})</div>"""
        row    = $ """<div class="row"></div>"""
        boxes  = [ ]

        header.click (ev) => @addSkill(ev, 4 - i)
        row.append header

        for j in [0...@width]
          do (j) =>
            box = @mkBox(4 - i, j, row, boxes)

            boxes.push box
            row.append box

        @rows.unshift boxes
        @vals.append row

  mkBox: (i, j, row, boxes) =>
    box = $ """<div class="skill"></div>"""

    if not @values[i][j]
      box.append "<br>"
      box.addClass("empty")
      box.click (ev) => @addSkill(ev, i)
    else
      box.append @values[i][j]
      box.click (ev) => @change(ev, box, i, j)

    box

  addSkill: (ev, idx) =>
    log "addSkill: (#{idx})"

    html  = @rows[idx][@values[idx].length]

    if @selected.html
      [i, j] = @ij()

      @activate(html, idx, @values[idx].length, @values[i][j])
      @remove(i, j)

      @deselect()
    else
      input = new TextIn html, "skillIn", "", (value) =>
        @activate(html, idx, @values[idx].length - 1, value)

  change: (ev, cont, i, j) =>
    log "change: (#{i}, #{j})"

    if not @selected.html
      cont.addClass("selected")
      @selected.html  = cont
      @selected.i     = i
      @selected.j     = j
      @selected.timer = true
      delay 500, => @selected.timer = false

    else if @selected.html is cont
      if @selected.timer
        new TextIn cont, "skillIn", @values[i][j], (value) =>
          if value is ""
            @remove(i, j)
          else
            @values[i][j] = value
      @deselect()

    else
      [oi, oj] = @ij()
      [@values[i][j], @values[oi][oj]] = [@values[oi][oj], @values[i][j]]
      cont.html(@values[i][j])
      @selected.html.html(@values[oi][oj])
      @deselect()

  activate: (html, i, j, value) =>
    html.off 'click'
    html.click (ev) => @change(ev, html, i, j)
    html.removeClass "empty"
    html.html value
    @values[i].push value

  remove: (i, j) =>
    row  = @rows[i]
    html = row[j]
    @values[i].splice(j, 1)

    if j != @width then for idx in [j...@width - 1]
      row[idx].html(row[idx + 1].html())
      if row[idx + 1].hasClass("empty")
        row[idx].addClass("empty")
    row[row.length - 1].html "<br>"
    row[row.length - 1].addClass "empty"

    html.off "click"
    html.click (ev) => @addSkill(ev, i)

  deselect: =>
    if @selected.html
      @selected.html.removeClass("selected")
      @selected.html  = undefined
      @selected.timer = false

  ij: => [@selected.i, @selected.j]

  addAmt = [ "Average", "Fair", "Good", "Great", "Superb" ]

################################################################################
### Stories and Stunts #########################################################
################################################################################

# TODO finish the stories section
class Stories extends Section
  constructor: (@values) ->
    super("Stories")

class Stunt
  constructor: (@name, @values) ->
    @html = $ """<div class="stunt">#{@name}</div>"""
    @delb = $ """<button class="icon delete delb"></button>"""

    @delb.click @remove
    @html.append(@delb)

  remove: (ev) =>
    arRemove(@values, @name)
    @html.remove()

    log @values

class Stunts extends Section
  constructor: (@values) ->
    super("Stunts", @onAdd)

    for elem in @values
      @vals.append new Stunt(elem, @values).html

  onAdd: (ev, elem) =>
    input = $ """<input type="text" class="stuntIn">"""

    input.focusout (ev) =>
      input.remove()

    input.keyup (ev) =>
      if ev.keyCode is 27 or ev.keyCode is 13
        if ev.keyCode is 13 and input.val()
          @vals.append new Stunt(input.val(), @values).html
          @values.push(input.val())
        input.remove()

    @vals.append input
    input.focus()

################################################################################
### Stress and Consequences ####################################################
################################################################################

class Stress extends Section
  constructor: (@name, @values) ->
    super("#{@name} Stress", @onAdd, @onDel)

    @buttons = [ ]

    for idx in [0...@values.max]
      do (idx) =>
        button = $ """<button class="icon stressbox"></button>"""
        button.click (ev) => @onClick(ev, button, idx)
        button.addClass("#{if @values.filled[idx] then "cross" else "none"}#{idx}")

        @buttons.push button
        @vals.append button

  onClick: (ev, elem, idx) =>
    elem.toggleClass("none#{idx}")
    elem.toggleClass("cross#{idx}")
    @values.filled[idx] = not @values.filled[idx]

  onAdd: (ev, elem) =>
    button = $ """<button class="icon stressbox none#{@values.max}"></button>"""
    button.click (ev) => @onClick(ev, button, @values.max)

    @values.max++
    @values.filled.push false

    @buttons.push button
    @vals.append button

  onDel: (ev, elem) =>
    @buttons[@buttons.length - 1].remove()
    @buttons.pop()

    @values.max--
    @values.filled.pop()

class Stresses
  constructor: (@values) ->
    @html = $ """<div></div>"""
    @phys = new Stress("Physical", @values.physical)
    @ment = new Stress("Mental"  , @values.mental)

    @html.append @phys.html
    @html.append @ment.html

class Consequences extends Section
  constructor: (@values) ->
    super("Consequences")

    @minor    = $ """<div></div>"""
    @moderate = $ """<div></div>"""
    @major    = $ """<div></div>"""

    @minor   .append @mkBox(0)
    @minor   .append @mkBox(1)
    @moderate.append @mkBox(2)
    @major   .append @mkBox(3)

    @vals.append @minor
    @vals.append @moderate
    @vals.append @major

  mkBox: (idx) =>
    box = $ """<div class="conbox">#{
      if @values[idx] then @values[idx] else "<br>"
    }</div>"""

    box.click (ev) => new TextIn box, "consIn", @values[idx], (value) =>
        @values[idx] = value

    box

################################################################################
### Controller #################################################################
################################################################################

class Fate
  constructor: ->
    @container = $ "#fate"
    @body      = $ window

    @aspects  = new Aspects character.aspects
    @skills   = new Skills character.skills
    @newRow @aspects, @skills

    @stories  = new Stories character.stories
    @stunts   = new Stunts  character.stunts
    @newRow @stories, @stunts

    @stresses = new Stresses character.stress
    @cons     = new Consequences character.consequences
    @newRow @stresses, @cons

  newRow: (elems...) =>
    row = new Across(elems...)
    @container.append row.html

push -> sheet = new Fate
