
dot_cost = (value, per_dot) ->
  sum = (a, b) => a + ((b + 1) * per_dot)
  ([0...value].reduce(sum, 0))

merit_cost = (name, value) ->
  sub = name.split(" \(")[0]
  if system.merits[sub].flat
    system.merits[sub].value * 2
  else
    dot_cost(value, 2)

calculate_trait = (c, trait) ->
  total = 0
  
  types =
    merits:  =>
      for name, value of c.merits
        cost = merit_cost(name, value)
        
        if $.inArray(name, meta.discounted) >= 0
          cost = cost / 2
        
        total += cost
    
    disciplines: =>
      for name, value of c.disciplines
        if $.inArray(name, meta.discounted) >= 0
          total += dot_cost(value, 5)
        else total += dot_cost(value, 7)
    
    specialties: =>
      specs = [ ]
      for _, value of c.specialties
        for spec in value
          if $.inArray(spec, specs) >= 0
            total += 2
          else
            total += 3
            specs.push spec

    rituals: =>
      totals = ({"Crúac": false, "Theban Sorcery": false, count: 0 } for _ in [1..5])

      for name, _ of c.rituals
        ritual = system.rituals[name]
        dot    = parseInt(ritual.dot) - 1
        if not totals[dot][ritual.discipline]
          totals[dot][ritual.discipline] = true
        else totals[dot].count++

      for i in [1..5]
        counts = totals[i - 1]
        total += (2 * i) * counts.count

    devotions: =>
      for name, _ of c.devotions
        total += system.devotions[name]

  types[trait]()
  total

xp_lock  = false
xp_value = -1
click_xp_lock = (val, c) =>
  xp_lock  = val
  xp_value = calculate_xp(c)

calculate_xp = (c) ->
  total = 0
  
  for name, value of c.attributes
    total += dot_cost(value, 5)
    total -= 5
  
  for name, value of c.skills
    total += dot_cost(value, 3)
  
  for trait in meta.alternateDisplay
    total += calculate_trait(c, trait)
  
  total += dot_cost(c.potency, 8) - 8

  if xp_lock and xp_value >= 0 and (total - c.xp_diff) != xp_value
    c.xp_diff = total - xp_value
  
  total - c.xp_diff

update_funcs    = [ ]
update_register = { }

update_calculated = ->
  for pair in update_funcs
    if pair[1]
      pair[0](update_register[pair[1]])
    else pair[0]()

add_updater = (func, name = undefined) ->
  update_funcs.push([func, name])

register_update = (name, obj) ->
  update_register[name] = obj

################################################################################
### Main Traits ################################################################
################################################################################

class DotSet
  constructor: (@value, @call, @max = 5, zero_b = true, @filled = "● ", @empty = "○ ") ->
    @html = $("""<div class="right">""")
    @cont = $("""<div class="dotset">""")
    @dot_set  = [ ]
    
    if zero_b
      @dot_zero = $("""<span class="dot zero">X </span>""")
    
      @dot_zero.click =>
        @select(0)
    
      @cont.append(@dot_zero)
    
    for i in [0...@max]
      do (i) =>
        elem = $("""<span class="dot">#{
          if i < @value then @filled else @empty
        } </span>""")
        
        @cont.append(elem)
        @dot_set.push(elem)
        
        elem.click =>
          @select(i + 1)
    
    @html.append(@cont)
  
  select: (idx) =>
    @value = idx
    
    for i in [@value...@max]
      @dot_set[i].html @empty
    
    for i in [0...@value]
      @dot_set[i].html @filled
    
    @call(@value)
    update_calculated()

attribute_order = 
  "mental"   : ["Intelligence", "Wits"        , "Resolve"  ],
  "physical" : ["Strength"    , "Dexterity"   , "Stamina"  ],
  "social"   : ["Presence"    , "Manipulation", "Composure"]

