
class UserSet extends Backbone.View
  initialize: ->
    for user in @el.find(".user")
      new User el: $(user)

class User extends Backbone.View
  events:
    "click    .delete"          : "delete"
    "change   .permisions"      : "permisions"
  initialize: ->
    @el.click @show
    @addi = $(@el.find("#additional")[0])
    @id   = parseInt(@el.attr("data-id"))
  permisions: (ev) =>
    jsRoutes.controllers.Admin.permisions(@id, $(ev.target).val()).ajax
      success: (data) =>
      error: (err) =>
  show: (ev) =>
    if @addi.is(":visible")    
      @addi.slideUp()
    else
      @addi.slideDown()
  delete: (ev) =>
    jsRoutes.controllers.Admin.delete(@id).ajax
      success: (data) =>
        $(@el.parent()).remove()
      error: (err) =>

push -> new UserSet el: $("#userSet")
