package controllers

import play.api._
import mvc._
import libs._
import json._

import anorm._

import models._
import java.io._

trait Restful {
  def id: Pk[Long]
  def rest_json(getter: User): JsObject
}

object Restful extends Controller with Secured {

  def wrap(getter: User, obj: Restful): JsValue = Json.obj(
    "code"    -> 0,
    "success" -> Json.obj(
      "id"      -> obj.id.get,
      "body"    -> obj.rest_json(getter)
    )
  )

  def wrap(getter: User, objs: Seq[Restful]): JsValue = Json.obj(
    "code" -> 0,
    "success" -> objs.map(_.rest_json(getter))
  )

  def error(code: Long, msg: String): JsObject = Json.obj(
    "code" -> code,
    "error" ->  msg
  )

  val starting_regex = """(\w+):(.+)""".r

  def get(Type: String, id_in: Option[Long], name_in: Option[String]) = withAuth { user => implicit request =>
    Ok(try {
      (Type, id_in, name_in) match {
        case ("User",      Some(id), None) => wrap(user, User     (id))
        case ("Game",      Some(id), None) => wrap(user, Game     (id))
        case ("Character", Some(id), None) => wrap(user, Character(id))

        case ("User",      None, Some(name)) => wrap(user, User     (name))
        case ("Game",      None, Some(name)) => wrap(user, Game     (name))
        case ("Character", None, Some(name)) => wrap(user, Character(name))

        case ("System",    None, Some(starting_regex(name, sub))) =>
          Json.obj("code" -> 0, "success" -> (sub.split(":") foldLeft (Game system name))
            { case (curr, next) => curr \ next })
        case ("System",    None, Some(name)) =>
          Json.obj("code" -> 0, "success" -> (Game system name))

        case _ => error(2, s"Invalid type combination: ($Type, $id_in, $name_in)")
      }
    } catch {
      case e : FileNotFoundException => error(3, s"System(${name_in.get}) not found")
      case e : RuntimeException      => error(4, s"$Type(${(id_in, name_in) match {
        case (Some(in),  None)  => s"id = $in"
        case (None, Some(name)) => s"name = $name"
        case _                  => "???" }}) not found")
      case e : Throwable        => error(1, e.toString)
    })
  }

}