class Attributes
  constructor: (@values) ->
    @html     = $("""<div class="section attributes">""")
    @mental   = $("""<div class="attribute border_right">""")
    @physical = $("""<div class="attribute border_right">""")
    @social   = $("""<div class="attribute">""")
    
    @html.append("""
    <div class="header">
      <span class="sectionName">Attributes</spen>
    </div>""")
    
    container = $("""<div class="body">""")
    
    @render(@mental  , "mental"  )
    @render(@physical, "physical")
    @render(@social  , "social"  )
    
    container.append @label()
    container.append @mental
    container.append @physical
    container.append @social
    @html.append container
    
  render: (dest, type) ->
    list = attribute_order[type]
    
    for name in list
      do (name) =>
        dots = new DotSet(@values[name], ((nval) => @values[name] = nval), 5, false)
        
        cont = $("<div>")
        cont.append """<span class="attributeName">#{name}</span>"""
        cont.append dots.html
        dest.append cont
   
  label: ->
    $("""
    <div class="label border_right">
      <div>Power</div>
      <div>Finesse</div>
      <div>Resistance</div>
    </div>
    """)

class Skills
  constructor: (@values) ->
    @html     = $("""<div class="section skills">""")
    @mental   = @getSkillHtml("Mental"  , 3)
    @physical = @getSkillHtml("Physical", 1)
    @social   = @getSkillHtml("Social"  , 1)
    
    @html.append("""
    <div class="header">
      <span class="sectionName">Skills</span>
    </div>""")
    
    @container = $("""<div class="body lower">""")
    
    @render(@mental  , "mental"  )
    @render(@physical, "physical")
    @render(@social  , "social"  )
    
    @container.append @mental
    @container.append @physical
    @container.append @social
    @html.append @container

  getSkillHtml: (name, sub) ->
    $ """
      <div class="skill">
        <div class="skillType"><span>#{name}</span></div>
        <div class="skillSub"><span>-#{sub} for unskilled</span></div>
      </div>
      """
  
  render: (dest, type, sub) ->
    list = system.SkillGroups[type]
    
    for name in list
      do(name) =>
        dots = new DotSet(@values[name], (nval) => @values[name] = nval)
    
        cont = $("<div>")
        cont.append """<span class="skillName">#{name}</span>"""
        cont.append dots.html
        dest.append cont

  height: =>
    @container.css("height")

################################################################################
### Other Traits ###############################################################
################################################################################

class Trait
  constructor: (@name) ->
    @html = $ """<div class="trait #{@name}"></div>"""
    @vals = $ """<div class="trait_body"></div>"""
    @head = $ """<div class="traitName">"""
    @add  = $ """<button class="icon plus add"></button>"""

    @head.append """<span>#{@name}</span>"""
    @head.append @add

    @html.append @head
    @html.append @vals

  tDel: (ev) =>
    if @ttip
      @ttip.remove()

class Merits extends Trait
  constructor: (@values, @base) ->
    super("Merits")

    for name in (n for n, _ of @values).sort()
      @vals.append @makeHtml(name, @values[name])
    
    @add.click @addMerit
  
  makeHtml: (name, value) =>
    dots = new DotSet(value, (nval) => @values[name] = nval)
    delb = $ """<button class="icon delete delbtn">"""
    cont = $ """<div class="delctn">"""

    delb.click (ev) => @removeMerit(ev, name, cont)

    cont.append """<span>#{name}</span>"""
    cont.append dots.html
    cont.append delb
    cont
  
  addMerit: (ev) =>
    @sele  = getSelect((merit for merit of system.merits).sort())
    @text  = $("<textarea>")
    @check = $("<input type=\"checkbox\">")
    disc   = $("<span>Discounted:</span>").append(@check)
    @ttip  = new ToolTip(ev, @base, @tAdd, @tDel, @sele, @text, disc)

  removeMerit: (ev, name, container) ->
    delete @values[name]
    container.remove()
    update_calculated()
  
  tAdd: (ev) =>
    if @sele.val() and not @values[@sele.val()]
      val = (if @text.val() then "#{@sele.val()} (#{@text.val()})" else @sele.val())
      mer = system.merits[@sele.val()]
      @values[val] = if mer.flat then mer.value else 0
      @vals.append @makeHtml(val, @values[val])
      if @check.is(":checked")
        meta.discounted.push(val)
    @ttip.remove()
    
    update_calculated()

