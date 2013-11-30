
################################################################################
### Utility ####################################################################
################################################################################

getNote = (note) -> $($.parseHTML("
  <div>
    <div class=\"box note #{if note["public"] then "public" else "private"}\">
      <span>User: #{note.user}</span>
      #{ if note.owner then "
        <div class=\"topright\">
          <button class=\"icon write\"></button>
          <button class=\"icon delete\"></button>
        </div>" else "" }
      <div class=\"inner\"><pre>#{note.content}</pre></div>
    </div>
  </div>
  "))[1]

getEdit = (note) -> $($.parseHTML("
  <div>
    <div class=\"box notecreate\">
      <div class=\"topright\">
        <button class=\"icon enter\"></button>
        <button class=\"icon delete\"></button>
      </div>
      <span>Public:<input type=\"checkbox\" class=\"public\" #{if note["public"] then "checked"}>
      </span>
      <textarea>#{note.content}</textarea>
    </div>
  </div>
  "))[1]

getAssociation = (data) -> $($.parseHTML("
  <a class=\"association\" href=\"#{data.url}\">#{data.name}</a></br>
  "))[1]

character_id = 0

################################################################################
################################################################################
################################################################################

class Control extends Backbone.View
  events:
    "click    .setVisible"      : "setVisible"
    "click    .setPublic"       : "setPublic"
    "click    .delete"          : "delete"
  
  initialize: ->
    @Visible = $(".setVisible")
    @Public  = $(".setPublic")
    
  setVisible: (ev) ->
    jsRoutes.controllers.Characters.setVisible(character_id, @Visible.is(":checked")).ajax
      success: (data) =>
      error: (err) =>
  
  setPublic: (ev) ->
    jsRoutes.controllers.Characters.setPublic(character_id, @Public.is(":checked")).ajax
      success: (data) =>
      error: (err) =>
  
  delete: (ev) ->
    if(confirm("Delete this character?"))
      jsRoutes.controllers.Characters.delete(character_id).ajax
        success: (data) =>
          window.location.href = data.url
        error: (err) =>

################################################################################
################################################################################
################################################################################

class NoteSet extends Backbone.View
  initialize: ->
    $("#newnote").click @addNote
    @set  = $("#noteSet")
    character_id = parseInt(@el.attr("data-character"))
    jsRoutes.controllers.Notes.list(character_id).ajax
      success: (data) =>
        for note in data.notes
          html = $(getNote(note))
          @set.append(html)
          new Note
            el  : html
            note: note
            set : @set
      error: (err) ->
    $("#c_save").click =>
      data = meta: meta, Character: character, data: npcdata
      saveClick()
      jsRoutes.controllers.Characters.update(character_id, JSON.stringify(data)).ajax
        success: (data) => saveFinish()
        error: (err) =>
  addNote: (ev) =>
    note = { "public": true, "content": "" }
    html = $(getEdit(note))
    html.hide()
    @set.append(html)
    html.slideDown()
    new EditNote
      el  : html
      note: note
      set : @set
      base: undefined

class Note extends Backbone.View
  events:
    "click    .write"           : "write"
    "click    .delete"          : "delete"
  initialize: (pass) ->
    @note = pass.note
    @set  = pass.set
  write: (ev) =>
    html = $(getEdit(@note))
    html.hide()
    @el.after(html)
    @el.slideUp()
    html.slideDown()
    new EditNote
      el  : html
      note: @note
      set : @set
      base: this
  delete: (ev) =>
    if confirm("Delete note?")
      jsRoutes.controllers.Notes.delete(@note.id).ajax
        success: (data) =>
          @el.slideUp => @el.remove()
        error: (err) =>
          # TODO: Deal with

class EditNote extends Backbone.View
  events:
    "click    .enter"           : "enter"
    "click    .delete"          : "delete"
  initialize: (pass) =>
    @base   = pass.base
    @note   = pass.note
    @set    = pass.set
    @pub_in = $(@el.find("input")[0])
    @txt_in = $(@el.find("textarea")[0])
    @txt    = @txt_in.val()
    @pub    = @pub_in.is(":checked")
  enter: (ev) =>
    @cover = new Cover(@el)
    newText = @txt_in.val()
    if (newText == @text and @pub_in.is(":checked") == @pub) or newText == ""
      return @delete(ev)
    oper = (text, pub) =>
      if @base
        jsRoutes.controllers.Notes.update(@note.id, text, pub)
      else
        jsRoutes.controllers.Notes.save(character_id, text, pub)
    oper(@txt_in.val(), @pub_in.is(":checked")).ajax
      success: (note) =>
        if @base
          @base.el.remove()
        html = $(getNote(note))
        html.hide()
        @el.after(html)
        @base = new Note
          el  : html
          note: note
          set : @set
        @delete(ev)
      error: (err) =>
  delete: (ev) =>
    if @cover
      @cover.clear()
    if @base
      @base.el.slideDown()
    @el.slideUp =>
      @el.remove()

################################################################################
################################################################################
################################################################################

class DataSet
  constructor: ->
    @html = $("#characterData")
    @add  = $("#newdata")
    @data = [ ]

    names = (name for name, _ of npcdata).sort()
    for name in names
      @addDatum(name, npcdata[name])

    @add.click @addDialog

  addDatum: (name, value) =>
    nd = new Datum(name, value)

    @data.push nd
    @html.append nd.html

  addDialog: (ev) =>
    new DataDialog(@, true)

  append: (dialog) =>
    @html.append(dialog.html)

  remove: (dialog) =>
    dialog.html.remove()

class Datum
  constructor: (@name, @value) ->
    @html = $ """<div class="dataentry datawidget">"""
    @delb = $ """<button class="icon delete delbtn"></button>"""

    @html.append """<span class="dataname" >#{@name}</span> """
    @html.append """<span class="datavalue">#{@value}</span>"""
    @html.append @delb

    @html.click @alter
    @delb.click @deldatum

  alter: (ev) =>
    new DataDialog(@, false, @name, @value)

  append: (dialog) =>
    @html.after(dialog.html)
    @html.hide()

  remove: (dialog) =>
    dialog.html.remove()
    @html.show()

  deldatum: (ev) =>
    delete npcdata[@name]
    @html.remove()

class DataDialog
  constructor: (@base, @add, @name = "", @value = "") ->
    @html    = $ """<div class="dataadd">"""
    @namein  = $ """<input type="text" class="datain" value="#{@name}" >"""
    @valuein = $ """<input type="text" class="datain" value="#{@value}">"""

    @html.focusout (ev) =>
      @focus = false
      delay(50, => if !@focus then @remove(ev))
    @html.focusin (ev) =>
      @focus = true
    @html.keyup (ev) =>
      if ev.keyCode == 13
        @save(ev)
      else if ev.keyCode == 27
        @remove(ev)

    @html.append @namein
    @html.append @valuein

    @base.append @
    @namein.focus()

  save: (ev) =>
    if @namein.val() and @valuein.val()
      npcdata[@namein.val()] = @valuein.val()
      if @add
        @base.addDatum(@namein.val(), @valuein.val())

    @remove(ev)

  remove: (ev) =>
    @base.remove(@)

################################################################################
################################################################################
################################################################################

class LinkSet extends Backbone.View
  initialize: (pass) ->
    $("#newlink").click   @duplicate
    $("#duplicate").click @newlink
    @set = $("#linkSet")
    
  newlink: (ev) =>
    jsRoutes.controllers.Games.characters(character_id).ajax
      success: (data) =>
        select = getSelect(name for name, id of data.names)
        html = Tooltip(ev, true, select)
        @el.append(html)
        new LinkSelect
          el    : html
          select: select
          names : data.names
          set   : @set
      error: (err) =>
    
  duplicate: (ev) =>
    jsRoutes.controllers.Characters.duplicate(character_id).ajax
      success: (data) =>
        @set.append(getAssociation data)
      error: (err) =>

class LinkSelect extends Backbone.View
  events:
    "click    .enter"           : "enter"
    "click    .delete"          : "delete"
  
  initialize: (pass) ->
    @select = pass.select
    @names  = pass.names
    @set    = pass.set
  
  enter: (ev) =>
    if @names[@select.val()]
      jsRoutes.controllers.Characters.link(character_id, @names[@select.val()]).ajax
        success: (data) =>
          @set.append(getAssociation data)
        error: (err) =>

    @delete(ev)
  
  delete: (ev) =>
    @el.remove()
    
    
push -> new Control el: $("#control")
push -> new DataSet el: $("#dataSet")
push -> new NoteSet el: $("#noteSet")
push -> new LinkSet el: $("#linkSet")
