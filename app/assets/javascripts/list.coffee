
################################################################################
################################################################################
################################################################################

getCharacter = (data) ->
  img = $("""<img class="picture charIcon" data-id="#{data.id}" src="#{data.thumb}" alt="character pic">""")
  res = $($.parseHTML("""
    <div class="inline showEntity">
      <div class="box character">
        <div class="topright"></div>
        <span>
          <a id="c_name" href="#{data.name.link}"><b>#{data.name.name}</b></a>
          <a class="gameLink" href="#{data.user.link}">#{data.user.name}</a>
          <a class="gameLink" href="#{data.game.link}">#{data.game.name}</a>
        </span>
      </div>
    </div>
  """)[0])
  
  img.click (ev) ->
    navigator.picture(ev)  
  res.find(".character").prepend(img)
  
  btn = if data.owned
    $("""<button class="icon delete"</button>""")
  else if data.master
    $("""<button class="icon enter"</button>""")
  else
    undefined
  res.find(".topright").append(btn)
  
  [res, btn]

makeCharacter = (data) ->
  res = $($($.parseHTML(data))[1])
  res.on "click", "img.picture", (ev) ->
    navigator.picture(ev)
  res

characterLink = (id, name) ->
  "<li data-character=\"#{id}\">
    <a class=\"name\" href=\"/character?id=#{id}\">#{name}</a>
  </li>"

getGroup = (name, chars) ->
  dif = 10
  
  res = $($.parseHTML("""
    <div class="box groupBy"
     style="
       width: #{ 350 + chars.length * dif }px;
       height: #{ 116 + chars.length * dif }px;">
      <span class="label">#{name}</span>
    </div>
  """)[0])
  
  x = 5
  y = 35
  
  for character in chars
    html = character.el
    html.css("left", x)
    html.css("top" , y)
    html.removeClass("showEntity")
    html.addClass("groupEntity")
    res.append(html)
    
    $(html.children()[0]).addClass("popUp")
    
    x += dif
    y += dif
  
  res

################################################################################
################################################################################
################################################################################

class CharacterSet extends Backbone.View
  initialize: ->
    @cCreate  = $("#characterCreate")
    @cInput   = $("#characterInput" )
    @cont     = $("#createContainer")
    @groupSet = $("#groupSet")
    @groupSel = $("#groupSelect") 
    @cCreate.click @addCharacter
    @expanded = undefined
    @cv = new CreateView
      el : @cInput
      ncv: @cCreate
    
    @groups = { }
    for character in characters
      for data, option of character.info
        if @groups[data] == undefined
          @groups[data] = [ ]
        if $.inArray(option, @groups[data]) == -1
          @groups[data].push(option)
    for group, _ of @groups
      @groupSel.append("""<option value="#{group}">#{group}</option>""")
    
    @characters = for character in characters
      [html, button] = getCharacter(character)
      new Character
        el     : html
        button : button
        data   : character
        
    @groupSel.change((ev) => @groupBy @groupSel.val()).change()
    
  addCharacter: (ev) =>
    @cCreate.hide()
    @cInput.show()
  
  groupBy: (name) =>
    @groupSet.empty()
    if name == "none"
      for character in @characters
        character.el.addClass("showEntity")
        character.el.insertBefore(@cont)
    else
      mkg = (group, eq) =>
        chars = (c for c in @characters when eq(c.data.info[name]))
        html = getGroup(group, chars)
        @groupSet.append(html)
        new Group
          el   : html
          name : group
          owner: @
          chars: chars
      
      for group in @groups[name]
        mkg(group, (name) => name == group )
      mkg("Undefined", (name) => name == undefined or name == "")
      

class Character extends Backbone.View
  initialize: (pass) ->
    _.bindAll @
    @button = pass.button
    @data   = pass.data
    
    if @button
      @button.click (ev) =>
        if @data.state == "owned"
          @delete(ev)
        else
          @enter(ev)
    
  enter: (ev) =>
    jsRoutes.controllers.Characters.take(@data.id).ajax
      success: (data) =>
        ta = $(ev.target)
        ta.removeClass "enter"
        ta.addClass    "delete"
        ta.click       @delete
      error: (err) =>
  delete: =>
    jsRoutes.controllers.Characters.delete(@data.id).ajax
      success: (data) =>
        $("##{@data.min}").remove()
        @el.animate({width: 'toggle'}, => @el.remove())
      error: (err) ->

class Group extends Backbone.View
  initialize: (pass) ->
    _.bindAll @
    @el.click (ev) => @expand(ev)
    
    @name  = pass.name
    @owner = pass.owner
    @chars = pass.chars
  
  expand: (ev) =>
    if @owner.expanded
      @owner.expanded.collapse( =>
        @owner.expanded = undefined
        @expand(ev))
    else
      @el.hide()
      for c in @chars
        c.el.remove()
        c.el.removeClass("groupEntity")
        c.el.addClass("showEntity")
        c.el.insertBefore(@owner.cont)
      @owner.expanded = @
  
  collapse: (after) =>
    log @name
    for c in @chars
      c.el.remove()
      c.el.addClass("groupEntity")
      @el.append(c.el)
    @el.show()
    after()

class CreateView extends Backbone.View
  events:
    "click    .delete"          : "delete"
    "click    .enter"           : "enter"
    "change   .system"          : "games"
  initialize: (pass) ->
    _.bindAll @
    @ncv  = pass.ncv
    @cont = $("#createContainer")
    @game = $("#game")
    @name = $("#name")
  games: =>
    jsRoutes.controllers.Games.games($(".system").val()).ajax
      success: (data) =>
        @game.empty()
        @gameNames = { }
        for game in data
          @gameNames[game.id] = game.name
          opt = $("<option>")
          opt.attr value: "#{game.id}"
          opt.html game.name
          opt.appendTo("#game")
      error: (err) =>
        @game.empty()
        @gameNames = { }
  enter: (ev) =>
    jsRoutes.controllers.Characters.save(@name.val(), @game.val()).ajax
      data: { data: "{}", note: "New Character" }
      success: (data) =>
        gameid = $("##{@gameNames[@game.val()].replace(" ", "")}") 
        gameid.append($.parseHTML(characterLink(data.id, data.name.name)))
        [html, button] = getCharacter(data)
        html.hide()
        @cont.before html
        html.animate({width: 'toggle'})
        new Character
          el     : html
          button : button
          data   : data
      error: (err) =>
    @delete(ev)
  delete: (ev) =>
    @name.val("")
    @el.hide()
    @ncv.show()

character_set = undefined
push -> character_set = new CharacterSet el: $("#characterSet")