class Specialties extends Trait
  constructor: (@values, @base) ->
    super("Specialties")

    @setHtml()

    @add.click @addSpecialty
  
  getHtml: (name, specialties) =>
    curr= $("<div>")
    list = $("""<ul class="right specialties">""")

    for spec in specialties
      do (spec) =>
        cont = $ """<li class="delctn">#{spec}</li>"""
        delb = $ """<button class="icon delete delbtn">"""

        delb.click (ev) => @removeSpecialty(ev, name, spec, cont, curr)

        cont.append(delb)
        list.append(cont)

    curr.append """<span>#{name}</span>"""
    curr.append list
    
    curr

  setHtml: =>
    names = (name for name, _ of @values)
    names.sort()

    @vals.empty()
    for name in names
      @vals.append @getHtml(name, @values[name])

  addSpecialty: (ev) =>
    @sele  = getSelect([].concat (group for _, group of system.SkillGroups)...)
    @text  = $("<textarea>")
    @ttip = new ToolTip(ev, @base, @tAdd, @tDel, @sele, @text)

  removeSpecialty: (ev, skill, name, cont, list) =>
    @values[skill].splice(@values[skill].indexOf(name), 1)
    cont.remove()

    if @values[skill].length == 0
      delete @values[skill]
      list.remove()

    update_calculated()

  tAdd: (ev) =>
    if @sele.val() and @text.val()
      if @values[@sele.val()]
        @values[@sele.val()].push @text.val()
      else
        @values[@sele.val()] = [@text.val()]
    
    @setHtml()
    @ttip.remove()
    
    update_calculated()

class Disciplines extends Trait
  constructor: (@values, @base) ->
    super("Disciplines")

    for name in (n for n, _ of @values).sort()
      @vals.append @makeHtml(name, @values[name])

    @add.click @addDiscipline

  makeHtml: (name, value) =>
    dots = new DotSet(value, (nval) => @values[name] = nval)
    delb = $ """<button class="icon delete delbtn">"""
    cont = $ """<div class="delctn">"""

    delb.click (ev) => @removeDiscipline(ev, name, cont)

    cont.append """<span>#{name}</span>"""
    cont.append dots.html
    cont.append delb
    cont

  addDiscipline: (ev) =>
    @sele  = getSelect((discipline for discipline of system.disciplines).sort())
    @check = $("<input type=\"checkbox\">")
    disc   = $("<span>Discounted:</span>").append(@check)
    @ttip  = new ToolTip(ev, @base, @tAdd, @tDel, @sele, disc)

  removeDiscipline: (ev, name, cont) =>
    delete @values[name]
    cont.remove()
    update_calculated()

  tAdd: (ev) =>
    if @sele.val() and not @values[@sele.val()]
      val = @sele.val()
      @values[val] = 0
      @vals.append @makeHtml(val, 0)
      if @check.is(":checked")
        meta.discounted.push(val)
    @ttip.remove()

    update_calculated()

class Rituals extends Trait
  constructor: (@values, @base) ->
    super("Rituals")

    @catagories = ((
      $("""<div class="dotDisplay">""").append("""<span>#{i} Dot</span>""")
    ) for i in [1..5])

    for cat in @catagories
      @vals.append cat

    @poss = { }
    for name, _ of system.rituals
      @poss[the_flip(name)] = name

    names = (name for name, _ of @values)

    for name in names
      ritual = system.rituals[name]
      @addHtml(name, ritual.dot)

    @add.click @addRitual

  addHtml: (name, dot) =>
    elem = $ """<div class="delctn">#{name}</div>"""
    delb = $ """<button class="icon delete delbtn">"""

    delb.click (ev) => @removeRitual(ev, name, elem)

    elem.append(delb)
    @catagories[parseInt(dot) - 1].append elem

  addRitual: (ev) =>
    @sele = getSelect @poss
    @ttip = new ToolTip(ev, @base, @tAdd, @tDel, @sele)

  removeRitual: (ev, name, cont) =>
    delete @values[name]
    cont.remove()
    update_calculated()

  tAdd: (ev) =>
    name   = @sele.val()
    ritual = system.rituals[name]

    if not ritual or @values[name]
      @sele.addClass("error")
    else
      @addHtml(name, ritual.dot)
      @values[name] = true
      @ttip.remove()

    update_calculated()

