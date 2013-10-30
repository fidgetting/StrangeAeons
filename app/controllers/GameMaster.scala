package controllers

import play.api._
import mvc._
import data._
import libs._
import Forms._
import Play._

import anorm._
import json._
import concurrent._

import models._
import views._

import Execution.Implicits._

import fly.play.s3._
import scala.concurrent.duration._
import scala.concurrent._
import scala.io.Source._

object GameMaster extends Controller with Secured {
  
  def fromMutable[A, B](in:   collection.mutable.Map[A, B]) = collection.immutable.Map(in.toSeq: _*)
  def   toMutable[A, B](in: collection.immutable.Map[A, B]) =   collection.mutable.Map(in.toSeq: _*)
  
  lazy val jsonData = ((Application.storage get "names.json").map {
    case Left(error) =>
      println(error)
      Json.parse("""{"names":{}, "adjectives":[]}""")
    case Right(BucketFile(_, _, content, _, _)) =>
      Json.parse(fromBytes(content).mkString)
  })
  
  // -- Actions
  
  def data = isGm { _ => _ =>
    Ok(Await.result(jsonData, 60.seconds))
  }
  
  def npcui(game: String) = isGm { _ => _ =>
    Ok(html.gm.npc())
  }
  
  def aspects = isGm { _ => _ =>
    Ok(Json.arr(Game.aspects map { _.json }))
  }
  
  def aspect(name: String, values: String) = isGm { user => _ =>
    Game.saveAspect(name, values, user)
    
    Ok(Json.obj(
      "name" -> name,
      "aspect" -> Json.obj(
        "creator" -> user.email,
        "values" -> (Json.parse(values) \ "vals")
      )
    ))
  }
}
