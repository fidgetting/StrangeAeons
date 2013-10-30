package models

import play.api._
import db._
import libs._
import Play.current

import json._
import functional.syntax._

import anorm._
import SqlParser._

case class Note (
    id     : Pk[Long] = NotAssigned,
    user_id: Long,
    char_id: Long,
    content: String,
    public : Boolean) {
  
  def toJson(user: User) = {
    val owner = User(user_id)
    
    Json.obj(
      "id"      -> id.get,
      "user"    -> owner.name,
      "owner"   -> (owner.email == user.email),
      "content" -> content,
      "public"  -> public
    )
  }

}

object Note {
  
  def parse: RowParser[Note] = {
    get[Pk[Long]]("notes.id") ~
    get[Long]    ("notes.user_id") ~
    get[Long]    ("notes.char_id") ~
    get[String]  ("notes.content") ~
    get[Boolean] ("notes.public" ) map {
      case id ~ user_id ~ char_id ~ content ~ public =>
        Note(id, user_id, char_id, content, public)
    }
  }
  
  def list(user: User, char_id: Long): Seq[Note] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from notes
            left join users      on notes.user_id      = users.id
            left join characters on notes.char_id      = characters.id
            left join games      on characters.game_id = games.id
            where characters.id = {char_id} and (
              games.master = {user_id} or
              notes.user_id = {user_id} or
              notes.public = true
            )
        """
      ) on (
        'user_id -> user.id.get,
        'char_id -> char_id
      ) as (Note.parse *)
    }
  }
  
  def apply(id: Long): Note = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from notes
            where id = {id}
        """
      ).on(
        'id -> id
      ).as(Note.parse.single)
    }
  }
  
  
  def add(in: Note): Note = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into notes
            (user_id ,  char_id ,  content ,  public) values (
            {user_id}, {char_id}, {content}, {public}
          )
        """
      ).on(
        'user_id -> in.user_id,
        'char_id -> in.char_id,
        'content -> in.content,
        'public  -> in.public
      ).executeUpdate()
    }
    
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from notes
            order by notes.created desc limit 1
        """
      ).as(Note.parse.single)
    }
  }
  
  def update(id: Long, content: String, public: Boolean): Note = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update notes
            set content = {content}, public = {public}
            where id = {id}
        """
      ).on(
        'content -> content,
        'public  -> public,
        'id      -> id
      ).executeUpdate
    }
    
    Note(id)
  }
  
  def delete(id: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          delete from notes
            where id = {id}
        """
      ).on(
        'id -> id
      ).executeUpdate
    }
  }
  
  def isOwner(id: Long)(user: User): Boolean = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select count(notes.id) = 1 from notes
            left join users on notes.user_id = users.id
            where notes.id = {id} and users.id = {user};
        """
      ).on (
        'id   -> id,
        'user -> user.id.get
      ).as(scalar[Boolean].single)
    }
  }
  
}