class Devotions extends Trait
  constructor: (@values, @base) ->
    super("Devotions")

    @poss = { }
    for name, _ of system.devotions
      @poss[the_flip(name)] = name

    @list = (name for name, _ of @values)
    for name in @list
      @vals.append @getHtml(name)

    @add.click @addDevotion

  getHtml: (name) =>
    cont = $ """<div class="delctn"><span>#{name}</span></div>"""
    delb = $ """<button class="icon delete delbtn">"""

    delb.click (ev) => @removeDevotion(ev, name, cont)

    cont.append(delb)
    cont

  addDevotion: (ev) =>
    @sele = getSelect @poss
    @ttip = new ToolTip(ev, @base, @tAdd, @tDel, @sele)

  removeDevotion: (ev, name, cont) =>
    delete @values[name]
    cont.remove()
    update_calculated()

  tAdd: (ev) =>
    name = @sele.val()

    if name
      @values[name] = true
      @vals.append @getHtml(name)
      @list.push(name)
      @ttip.remove()

    update_calculated()

alternates =
  merits      : (values, base) -> new      Merits(values, base)
  specialties : (values, base) -> new Specialties(values, base)
  disciplines : (values, base) -> new Disciplines(values, base)
  rituals     : (values, base) -> new     Rituals(values, base)
  devotions   : (values, base) -> new   Devotions(values, base)

################################################################################
### Auxiliary Traits ###########################################################
################################################################################

class AuxTrait
  constructor: (name, id) ->
    @html  = $("""<div class="auxiliarytrait" id="#{id}">""")
    @vals = $("""<div class="boxes">""")

    @html.append("""
    <div class="auxName">
      <span>#{name}</span>
    </div>""")

    @html.append @vals

class Health extends AuxTrait
  constructor: (@values, @base) ->
    super("Health", "health")

    @hboxes = [ ]
    for i in [0...@getHealth()]
      do (i) =>
        newBox = $("""<button class="icon hbox none"></button>""")
        
        newBox.click => @boxClick(i)
        
        @hboxes.push
          type: 0
          html: newBox
        
        @vals.append newBox
    
    @setBoxes()

    register_update "health", @
    
  getHealth: =>
    character.attributes.Stamina +
    character.size
  
  setBoxes: =>
    idx = 0
    
    set = (name, type) =>
      for i in [0...@values[name]]
        @hboxes[idx].type = type
        @hboxes[idx].html.toggleClass "none"
        @hboxes[idx].html.toggleClass  name
        idx += 1
    
    set("grevious" , 4)
    set("agrivated", 3)
    set("lethal"   , 2)
    set("bashing"  , 1)
  
  boxClick: (idx) =>
    box = @hboxes[idx]
    
    transfer = (from, to, type) =>
      box.html.toggleClass from
      box.html.toggleClass to
      box.type = type
      if from != "none" then @values[from]--
      if to   != "none" then @values[to]++
    
    if box.type == 0
      transfer("none", "bashing", 1)
    else if box.type == 1
      transfer("bashing", "lethal", 2)
    else if box.type == 2
      transfer("lethal", "agrivated", 3)
    else if box.type == 3
      transfer("agrivated", "grevious", 4)
    else if box.type == 4
      transfer("grevious", "none", 0)

class Will extends AuxTrait
  constructor: (@values, @base) ->
    super("Will Power", "will")
    
    for i in [0...@getWill()]
      do (i) =>
        newBox = $("""<button class="icon wbox"></button>""")
        newBox.click => @boxClick(newBox)
        
        if i < @values["will power"]
          newBox.addClass("available")
        else
          newBox.addClass("marked")
        
        @vals.append newBox
  
  getWill: =>
    @values.attributes.Resolve + @values.attributes.Composure
  
  boxClick: (box) =>
    if box.hasClass "available"
      @values["will power"]--
    else
      @values["will power"]++
    
    box.toggleClass "available"
    box.toggleClass "marked"

