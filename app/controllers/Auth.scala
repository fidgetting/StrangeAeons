package controllers

import play.api._
import mvc._
import data._
import libs._
import concurrent._
import openid._
import Forms._

import Execution.Implicits._

import anorm._

import views._
import models._
import play.api.libs.json.Json

object Auth extends Controller with Secured {
  
  val loginForm = Form(
    tuple(
      "email"    -> text,
      "password" -> text
    ) verifying ("Invalid username or password", _ match {
      case (email, password) => check(email, password)
    })
  )

  val signupForm = Form(
    tuple(
      "email"    -> text,
      "name"     -> text,
      "password" -> text,
      "confirm"  -> text
    )
  )

  val changeForm = Form(
    tuple(
      "email"    -> text,
      "current"  -> text,
      "password" -> text,
      "confirm"  -> text
    )
  )
  
  def check(email: String, password: String) = {
    User.validate(email, password)
  }
  
  def login = Action { implicit request =>
    Ok(html.login(loginForm))
  }
  
  def authenticate = Action { implicit request =>
    loginForm.bindFromRequest.fold(
      formWithErrors => BadRequest(html.login(formWithErrors)),
      user => Redirect(routes.Application.index).withSession(Security.username -> user._1)
    )
  }
  
  def newlogin = {
    Redirect(routes.Auth.login).withNewSession
  }
  
  def logout = Action {
    newlogin.flashing(
      "success" -> "You are now logged out."
    )
  }

  def signup = Action { implicit request =>
    Ok(html.signup(signupForm))
  }

  def taken(possible: String) = Action { _ =>
    Ok(Json.obj("taken" -> User.exists(possible)))
  }

  def register = Action { implicit request =>
    signupForm.bindFromRequest.fold(
      { case with_error =>
        BadRequest(html.signup(with_error))
      },
      { case (email, name, pass, conf) =>
        if(User.exists(email))
          Redirect(routes.Auth.signup).flashing("error" -> "Email is taken")
        else if(pass != conf)
          Redirect(routes.Auth.signup).flashing("error" -> "Passwords Don't Match")
        else {
          User.sendValidation(name, email)
          User.insert(email, name, pass, false)
          Redirect(routes.Auth.login).flashing("success" ->
            "An email has been sent so that we can verify your account.")
        }
      }
    )
  }

  def validate(hash: String) = Action { implicit request =>
    Redirect(routes.Auth.login) flashing (if(User.userCheckin(hash)) {
      "success" -> "You are now ready to login"
    } else {
      "error"   -> "Unable to validate user"
    })
  }

  lazy val openid_params = Map(
    "google" -> ("https://www.google.com/accounts/o8/id", Seq(
      "email"     -> "http://axschema.org/contact/email",
      "firstname" -> "http://axschema.org/namePerson/first",
      "lastname"  -> "http://axschema.org/namePerson/last"
    )),

    "yahoo" -> ("https://me.yahoo.com",                  Seq(
      "email"      -> "http://axschema.org/contact/email",
      "namePerson" -> "http://axschema.org/namePerson"
    ))
  )

  lazy val openid_url_parse = """https:(.+)id=(.+)""".r

  def openid(service: String) = Action { implicit request =>
    val (url, params) = openid_params.getOrElse(service, ("unknown" -> Seq()))
    AsyncResult(OpenID.redirectURL(url, routes.Auth.openidValidate.absoluteURL(), params)
      .map( url => Redirect(url))
      .recover { case e => Redirect(routes.Auth.login).flashing("error" -> s"$service not fully implemented") }
    )
  }

  def openidValidate = Action { implicit request =>
    AsyncResult(OpenID.verifiedId.map {
      case UserInfo(id, attr) =>
        val email = attr("email")
        val name =
          if(attr.contains("firstname")) {
            attr("firstname") + " " + attr("lastname")
          } else {
            attr("fullname")
          }

        if(User.exists(email)) {
          Redirect(routes.Application.index).withSession(Security.username -> email)
        } else {
          User.insert(email, name, "", true)
          User.setValidated(User(email))
          Redirect(routes.Application.index).withSession(Security.username -> email)
        }

      case _ => Redirect(routes.Auth.login).flashing("error" -> "Unable to login using OpenID")
    }.recover { case _ => Redirect(routes.Auth.login).flashing("error" -> "Unable to login using OpenID") })
  }

