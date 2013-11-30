
class Navigator extends Backbone.View
  initialize: ->
    $(".picture")   .click @picture
    @el.children("li").each (i, game) ->
      new Game
        el: $(game)
    $('input[type=file]').change =>
      fd = new FormData(document.getElementById("fileinfo"))
      jsRoutes.controllers.Application.upload(@cid).ajax
        success: (data) => delay 1000, =>
          @tar.attr("src", data.url)
        error: (err) =>
        data: fd,
        processData: false,
        contentType: false
        
  picture: (ev) =>
    @tar = $(ev.target)
    @cid = @tar.attr("data-id")
    $('input[type=file]').trigger('click')

class Game extends Backbone.View
  events:
    "click    .toggle"          : "toggle"
    
  initialize: ->
    @id = @el.attr("data-game")
    
  toggle: (e) ->
    e.preventDefault()
    @el.toggleClass("closed")
    false
    

navigator = undefined
push -> navigator = new Navigator el: $("#games")
