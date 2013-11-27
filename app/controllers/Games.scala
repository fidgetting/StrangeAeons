package controllers

import play.api._
import data._
import mvc._
import libs._
import json._
import Forms._
import Forms.tuple
import Play._

import json._
import anorm._
import concurrent._
import iteratee._

import models._
import views._

object Games extends Controller with Secured {

  def games(system: String) = withAuth { user => _ =>
    Ok(Json.toJson(Game.games(system, user) map { game =>
      Map[String, JsValue](
        "id"   -> Json.toJson(game.id.get),
        "name" -> Json.toJson(game.name))
    }))
  }
  
  def newGame = withAuth { user => _ =>
    Ok(html.nav.newgame(user))
  }

  def save(name: String) = withAuth { user => implicit request =>
    def gameDataForm = Form(
      tuple(
        "gameData"   -> text,
        "gameSystem" -> text
      )
    )

    gameDataForm.bindFromRequest.fold (
      { case with_error =>
        BadRequest(html.character.list(user, User.list(user)))
      },
      { case (data, system) =>
          Ok(html.nav.game(Game.insert(Game(
            NotAssigned,
            name,
            user.id.get,
            system,
            data), user), user))
      }
    )
  }
  
  def delete(id: Long) = isMaster(id) { _ => _ =>
    Game.delete(id)
    
    Application.Home
  }
  
  def add(game_id: Long, user_id: Long) = isMaster(game_id) { _ => _ =>
    Game.addUser(game_id, user_id)
    Ok
  }
  
  def remove(game_id: Long, user_id: Long) = isMaster(game_id) { _ => _ =>
    Ok(Json.obj("names" -> Game.removeUser(game_id, user_id).map { _.id.get }))
  }
  
  def characters(id: Long) = inGame(id) { _ => _ =>
    val char = Character(id)
    
    Ok(Json.obj("names" -> JsObject(
      for(c <- Game(char.game_id).characters if(c.name != char.name))
        yield c.name -> JsNumber(c.id.get)
    )))
  }
  
}