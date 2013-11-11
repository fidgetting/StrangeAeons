package models

import java.util.{Date}

import play.api._
import db._
import libs._
import Play.current
import json._

import anorm._
import SqlParser._

import controllers._

case class Character(
    id      : Pk[Long],
    name    : String,
    created : Date,
    user_id : Long,
    game_id : Long,
    data    : String,
    _picture: Option[String],
    public  : Boolean = false,
    visible : Boolean = true) extends Restful {

  def picture = _picture.getOrElse("nonPerson.png")
  
  lazy val json = Json.parse(data)
  lazy val stat = json \ "Character"
  lazy val meta = json \ "meta"
  lazy val info = json \ "data"
  
  lazy val minName = name.replace(" ", "")

  lazy val user = User(user_id)
  lazy val game = Game(game_id)

  def rest_json(getter: User) = Json.obj(
    "id"      -> id.get,
    "owned"   -> (getter == user),
    "master"  -> (getter.id == game.master),
    "name"    -> Json.obj(
      "name"    -> name,
      "link"    -> routes.Characters.display(id.get).toString),
    "user"    -> Json.obj(
      "name"    -> user.name,
      "link"    -> routes.Application.user(user.name).toString,
      "id"      -> user.id.get),
    "game"    -> Json.obj(
      "name"    -> game.name,
      "link"    -> routes.Application.game(game.name).toString,
      "id"      -> game.id.get),
    "picture" -> imgUrl,
    "data"    -> json)

  def formatedDate =
    Character.dateFormat.format(created)
  
  def skills(idx: Int) = {
    val seq = (stat \ "skills")(idx).as[Seq[String]]
    
    for(idx <- 0 until 5) yield
      if(idx < seq.size) Option(seq(idx)) else None
  }
  
  def imgUrl = controllers.Application.storage.url(picture, 100)
  
}

object Character {
  
  def nonUrl =
    controllers.Application.storage.url("nonPerson.png", 100)
  
  def parse: RowParser[Character] = {
    get[Pk[Long]]      ("characters.id"     ) ~
    get[String]        ("characters.name"   ) ~
    get[Date]          ("characters.created") ~
    get[Long]          ("characters.user_id") ~
    get[Long]          ("characters.game_id") ~
    get[String]        ("characters.data"   ) ~
    get[Option[String]]("characters.picture") ~
    get[Boolean]       ("characters.public" ) ~
    get[Boolean]       ("characters.visible") map {
      case id ~ name ~ created ~ user_id ~ game_id ~ data ~ picture ~ public ~ visible =>
        Character(id, name, created, user_id, game_id, data, picture, public, visible)
    }
  }
  
  def list(filter: String): CharacterSet =
    list(filter, filter, filter)
  
  def list(user_filter: String, game_filter: String, character_filter: String): CharacterSet = {
    DB.withConnection { implicit connection =>
      CharacterSet(SQL(
        """
          select * from characters
            left join users on characters.user_id = users.id
            left join games on characters.game_id = games.id
            where (
              users.name      like {user_filter} or
              games.name      like {game_filter} or
              characters.name like {character_filter}) and
              characters.visible
            order by characters.name
        """
      ).on(
        'user_filter      -> user_filter,
        'game_filter      -> game_filter,
        'character_filter -> character_filter
      ).as(User.parseAll *))
    }
  }