class Blood extends AuxTrait
  constructor: (@values, @base) ->
    super("Vitae", "blood")

    @upper = $("""<div>""")
    @lower = $("""<div>""")
    
    total = 0
    for i in [0...10]
      do (i) =>
        newBox = $("""<button class="icon bbox"></button>""")
        newBox.click => @bloodClick(newBox)
        
        if total < @getBlood()
          if total < @values.blood
            newBox.addClass "full"
          else
            newBox.addClass "empty"
        else
          newBox.addClass "blank"
        total += 1
        
        @upper.append newBox

    @vals.append @upper
    @vals.append @lower
        
    for i in [0...10]
      do (i) =>
        newBox = $("""<button class="icon bbox"></button>""")
        newBox.click => @bloodClick(newBox)
        
        if total < @getBlood()
          if total < @values.blood
            newBox.addClass "full"
          else
            newBox.addClass "empty"
        else
          newBox.addClass "blank"
        
        total += 1
        
        @lower.append newBox
  
  getBlood: ->
    character.potency + 9
  
  bloodClick: (box) =>
    if box.hasClass "full"
      @values.blood--
      box.toggleClass "full"
      box.toggleClass "empty"
    else if box.hasClass "empty"
      @values.blood++
      box.toggleClass "full"
      box.toggleClass "empty"

class Potency extends AuxTrait
  constructor: (@values) ->
    super("Blood Potency", "potency")
    
    @dots = new DotSet(@values.potency, (i) =>
      @values.potency = i
    , 6, false)
    
    @vals.append  @dots.html

class Morality extends AuxTrait
  constructor: (@values) ->
    super("Morality", "morality")
    @dots = [ ]

    if not @values.derangements
      @values.derangements = { }

    if not @values.morality or @values.morality == 0
      @values.morality = 7

    for i in [10..1]
      @vals.append @makeRow(i)

  makeRow: (idx) =>
    ret = $ """<div class="pair">"""
    dot = $ """<div class="dot">#{if idx == @values.morality then "●" else "○"}</div>"""
    ins = $ """<div class="insanity noText">1</div>"""

    @dots[idx] = dot

    derangements = @values.derangements[idx]
    if derangements and derangements.length != 0
      ins.html(derangements.join(", "))
      ins.removeClass("noText")

    dot.click =>
      @dots[@values.morality].html("○")
      @values.morality = idx
      dot.html("●")

    ins.click =>
      @insanityClick(idx, ins)

    ret.append dot
    ret.append ins

    ret

  insanityClick: (idx, res) =>
    other = $ """<div class="insanity"></div>"""
    input = $ """<input type="text">"""

    if @values.derangements[idx]
      input.val(@values.derangements[idx].join(", "))
    other.append input

    input.focusout (ev) =>
      other.remove()
      res.show()

    input.keyup (ev) =>
      if ev.keyCode is 13 or ev.keyCode is 27
        if ev.keyCode == 13
          @values.derangements[idx] = input.val().split(", ")
          if input.val().length == 0
            res.addClass "noText"
            res.html "1"
          else
            res.removeClass "noText"
            res.html @values.derangements[idx].join(", ")

        other.remove()
        res.show()

    res.after(other)
    res.hide()
    input.focus()

  joined: (idx) =>

