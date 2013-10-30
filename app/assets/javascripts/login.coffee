
class Signup extends Backbone.View
  initialize: ->
    @update = Date.now()
    @email = $("#email")
    @pass  = $("#password")
    @conf  = $("#confirm")
    
    @email.keyup (ev) =>
      if @email.is(":invalid")
        @email.addClass("invalid")
      else
        @email.removeClass("invalid")
      @update = Date.now()
      delay 500, @checkEmail
    
    @conf.keyup (ev) =>
      @checkPassword()
  
  checkEmail: =>
    if (Date.now() - @update) >= 500
      jsRoutes.controllers.Application.taken(@email.val()).ajax
        success: (data) =>
          if data.taken or @email.is(":invalid")
            @email.addClass("invalid")
          else
            @email.removeClass("invalid")
        error: (err) =>
  
  checkPassword: =>
    if @pass.val() != @conf.val()
      @conf.addClass("invalid")
      @pass.addClass("invalid")
    else
      @conf.removeClass("invalid")
      @pass.removeClass("invalid")

push -> new Signup el: $("#login")