  def list(user: User): Seq[Character] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            where user_id = {user};
        """
      ).on(
        'user -> user.id
      ).as(Character.parse *)
    }
  }
  
  def apply(id: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            where id = {id}
        """
      ).on(
        'id -> id
      ).as(Character.parse.single)
    }
  }
  
  def apply(user: User) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            where user_id = {id}
        """
      ).on(
        'id -> user.id.get
      ).as(Character.parse *)
    }
  }

  def apply(name: String) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            where name = {name};
        """
      ).on(
        'name -> name
      ).as(Character.parse.single)
    }
  }
  
  def insert(character: Character,
             min: Option[JsValue],
             din: Option[JsValue],
             sin: Option[JsValue]): Character = {
    lazy val starting = Game.starting(character.game_id)
    lazy val meta     = min.getOrElse(starting \ "meta")
    lazy val data     = din.getOrElse(Json.obj())
    lazy val stats    = sin.getOrElse(starting \ "Character")
    val info = Json.obj(
      "meta"      -> meta,
      "data"      -> data,
      "Character" -> stats)

    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into characters
            (name ,  user_id ,  game_id ,  data ,  picture ) values (
            {name}, {user_id}, {game_id}, {info}, {picture}
          )
        """
      ).on(
        'name    -> character.name,
        'created -> character.created,
        'user_id -> character.user_id,
        'game_id -> character.game_id,
        'info    -> Json.stringify(info),
        'picture -> character.picture
      ).executeUpdate
    }
    
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            order by characters.created desc limit 1
        """
      ).as(Character.parse.single)
    }
  }
  
  def updateData(id: Long, data: String) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update characters
            set data = {data}
            where id = {id} 
        """
      ).on(
        'id   -> id,
        'data -> data
      ).executeUpdate
    }
  }
  
  def updatePicture(id: Long, picture: String) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update characters
            set picture = {picture}
            where id = {id} 
        """
      ).on(
        'id      -> id,
        'picture -> picture
      ).executeUpdate
    }
  }
  
  def updateOwner(id: Long, user: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update characters
            set user_id = {user}
            where id = {id} 
        """
      ).on(
        'id   -> id,
        'user -> user
      ).executeUpdate
    }
  }
  
  def delete(id: Long) = {
    Character(id).data map (jFile =>
      Play.getFile("private/characters/" + jFile).delete)
    
    DB.withConnection {
      implicit connection =>
      SQL(
        """
          delete from notes
            where char_id = {id}
        """
      ).on(
        'id -> id
      ).executeUpdate
    }
    
    DB.withConnection { implicit connection =>
      SQL(
        """
          delete from characters
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
          select count(characters.id) = 1 from characters
            left join users on characters.user_id = users.id
            where characters.id = {id} and users.id = {user};
        """
      ).on (
        'id   -> id,
        'user -> user.id.get
      ).as(scalar[Boolean].single)
    }
  }
  
  def isViewable(entity: Long)(user: User): Boolean = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select count(characters.id) = 1 from characters
            left join users on characters.user_id = users.id
            left join games on characters.game_id = games.id
            where characters.id = {entity} and (
              games.master = {user} or
              characters.user_id = {user} or
              characters.public = true
            )
        """
      ).on (
        'entity -> entity,
        'user   -> user.id.get
      ).as(scalar[Boolean].single)
    }
  }

  def canSetPic(entity: Long)(user: User): Boolean = {
    true
  }
  
  def isNpc(id: Long): Boolean = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select count(characters.id) = 1 from characters
            left join games on characters.game_id = games.id
            where characters.id = {id} and characters.user_id = games.master;
            
        """
      ).on (
        'id -> id
      ).as(scalar[Boolean].single)
    }
  }
  
  def link(from: Long, to: Long) = {
    if(!areLinked(from, to)) {
      DB.withConnection { implicit connection =>
        SQL(
          """
            insert into characterassociation
              (base ,  link ) values (
              {a}   , {b}
            );
            
            insert into characterassociation
              (base ,  link ) values (
              {b}   , {a}
            );
          """
        ).on(
          'a -> from,
          'b -> to
        ).executeUpdate()
      }
    }
  }
  
  def areLinked(from: Long, to: Long): Boolean = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select count(id) = 1 from characterassociation
            where (base = {a} and link = {b});
        """
      ).on(
        'a -> from,
        'b -> to
      ).as(scalar[Boolean].single)
    }
  }
  
  def getLinks(from: Long) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select characters.* from characterassociation
            left join characters on characters.id = characterassociation.link
            where characterassociation.base = {base};
        """
      ).on(
        'base -> from
      ).as(Character.parse *)
    }
  }
  
  def duplicate(char: Character) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into characters
            (name ,  user_id ,  game_id ,  data ,  picture ,  visible) values (
            {name}, {user_id}, {game_id}, {data}, {picture}, {visible}
          );
        """
      ).on(
        'name    -> char.name,
        'created -> char.created,
        'user_id -> char.user_id,
        'game_id -> char.game_id,
        'data    -> char.data,
        'picture -> char.picture,
        'visible -> false
      ).executeUpdate
    }
    
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from characters
            order by characters.created desc limit 1;
        """
      ).as(Character.parse.single)
    }
  }
  
  def public(id: Long, value: Boolean) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update characters
            set public = {value}
            where id = {id};
        """
      ).on(
        'id    -> id,
        'value -> value
      ).executeUpdate
    }
  }
  
  def visible(id: Long, value: Boolean) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update characters
            set visible = {value}
            where id = {id};
        """
      ).on(
        'id    -> id,
        'value -> value
      ).executeUpdate
    }
  }
  
  def canUpdate(id: Long)(user: User): Boolean = {
    val character = Character(id)
    
    if(character.user_id == user.id.get) {
      true
    } else if(Game.inGame(character.game_id)(user)) { 
      true
    } else {
      false
    }
  }
  
  val dateFormat = new java.text.SimpleDateFormat("EEE, d MMM yyy")
  
  def listSystems = {
    for(sys <- Play.getFile("public/data/").list())
      yield sys.split("""\.""")(0)
  }
  
}