class Calculated extends AuxTrait
  constructor: (@values) ->
    super("Information", "calculated")
    
    @elements = { }
    for name, calc of @keys
      [html, inner] = @get(name, calc())
      @elements[name] = inner
      @vals.append html
    
    @lock  = $("""<input type="checkbox">""")
    @label = $("""<div class="lock"><div class="key">Lock XP:</div></div>""")
    @label.append @lock
    @vals.append @label
    
    @lock.click (ev) =>
      click_xp_lock @lock.is(":checked"), @values
    
    add_updater @update
    
  get: (name, value) =>
    ret   = $("""<div class="pair">""")
    key   = $("""<div class="key">#{name}</div>""")
    value = if name == "Experience"
      res = $("""<div class="right value experience">#{value}</div>""")

      res.click (ev) =>
        @xp_click(name, res, ev)

      res
    else
      $("""<div class="right value">#{value}</div>""")

    
    ret.append key
    ret.append value

    [ret, value]

  xp_click: (name, res, ev) =>
    other = $ """<div class="right value">"""
    input = $ """<input type="text">"""

    input.val(@keys[name]())
    other.append input

    input.focusout (ev) =>
      res.show()
      other.remove()

    input.keyup (ev) =>
      if ev.keyCode is 13 or ev.keyCode is 27
        if ev.keyCode == 13 and not isNaN(input.val())
          @values.xp_diff -= parseInt(input.val()) - @keys[name]()

        res.html(@keys[name]())
        other.remove()
        res.show()

    res.after(other)
    res.hide()
    input.focus()

  keys: 
    Size       : -> character.size
    Defense    : -> Math.min(character.attributes.Wits, character.attributes.Dexterity)
    Armor      : -> 0

    Speed      : ->
      character.attributes.Strength + character.attributes.Dexterity + character.size + (
        if character.merits["Fleet of Foot"] then character.merits["Fleet of Foot"] else 0
      )
    
    Initiative : ->
      character.attributes.Dexterity + character.attributes.Composure + (
        if character.merits["Fast Reflexes"] then character.merits["Fast Reflexes"] else 0
      )
    
    Experience : ->
      calculate_xp(character)

  update: =>
    for name, eval of @keys
      @elements[name].html(eval())

################################################################################
### Controller #################################################################
################################################################################

class Traits
  constructor: (@values, @base, height) ->
    @html = $("""<div class="section traits">""")
    @head = $("""<div class="header">""")
    @sect = $("""<button class="icon enter setTraits"></button>""")
    
    @head.append """<span class="sectionName">Other Traits</span>"""
    @head.append @sect
    @html.append @head
    
    @sect.click (ev) => @setTraits(ev)
    
    @container = $("""<div class="body lower" style="height: #{height}">""")
    
    @othertraits = $("""<div class="scroll">""")
    
    @auxTraits = { }
    for trait in meta.alternateDisplay
      elem = alternates[trait](@values[trait], @base)
      @othertraits.append elem.html
      @auxTraits[trait] = elem
    
    @auxiliarytraits = $("""<div class="auxiliary">""")
    
    @health   = new     Health(@values.health)
    @will     = new       Will(@values)
    @blood    = new      Blood(@values)
    @potency  = new    Potency(@values)
    @morality = new   Morality(@values)
    @claced   = new Calculated(@values)
    
    @auxiliarytraits.append @health.html
    @auxiliarytraits.append @will.html
    @auxiliarytraits.append @blood.html
    @auxiliarytraits.append @potency.html
    @auxiliarytraits.append @morality.html
    @auxiliarytraits.append @claced.html
    
    @container.append @othertraits
    @container.append @auxiliarytraits
    @html.append @container
  
  setTraits: (ev) =>
    elements = [ ]
    @checks  = { }
    
    for name, func of alternates
      do (name, func) =>
        check = $("""<input type="checkbox" class="addCheckbox">""")
        label = $("""<span>#{name}</span>""")
        html  = $("""<div class="traitcheck">""")
        
        if $.inArray(name, meta.alternateDisplay) >= 0
          check.attr("checked", true)
        
        html.append label
        html.append check
        
        elements.push html
        @checks[name] = check
    @ttip = new ToolTip(ev, @base, @tAdd, @tDel, elements)

  setHeight: (height) =>
    @container.css("height", height)

  tAdd: (ev) =>
    @othertraits.empty()
    
    meta.alternateDisplay = [ ]
    for name, _ of alternates
      if @checks[name].is(":checked")
        meta.alternateDisplay.push name
        
        if !@auxTraits[name]
          if !@values[name]
            @values[name] = { } 
          @auxTraits[name] = alternates[name](@values[name], @base)
        
        @othertraits.append @auxTraits[name].html
    
    @ttip.remove()
  
  tDel: (ev) =>
    @ttip.remove()

class NWod
  constructor: ->
    @container = $("#nwod")
    @body      = $(window)

    @attributes = new Attributes(character.attributes)
    @container.append(@attributes.html)
    
    @skills = new Skills(character.skills)
    @container.append(@skills.html)
    
    @traits = new Traits(character, @container, @skills.height())
    @container.append(@traits.html)

    @body.resize (ev) =>
      @traits.setHeight(@skills.height())

push -> sheet = new NWod
