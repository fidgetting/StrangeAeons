package controllers

import play.api._
import mvc._
import libs._

import models._
import views._

object Admin extends Controller with Secured  {
  
  def permisions(id: Long, value: Int) = isAdmin { _ => _ =>
    User.permision(User(id), value)
    Ok
  }
  
  def users() = isAdmin { user => _ =>
    Ok(html.admin.users(user, User.not(user)))
  }
  
  def delete(id: Long) = isAdmin { _ => _ =>
    User.delete(id)
    Ok
  }

  def profile() = withAuth { user => implicit request =>
    Ok(html.admin.profile(user, Auth.changeForm))
  }
  
}