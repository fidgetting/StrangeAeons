
check_gmail = /(.+)@gmail\.com/g
check_yahoo = /(.+)@yahoo\.com/g
check_email = /(.+)@(.+)/g

class Login
  constructor: ->
    @html     = $ "#form"
    @email    = $ "#email"
    @password = $ "#password"
    @buttons  = $ "#buttons"

    @email.on "input", (ev) => @emailClicked(ev)

    @hideAll()

  emailClicked: (ev) =>
    @update = Date.now()
    delay 500, @checkOpenid

  checkOpenid: =>
    if Date.now() - @update >= 500
      @hideAll()
      jsRoutes.controllers.Auth.taken(@email.val()).ajax
        success: (data) =>
          if data.taken
            @addPassword()
            @addLogin()
          else if @email.val().match(check_email)
            @addSignup()
      if @email.val().match(check_gmail)
        @addOpenid(gmail_url)
      else if @email.val().match(check_yahoo)
        @addOpenid(yahoo_url)

  hideAll: =>
    @password.hide()

    if @openid then @openid.remove()
    if @signup then @signup.remove()
    if @login  then @login .remove()

  addPassword: =>
    @password.show()

  addOpenid: (url) =>
    @openid = $ "<div><a class='btn primary' href='#{url}'>OpenID</a></div>"
    @buttons.append(@openid)

  addSignup: =>
    @signup = $ "<div><a class='btn primary' href='#{singup_url}'>Sign Up</a></div>"
    @buttons.append(@signup)

  addLogin: =>
    @login = $ "<div><button type='submit' class='btn primary'>Login</button></div>"
    @buttons.append(@login)

push -> new Login

