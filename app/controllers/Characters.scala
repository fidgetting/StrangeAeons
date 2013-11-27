package controllers

import java.util.{Date}

import play.api._
import mvc._
import data._
import libs._

import Forms._
import Play._

import anorm._
import json._
import validation.ValidationError
import functional.syntax._

import models._
import views._

import scala.reflect.runtime.{universe => ru}

object Characters extends Controller with Secured {
  
  def images = 
    (for(str <- Play.getFile("public/images").list)
      yield (str, str)).toSeq
  
  // -- Actions
  
  def create = withAuth { user => implicit request =>
    Ok(html.character.create(user))
  }
  
  def display(id: Long) = withAuth { user => _ =>
    val character = Character(id)
    val game      = Game(character.game_id)
    val sys       = Game.system(game)
    
    if(Character.isViewable(id)(user)) {
      Ok(html.character.sheet(user, character, Option(game.system)))
    } else {
      Ok(html.character.sheet(user, character, None))
    }
  }

  def save(name: String, game_id: Long) = inGame(game_id) { user => implicit request =>
    def sForm = Form(
      tuple (
        "meta"   -> optional(text),
        "data"   -> optional(text),
        "stats"  -> optional(text),
        "note"   -> text
      )
    )

    sForm.bindFromRequest.fold(
      { case with_error =>
        BadRequest(html.character.list(user, User.list(user)))
      },
      { case (meta, data, stats, note) =>
        val nc = Character.insert(
          Character(NotAssigned, name, new Date(), user.id.get, game_id, "{}", None),
          meta  map (Json.parse(_)),
          data  map (Json.parse(_)),
          stats map (Json.parse(_)))
        Note.add(Note(NotAssigned, user.id.get, nc.id.get, note, false))

        Ok(nc.rest_json(user))
      }
    )
  }
  
  def update(character: Long, data: String) = ownsCharacter(character) { _ => _ =>
    Character.updateData(character, data)
    Ok
  }

  def character(id: Long) = canView(id) { _ => _ =>
    Ok(Character(id).json)
  }
  
  def system(name: String) = Action { implicit request =>
    Ok(Json.parse(Game.systemFile(name)))
  }
  
  def take(character: Long) = isMaster(Character(character).game_id) { user => _ =>
    Character.updateOwner(character, user.id.get)
    Ok
  }
  
  def delete(character: Long) = ownsCharacter(character) { _ => _ =>
    Character.delete(character)
    Ok(Json.obj(
        "url" -> routes.Application.index.toString
      )
    )
  }
  
  def link(from: Long, to: Long) = ownsCharacter(from) { _ => _ =>
    val char = Character(to)
    
    Character.link(from, to)
    
    Ok( Json.obj (
        "name" -> char.name,
        "url"  -> routes.Characters.display(to).toString
      )
    )
  }
  
  def duplicate(id: Long) = ownsCharacter(id) { _ => _ =>
    val char = Character.duplicate(Character(id))
    Character.link(id, char.id.get)
    Ok(Json.obj(
        "name" -> char.name,
        "url"  -> routes.Characters.display(char.id.get).toString
      )
    )
  }
  
  def setPublic(id: Long, value: Boolean) = ownsCharacter(id) { _ => _ =>
    Character.public(id, value)
    Ok(Json.obj("val" -> value))
  }
  
  def setVisible(id: Long, value: Boolean) = ownsCharacter(id) { _ => _ =>
    Character.visible(id, value)
    Ok(Json.obj("val" -> value))
  }
  
}