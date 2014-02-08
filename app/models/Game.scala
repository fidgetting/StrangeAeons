package models

import scala.io.Source._

import play.api._
import db._
import libs._
import json._
import Play.current
import concurrent._

import anorm._
import SqlParser._
import Execution.Implicits._

import controllers._
import scala.concurrent.duration._
import scala.concurrent.Await

import fly.play.s3._

case class Game(
    id    : Pk[Long] = NotAssigned,
    name  : String,
    master: Long,
    system: String,
    s_data: String) extends Restful {
  
  lazy val data =
    Json.parse(s_data)

  def rest_json(getter: User) = Json.obj(
    "id"         -> id.get,
    "name"       -> name,
    "system"     -> system,
    "characters" -> (for(char <- Game.characters(this)) yield Json.obj(
      "id" -> char.id.get,
      "name" -> char.name
    ))
  )
}

case class AspectInfo(
    name : String,
    email: String,
    data : String) {
  
  lazy val json = Json.obj (
    "name"    -> name,
    "creator" -> email,
    "values"  -> Json.parse(data) \ "vals"
  )
  
}

object Game {
  
  def parse = {
    get[Pk[Long]]("games.id"    ) ~
    get[String]  ("games.name"  ) ~
    get[Long]    ("games.master") ~
    get[String]  ("games.system") ~
    get[String]  ("games.data"  ) map {
      case id ~ name ~ master ~ system ~ data =>
        Game(id, name, master, system, data)
    } 
  }
  
  def list(user: User): Seq[Game] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            left join gameAssociation on gameAssociation.game_id = games.id
            where gameAssociation.user_id = {user_id}
            order by name;
        """
      ).on(
        'user_id -> user.id
      ).as(Game.parse *)
    }
  }
  
  def insert(game: Game, user: User): Game = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into games
            (name ,  master ,  system ,  data) values (
            {name}, {master}, {system}, {data}
          )
        """
      ).on(
        'name   -> game.name,
        'master -> game.master,
        'system -> game.system,
        'data   -> game.s_data
      ).executeUpdate
    }
    
    val ng = DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            order by games.created desc limit 1
        """
      ).as(Game.parse.single)
    }
    
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into gameAssociation
            (game_id ,  user_id) values (
            {game_id}, {user_id}
          )
        """
      ).on(
        'game_id -> ng.id,
        'user_id -> user.id.get
      ).executeUpdate
    }
        
    ng
  }
  
  def delete(id: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          delete from games
            where id = {game_id}
        """
      ).on(
        'game_id -> id
      ).executeUpdate
    }
  }
  
  def addUser(game: Long, user: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into gameAssociation
            (game_id ,  user_id) values (
            {game_id}, {user_id}
          )
        """
      ).on(
        'game_id -> game,
        'user_id -> user
      ).executeUpdate
    }
  }
  
  def removeUser(game: Long, user: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          delete from gameassociation
            where game_id = {game_id} and user_id = {user_id}
        """
      ).on(
        'game_id -> game,
        'user_id -> user
      ).executeUpdate
    }
    
    val ret = DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            where game_id = {game_id} and user_id = {user_id}
        """
      ).on(
        'game_id -> game,
        'user_id -> user
      ).as(Character.parse *)
    }
    
    DB.withConnection { implicit connection =>
      SQL(
        """
          delete from characters
            where game_id = {game_id} and user_id = {user_id}
        """
      ).on(
        'game_id -> game,
        'user_id -> user
      ).executeUpdate
    }
    
    ret
  }

  def characters(game: Game): Seq[Character] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            left join characters on characters.game_id = games.id
            where games.id = {id}
            order by characters.name;
        """
      ).on(
        'id -> game.id.get
      ).as(Character.parse *)
    }
  }

  def characters(game: Game, user: User): Seq[Character] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            left join characters on characters.game_id = games.id
            where games.id = {game_id} and (
              characters.visible or
              characters.user_id = user_id
            )
            order by characters.name;
        """
      ).on(
        'game_id -> game.id.get,
        'user_id -> user.id.get
      ).as(Character.parse *)
    }
  }
  
  def apply(id: Long): Game =  {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            where id = {id};
        """
      ).on(
        'id -> id
      ).as(Game.parse.single)
    }
  }
  
  def apply(name: String): Seq[Game] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            where name = {name};
        """
      ).on(
        'name -> name
      ).as(Game.parse *)
    }
  }

  def apply(user: User): Seq[Game] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select games.* from games
            left join gameassociation on gameassociation.game_id = games.id
            where gameassociation.user_id = {id};
        """
      ).on(
        'id -> user.id.get
      ).as(Game.parse *)

    }
  }
  
  def id(gamename: String): Long = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select id from games
            where name = {gamename};
        """
      ) on (
        'gamename -> gamename
      ) as (scalar[Long].single)
    }
  }
  
  def games(system: String, user: User): Seq[Game] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            left join gameAssociation on gameAssociation.game_id = games.id
            where games.system = {system} and gameAssociation.user_id = {user_id};
        """
      ).on(
        'system  -> system,
        'user_id -> user.id.get
      ).as(Game.parse *)
    }
  }
  
  def exists(name: String): Boolean = {
    DB.withConnection { implicit connection =>
      (SQL(
        """
          select count(users.id) = 1 from games
            where name = {name}
        """
      ).on (
        'name -> name
      ).as (scalar[Boolean].single))
    }
  }

  def master(user: User): Seq[Game] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from games
            where master = {id};
        """
      ).on(
        'id -> user.id.get
      ).as(Game.parse *)
    }
  }
  
  def inGame(game_id: Long)(user: User): Boolean = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select count(id) = 1 from gameAssociation
            where game_id = {game_id} and user_id = {user_id}
        """
      ).on(
        'game_id -> game_id,
        'user_id -> user.id.get
      ).as(scalar[Boolean].single)
    }
  }
  
  def isMaster(id: Long)(user: User): Boolean = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select count(id) = 1 from games
            where games.id = {id} and master = {user_id}
        """
      ).on(
        'id      -> id,
        'user_id -> user.id.get
      ).as(scalar[Boolean].single)
    }
  }
  
  def system(name: String): JsValue = {
    val result = ((Application.storage get s"$name.json") map {
      case Right(BucketFile(name, contentType, content, acl, Some(headers))) =>
        Json.parse(content)

      case Left(error) =>
        Json.obj()
    })

    Await.result(result, 60.seconds)
  }

  def system(game: Game): JsValue =
    system(game.system)
  
  def starting(id: Long): JsValue =
    system(Game(id)) \ "Starting"
  
  def aspect = {
    get[String]("aspects.name") ~
    get[String]("users.email" ) ~
    get[String]("aspects.data") map {
      case name ~ email ~ data =>
        AspectInfo(name, email, data)
    }
  }
  
  def aspects = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from aspects
            left join users on aspects.user_id = users.id
        """
      ).as(Game.aspect *)
    }
  }
  
  def saveAspect(name: String, data: String, user: User) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into aspects
            (user_id ,  name ,  data) values (
            {user_id}, {name}, {data}
          )
        """
      ).on(
        'user_id -> user.id.get,
        'name    -> name,
        'data    -> data
      ).executeUpdate
    }
  }
  
}
