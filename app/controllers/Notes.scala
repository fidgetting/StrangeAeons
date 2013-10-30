package controllers

import play.api._
import mvc._
import libs._

import json._
import anorm._

import models._
import views._

object Notes extends Controller with Secured {
  
  def list(char_id: Long) = withAuth { user => _ =>
    Ok(Json.obj("notes" -> (Note.list(user, char_id) map (_.toJson(user)))))
  }
  
  def save(char: Long, content: String, public: Boolean) = withAuth { user => _ =>
    Ok(Note.add(Note(NotAssigned, user.id.get, char, content, public)).toJson(user))
  }
  
  def update(id: Long, content: String, public: Boolean) = ownsNote(id) { user => _ =>
    Ok(Note.update(id, content, public).toJson(user))
  }
  
  def delete(id: Long) = ownsNote(id) { _ => _ =>
    Note.delete(id)
    Ok
  }
  
}