
################################################################################
### Utility ####################################################################
################################################################################

getAspect = (name, aspect, type = true) -> $($.parseHTML("
  <div class=\"aspect\" data-name=\"#{name}\">
    <div class=\"topright\">
      <button class=\"icon #{if type then "enter addto" else "delete remove"}\"></button>
    </div>
    <p class=\"name\">#{name}</p>
    <p class=\"creator\">#{aspect.creator}</p>
    <div class=\"types hidden\" style=\"display: none;\">
      <table class=\"tinner\">#{("
        <tr>
          <td>#{opt[0]}</td>
          <td class=\"right\">#{(opt[1] * 100).toFixed(1)} %</td>
        </tr>" for opt in aspect.values).join("")}
      </table>
    </div>
  </div>
  "))

getLink = (from, to, values) -> $($.parseHTML("
  <div class=\"aspect\" data-name=\"#{to}\" data-src=\"#{from}\">
    <div class=\"topright\">
      <button class=\"icon delete rmlink\"></button>
    </div>
    <p class=\"name\">#{from}</p>
    <p class=\"creator\">#{to}</p>
    <div class=\"types hidden\" style=\"display: none;\">
      <table class=\"tinner\">#{("
        <tr>
          <td>#{name}</td>
          <td class=\"right\">#{value}</td>
        </tr>" for name, value of values).join("")}
      </table>
    </div>
  </div>
  "))

getEthnicity = -> $($.parseHTML("
  <div class=\"aspect\">
    <div class=\"topright\">
      <button class=\"icon write\"></button>
    </div>
    <p class=\"name\">Ethnicities</p>
    <p class=\"creator\">weighted</p>
    <div class=\"types hidden\" style=\"display: none;\">
      <table class=\"tinner\" id=\"display\">
      </table>
    </div>
  </div>
  "))

ethSelect = -> $($.parseHTML("
  <select>
    <option value=\"\">-- choose --</option>
    #{ ("<option value=\"#{name}\">#{name}</option>" for name in npc_data.ethnicities).join("") }
  </select>
  "))

################################################################################
### New Format #################################################################
################################################################################

class NumberDefine
  constructor: (@value, @type = "number") ->
    @html = $("""<div class="numberDefine"></div>""")
    @inputs = { }

    for value in npc_data.aspects[@value].values
      next = $ """<input class="numberInput" type="text" value="0">"""
      body = $ """<div><span class="numberLabel">#{value[0]}</span></div>"""

      body.append next
      @html.append body
      @inputs[value[0]] = next

  remove: =>
    @html.remove()

  validate: =>
    valid = true

    for name, input of @inputs
      if isNaN(input.val())
        valid = false
        input.addClass "error"
      else input.removeClass "error"
    valid

  json: (from, to, dest) =>
    map = { }
    for name, input of @inputs
      map[name] = parseFloat(input.val())

    dest[to] = { type: @type, src: from, values: map }
    map

class MaskDefine
  constructor: (@from, @to, @type = "mask") ->
    @html = $("""<div class="maskDefine"></div>""")
    @mask = { }
    @fo_body = $("""<div class="maskFoBody"></div>""")
    @to_body = $("""<div class="maskToBody"></div>""")
    @selected = undefined
    @inputs   = { }
    @selects  = { }

    for value in npc_data.aspects[@from].values then do (value) =>
      curr = $ """<div class="maskLabel"><span>#{value[0]}</span></div>"""

      if not @selected
        @selected = { dom: curr, name: value[0] }

      curr.click (ev) =>
        @setSelected(curr, value[0])

      res = { }
      for inner in npc_data.aspects[@to].values
        res[inner[0]] = inner[1]

      @mask[value[0]] = res
      @selects[value[0]] = curr
      @fo_body.append curr

    for value in npc_data.aspects[@to].values then do (value) =>
      curr  = $ """<div class="toLabel"><span>#{value[0]}</span></div>"""
      input = $ """<input class="toInput" type="text" value="0">"""
      curr.append input

      @inputs[value[0]] = input
      input.change (ev) =>
        if not isNaN(input.val())
          @mask[@selected.name][value[0]] = parseFloat(input.val())

      @to_body.append curr

    @selected.dom.addClass("maskSelected");
    @setInputs(@selected.name)

    @html.append $("""<div class="inline">""").append @fo_body
    @html.append $("""<div class="inline">""").append @to_body

  setSelected: (curr, value) =>
    @selected.dom.toggleClass "maskSelected"
    @selected = { dom: curr, name: value }
    @selected.dom.toggleClass "maskSelected"
    @setInputs(@selected.name)

  setInputs: (value) =>
    for name, value of @mask[value]
      @inputs[name].val(value.toPrecision(3))

  remove: =>
    @html.remove()

  validate: =>
    valid = true

    for from, values of @mask
      for name, value of values
        if isNaN(value)
          valid = false
          @setSelected(@selects[from], from)
          @inputs[name].addClass("error")
        else @inputs[name].addClass("error")

    valid

  json: (from, to, dest) =>
    for name, values of @mask
      normalize(values)

    if not dest[to]
      dest[to] = [ ]
    dest[to].push { src: from, type: @type, values: @mask }

    @mask

class CreateLink
  constructor: (@ev, @base, @aspects, @dest) ->
    @body  = $("<div></div>")
    @from  = @makeSelect("mkLink", @aspects)
    @to    = @makeSelect("mkLink")
    @ltype = @makeSelect("mkLink", ["mask", "number"])
    @inner = undefined

    @body.append($("<div>").append @from)

    @ttip  = new ToolTip(@ev, @base, @onEnter, @onDelete, @body)

    @body.removeClass("tooltip")

    @from.click  @onFrom

  makeSelect: (name, values = []) ->
    ret = $ """<select class="#{name}"></select>"""
    ret.append """<option value="none">-- Choose --</option>"""
    for value in values
      ret.append """<option value="#{value}">#{value}</option>"""
    ret

  onFrom: (ev) =>
    @to.empty()

    @to.remove()
    @ltype.remove()

    if @inner
      @inner.remove()
      @inner = undefined

    if @from.val() != "none"
      @populateTo(@from.val())
      @to.click @onTo
      @body.append($("<div>").append @to)

  populateTo: (skip) =>
    @to.append("""<option value="none">-- Choose --</option>""")
    for aspect in @aspects when aspect != skip
      @to.append("""<option value="#{aspect}">#{aspect}</aspect>""")

  onTo: (ev) =>
    @ltype.remove()

    if @inner
      @inner.remove()
      @inner = undefined

    if @to.val() != "none"
      @ltype.val("none")
      @ltype.click @onType
      @body.append($("<div>").append @ltype)

  onType: (ev) =>
    if @inner
      @inner.remove()
      @inner = undefined

    if @ltype.val() != "none"
      @inner = switch @ltype.val()
        when "number" then new NumberDefine(@from.val())
        when "mask"   then new MaskDefine(@from.val(), @to.val())

      if @inner
        @body.append(@inner.html)

  validate: =>
    (@inner != undefined and @inner.validate())

  onEnter: (ev) =>
    if @validate()
      from = @from.val()
      to   = @to.val()
      map  = @inner.json(from, to, @dest)

      link = getLink(from, to, map)
      link.hide()
      $("#links").append(link)

      @ttip.remove()
      link.slideDown()

  onDelete: (ev) =>
    @ttip.remove()

################################################################################
################################################################################
################################################################################

npc_data = { }

class GameView extends Backbone.View
  events:
    "click    .aspect"          : "aspect"
    "click    .addto"           : "add"
    "click    .remove"          : "remove"
    "click    .create"          : "create"
    "click    .clink"           : "link"
    "click    .rmlink"          : "rmlink"
    "click    .write"           : "ethnicities"
    "click    .save"            : "enter"
    "click    .finished"        : "delete"
    
  initialize: ->
    _.bindAll @
    
    @newGame = $("#newgame") 
    @newGame.click @show
    
    @gameName  = $("#gameName")
    @system    = $("#system")
    @current   = $("#current")
    @available = $("#available")
    @links     = $("#links")
    @ethdisp   = getEthnicity()
    
    @chosen    = { }
    @linked    = { }
    @ethnicity = { }
    
    @current.append(@ethdisp)
    
    jsRoutes.controllers.GameMaster.data().ajax
      success: (data) =>
        npc_data.names       = data.names
        npc_data.adjectives  = data.adjectives
        npc_data.ethnicities = [ ]
        
        for name, _ of npc_data.names
          npc_data.ethnicities.push(name)
        npc_data.ethnicities.sort()
        
        ethOpt = $("#eth")
        ethOpt.append $("<option>").html(eth).attr("value", eth) for eth in npc_data.ethnicities
        
        if npcui
          npcui.populate()
    
    jsRoutes.controllers.GameMaster.aspects().ajax
      success: (data) =>
        npc_data.aspects = { }
        
        for aspect in data[0]
          npc_data.aspects[aspect.name] =
            creator: aspect.creator
            values:  aspect.values
        @populate()
      
  show: (ev) =>
    @newGame.hide()
    @el.slideDown()
  
  populate: =>
    for name in (n for n, _ of npc_data.aspects).sort()
      @available.append(getAspect(name, npc_data.aspects[name]))
  
  aspect: (ev) =>
    if !$(ev.target).is("button")
      target = $(ev.currentTarget).find(".types")
      if target.hasClass("hidden")
        target.slideDown()
      else
        target.slideUp()
      target.toggleClass("hidden")
  
  toggle: (target) =>
    target.toggleClass("addto")
    target.toggleClass("remove")
    target.toggleClass("enter")
    target.toggleClass("delete")
  
  add: (ev) =>
    target = $(ev.target).parent().parent()
    target.slideUp =>
      target.remove()
      @toggle $(ev.target)
      @current.append(target)
      target.slideDown()
    @chosen[target.attr "data-name"] = true
  
  remove: (ev) =>
    target = $(ev.target).parent().parent()
    target.slideUp =>
      target.remove()
      @toggle $(ev.target)
      @available.append(target)
      target.slideDown()
    @chosen[target.attr "data-name"] = false
  
  create: (ev) =>
    name  = $("<input class=\"hname\" type=\"text\">")
    types = $("<table>")
    add   = $("<button class=\"icon plus\">")
    ttip  = Tooltip(ev, true, name, types, add)
    @el.append(ttip)
    new AspectCreate
      el    : ttip
      name  : name
      types : types
      dest  : @current
      chosen: @chosen
  
  link: (ev) =>
    ttip = new CreateLink(ev, @el,
      (aspect for aspect, value of @chosen when value), @linked)
  
  rmlink: (ev) =>
    target = $(ev.target).parent().parent()
    name   = target.attr "data-name"
    src    = target.attr "data-src"
    link   = @linked[name]
    
    target.slideUp =>
      target.remove()
    
    if link.type is "number"
      delete @linked[name]
      return true
    else if link.type is "add"
      for idx in [0...link.values.length]
        if link.values[idx].src is src
          link.values.splice(idx, 1)
          return true
    
    return false
  
  ethnicities: (ev) =>
    label = $("<h2 style=\"width: 278px\">").html("Ethnicities")
    types = $("<table>")
    add   = $("<button class=\"icon plus\">")
    ttip  = Tooltip(ev, false, label, types, add)
    @el.append(ttip)
    edit = new EthnicityEdit
      el   : ttip
      add  : add
      types: types
      dest : @ethnicity
      disp : @ethdisp
    for name, value of @ethnicity
      edit.add name, value

  limitPrecision: (values) ->
    for name, value of values
      values[name] = parseFloat(value.toPrecision(2))

  enter: (ev) =>
    name = @gameName.val()
    sys  = @system.val()

    for _, links of @linked
      if Array.isArray(links)
        for link in links
          for _, mask of link.values
            @limitPrecision(mask)
    data =
      aspects  : (n for n, _ of @chosen)
      links    : @linked
      ethnicity: @ethnicity

    jsRoutes.controllers.Games.save(name).ajax
      data: { gameData: JSON.stringify(data), gameSystem: sys }
      success: (data) => $("#games").append(data)
    
    @delete()
  
  delete: (ev) =>
    @el.slideUp =>
      @current.empty()
      @available.empty()
      @populate()
      @newGame.show()

class AspectCreate extends Backbone.View
  events: 
    "click    .plus"            : "plus"
    "click    .enter"           : "enter"
    "click    .delete"          : "delete"
  
  initialize: (pass) ->
    _.bindAll @
    @name   = pass.name
    @types  = pass.types
    @dest   = pass.dest
    @chosen = pass.chosen
    @input  = [ ]
    
  plus: (ev) =>
    wrap = (h) -> $("<td>").append(h)
    
    name  = $("<input class=\"tname\" type=\"text\">")
    value = $("<input class=\"tvalue\" type=\"text\">")
    value.val("1")
    @types.append($("<tr>").append(wrap name).append(wrap value))
    @input.push { name: name, value: value }
  
  validate: =>
    valid  = true
    check = (elem, add...) =>
      inner = false
      for el in add
        if el(elem) then inner = true
      if elem.val() == "" or inner
        valid = false
        elem.addClass("error")
      else elem.removeClass("error")
        
    check @name
    if @input.length == 0
      valid = false
    
    for elem in @input
      check elem.value, (el) -> isNaN(el.val())
      check elem.name
    valid
  
  enter: (ev) =>
    total  = 0
    result = [ ]
    
    if !@validate()
      return false
    
    for elem in @input
      curr = parseFloat elem.value.val()
      result.push [ elem.name.val(), curr]
      total += curr
    result = { vals: ([a[0], a[1] / total] for a in result)}
    
    jsRoutes.controllers.GameMaster.aspect(@name.val(), JSON.stringify(result)).ajax
      success: (data) =>
        @dest.append(getAspect(data.name, data.aspect, false))
        @chosen[data.name] = true
    
    npc_data.aspects[@name.val()] = {
      "creator" : "current",
      "values"  : result
    }
    
    @delete()
    
  delete: (ev) =>
    @el.remove()

class EthnicityEdit extends Backbone.View
  events: 
    "click    .plus"            : "plus"
    "click    .enter"           : "enter"
    "click    .delete"          : "delete"
  
  initialize: (pass) ->
    _.bindAll @
    
    @table = pass.types
    @dest  = pass.dest
    @disp  = pass.disp
    @input = [ ]
    
  plus: (ev) =>
    @add("", 1)
  
  add: (name, base) =>
    wrap = (h) -> $("<td>").append(h)
    
    select = $(ethSelect()[1])
    select.val(name)
    value  = $("<input class=\"tvalue\" type=\"text\">")
    value.val(base.toString())
    @table.append($("<tr>").append(wrap select).append(wrap value))
    @input.push([select, value])
    
  validate: =>
    valid  = true
    check = (elem, add...) =>
      inner = false
      for el in add
        if el(elem) then inner = true
      if elem.val() == "" or inner
        valid = false
        elem.addClass("error")
      else elem.removeClass("error")
    
    for select in @input
      check select[0]
      check select[1], (el) -> !isNaN(el)
    valid
    
  enter: (ev) =>
    total = 0
    table = $(@disp.find("#display"))
    
    if !@validate()
      return false
    
    for elem in @input
      elem[1] = parseFloat(elem[1].val())
      total += elem[1]
    
    table.empty()
    for elem in @input
      elem[1] = elem[1] / total
      @dest[elem[0].val()] = elem[1]
      table.append("
      <tr>
        <td>#{elem[0].val()}</td>
        <td class=\"right\">#{(elem[1] * 100).toFixed(1)} %</td>
      </tr>")
    
    @delete(ev)
  
  delete: (ev) =>
    @el.remove()

push -> new GameView
  el: $("#gameCreate")
