
getRow = (name) ->
  $($.parseHTML("
  <tr>
    <td><input type=\"checkbox\" class=\"fix\" data-id=\"name\"></td>
    <td>#{name}</td>
    <td id=\"name\" class=\"right\"></td>
  </tr>
  "))

class NpcCreate extends Backbone.View
  events:
    "click    .enter"           : "enter"
    "click    .fix"             : "fix"
    "click    .ethnicity"       : "generate"
    "click    .names"           : "chooseName"
  
  fixed:
    gender   : false
    adjective: false
  
  initialize: ->
    @ethsel      = $("#eth")
    @nameSelect  = $("#names")
    @table       = $(".aspects")
    @cont        = $("#createContainer")
    @note        = $("#note")
    @aspects     = { }
    @links       = { }
    @ethnicity   = [ ]
    @npc         = { }
  
  addAspect: (aspect) =>
    newRow = getRow(aspect)
    @aspects[aspect] = newRow.find("#name")
    @table.append newRow
  
  addLink: (dest, link) =>
    @links[dest] = link
  
  addEthnicity: (name, value) =>
    @ethnicity.push([name, value])
  
  fix: (ev) =>
    elem = $(ev.toElement)
    @fixed[elem.attr("data-id")] = elem.is(":checked")
    log(@fixed)
  
  chooseName: =>
    if name = @nameSelect.val()
      $("#npc_name").html(name)
      @npc.Name = name
  
  generate: =>
    @new_npc   = { }
    @npc.Gender    = @getGender()
    @npc.Ethnicity = @getEthnicity()
    @npc.Adjective = @getAdjective()
    for aspect, elem of @aspects
      @fillAspect(aspect, npc_data.aspects[aspect].values) 
      elem.html @new_npc[aspect]
      @npc[aspect] = @new_npc[aspect]
    @setNames(@npc.Gender, @npc.Ethnicity)
  
  getGender: =>
    ret = if !! Math.round(Math.random()) then "male" else "female"
    $("#gender").html(ret)
    ret
  
  getEthnicity: =>
    ret = (if @ethsel.val() == "weighted"
      @fromValues(@ethnicity)
    else if @ethsel.val() == "random"
      npc_data.ethnicities[Math.floor(Math.random() * npc_data.ethnicities.length)]
    else @ethsel.val())
    $("#ethnicity").html(ret)
    ret
  
  getAdjective: =>
    ret = npc_data.adjectives[Math.floor(Math.random() * npc_data.adjectives.length)]
    $("#adjective").html(ret)
    ret
  
  fromValues: (values) =>
    norm = normalize(elem[1] for elem in values)
    goal = Math.random()
    value = 0
    for i in [0...values.length]
      value += norm[i]
      if value > goal
        return values[i][0]
  
  getAspect: (name, aspect) =>
    link = undefined

    if link = @links[name]
      if Array.isArray(link)
        use = (1 for _ in [0...aspect.length])

        for elem in link
          @fillAspect elem.src, npc_data.aspects[elem.src].values

          mult = (value for _, value of elem.values[@new_npc[elem.src]])
          use = normalize(value[0] * value[1] for value in zip(use, mult))

        for i in [0...aspect.length]
          log "#{aspect[i][0]} => #{use[i]}"
        @fromValues zip(value[0] for value in aspect, use)
      else
        @fillAspect link.src, npc_data.aspects[link.src].values
        (@fromValues(aspect) for i in [0...link.values[@new_npc[link.src]]]).join(", ")
    else @fromValues aspect
  
  fillAspect: (name, aspect) =>
    if !@new_npc[name]
      @new_npc[name] = @getAspect(name, aspect)
  
  getName: (gender, eth) =>
    pos = npc_data.names[eth][gender]
    pos[Math.floor(Math.random() * pos.length)]
  
  setNames: (gender, eth) =>
    @clearNames()
    @nameSelect.append($("<option>").html(@getName(gender, eth)) for _ in [1..10])
  
  clearNames: ->
    @nameSelect.html("")
  
  populate: =>
    for aspect in game_data.aspects
      @addAspect aspect
    for dest, link of game_data.links
      @addLink dest, link
    for name, value of game_data.ethnicity
      @addEthnicity(name, value)
  
  enter: =>
    if @npc.Name
      jsRoutes.controllers.Characters.save(@npc.Name, game_id).ajax
        data: { data: JSON.stringify(@npc), note: @note.val() }
        success: (data) =>
          gameid = $("##{game_name.replace(" ", "")}") 
          gameid.append($.parseHTML(characterLink(data.id, data.name.name)))
          [html, button] = getCharacter(data)
          html.hide()
          @cont.before html
          html.animate({width: 'toggle'})
          new Character
            el     : html
            button : button
            data   : data

npcui         = undefined
push -> npcui = new NpcCreate
  el: $("#npcCreate")
  
################################################################################
################################################################################
################################################################################

class UserAdd extends Backbone.View
  events:
    "click    .add"             : "add"
    "click    .remove"          : "remove"
  
  initialize: ->
    _.bindAll @
    
    @ingame  = $("#ingame")
    @outgame = $("#outgame")
  
  toggle: (target) =>
    target.toggleClass("add")
    target.toggleClass("remove")
    target.toggleClass("enter")
    target.toggleClass("delete")
  
  add: (ev) =>
    target = $(ev.currentTarget).parent().parent()
    jsRoutes.controllers.Games.add(target.attr("data-game"), target.attr("data-user")).ajax
      success: (data) =>
        target.slideUp =>
          target.remove()
          @toggle $(ev.target)
          @ingame.append(target)
          target.slideDown()
  
  remove: (ev) =>
    target = $(ev.currentTarget).parent().parent()
    jsRoutes.controllers.Games.remove(target.attr("data-game"), target.attr("data-user")).ajax
      success: (data) =>
        for id in data.names
          for elem in $(".char#{id}")
            elem.remove()
        target.slideUp =>
          target.remove()
          @toggle $(ev.target)
          @outgame.append(target)
          target.slideDown()
    

push -> new UserAdd
  el: $("#users")

  