  /* ************************************************************** */
  /* *** Change password / openid ********************************* */
  /* ************************************************************** */

  def change = withAuth { user => implicit request =>
    changeForm.bindFromRequest.fold(
      { case with_error =>
        BadRequest(html.admin.profile(user, with_error))
      },
      { case (email, current, password, confirm) =>
        if(!(current == "" && user.openid) && !check(email, current)) {
          Redirect(routes.Admin.profile).flashing("error" -> "Invalid Password")
        } else if(password.length == 0 || password != confirm) {
          Redirect(routes.Admin.profile).flashing("error" -> "Password don't Match")
        } else {
          User.changePassword(user, password)
          Redirect(routes.Admin.profile).flashing("success" -> "Password Changed")
        }
      }
    )
  }

  def openid_switch(service: String) = withAuth { user => implicit request =>
    val (url, params) = openid_params.getOrElse(service, ("unknown" -> Seq()))
    AsyncResult(OpenID.redirectURL(url, routes.Auth.openidValidate_switch.absoluteURL(), params)
      .map( url => Redirect(url))
      .recover { case e => Redirect(routes.Auth.login).flashing("error" -> s"$service not fully implemented") }
    )
  }

  def openidValidate_switch = withAuth { user => implicit request =>
    AsyncResult(OpenID.verifiedId.map {
      case UserInfo(id, attr) =>
        val email = attr("email")

        if(user.email == email) {
          User.changeOpenid(user, id)
          Redirect(routes.Admin.profile).flashing("success" -> "OpenID login set")
        } else {
          Redirect(routes.Admin.profile).flashing("error" -> s"Emails do not match: ${user.email} != $email")
        }

      case _ => Redirect(routes.Admin.profile).flashing("error" -> "Error setting OpenID")
    }.recover { case e => println(e); Redirect(routes.Admin.profile).flashing("error" -> "Unable to get OpenID") })
  }
  
}

trait Secured {
  
  def username(request: RequestHeader) =
    request.session.get("username")
  
  def onUnauthorized(request: RequestHeader) = {
    Results.Redirect(routes.Auth.login)
  }

  def withAuth[A](bodyParser: BodyParser[A])(f: => User => Request[A] => Result): EssentialAction = {
    Security.Authenticated(username, onUnauthorized) { user =>
      if(!User.exists(user)) {
        Action(Auth.newlogin.flashing("error" -> s"Invalid username: $user"))
      }  else {
        Action(bodyParser)(request => f(User(user))(request))
      }
    }
  }

  def withAuth(f: User => Request[AnyContent] => Result): EssentialAction = {
    withAuth(BodyParsers.parse.anyContent)(f)
  }

  def checkCondition[A]
      (bodyParser: BodyParser[A])
      (check: User => Boolean)
      (f: User => Request[A] => Result) = withAuth[A](bodyParser) { user => request =>
    if(check(user)) {
      f(user)(request)
    } else {
      Results.Forbidden
    }
  }

  def checkCondition
      (check: User => Boolean)
      (f: User => Request[AnyContent] => Result) = withAuth { user => request =>
    if(check(user)) {
      f(user)(request)
    } else {
      Results.Forbidden
    }
  }
  
  def isGm    = checkCondition(_.isGm)_
  def isAdmin = checkCondition(_.isAdmin)_
  
  def ownsCharacter(id: Long) = checkCondition(Character.isOwner   (id)_)_
  def canView      (id: Long) = checkCondition(Character.isViewable(id)_)_
  def canUpdate    (id: Long) = checkCondition(Character.canUpdate (id)_)_
  def ownsNote     (id: Long) = checkCondition(Note.isOwner        (id)_)_
  def inGame       (id: Long) = checkCondition(Game.inGame         (id)_)_
  def isMaster     (id: Long) = checkCondition(Game.isMaster       (id)_)_

  def canUpload[A](bodyParser: BodyParser[A])(id: Long) = checkCondition(bodyParser)(Character.canSetPic (id)_)_
  
}

