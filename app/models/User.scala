package models

import java._
import util.{Date}
import security.{MessageDigest}
import math.{BigInteger}

import org.mindrot.jbcrypt.BCrypt

import com.typesafe.plugin._

import play.api._
import db._
import mvc._
import libs._
import json._
import Play.current
import controllers._

import anorm._
import SqlParser._

trait  Permisions
object Permisions {
  def apply(in: Int): Permisions = in match {
    case 0 => Basic
    case 1 => GameMaster
    case 2 => Administrator
  }
}

case object Basic         extends Permisions
case object GameMaster    extends Permisions
case object Administrator extends Permisions

case class User(
    id      : Pk[Long] = NotAssigned,
    email   : String,
    name    : String,
    password: String,
    perm    : Permisions,
    valid   : Boolean,
    openid  : Boolean) extends Restful {
  
  lazy val basic = perm match {
    case Basic         => true
    case _             => false
  }
  
  lazy val gm = perm match {
    case GameMaster    => true
    case _             => false
  }
  
  lazy val admin = perm match {
    case Administrator => true
    case _             => false
  }
  
  
  lazy val isGm = perm match {
    case Administrator => true
    case GameMaster    => true
    case _             => false
  }
  
  lazy val isAdmin = perm match {
    case Administrator => true
    case _             => false
  }

  def rest_json(getter: User) = Json.obj(
    "id"    -> id.get,
    "name"  -> name,
    "email" -> email,
    "games" -> (for(game <- Game.master(this)) yield Json.obj(
      "id"   -> game.id.get,
      "name" -> game.name
    ))
  )
  
}

case class CharacterSet(val chars: Seq[(User, Game, Character)]) {
  
  def json(getter: User, base: Option[Game]) = JsArray(
    for((user, game, char) <- chars) yield Json.obj(
      "picture" -> char.imgUrl,
      "id"      -> char.id.get,
      "name"    -> char.name,
      "min"     -> char.minName,
      "info"    -> char.info,
      "user"    -> Json.obj("name" -> user.name, "link" -> routes.Application.user(user.name).toString),
      "game"    -> Json.obj("name" -> game.name, "link" -> routes.Application.game(game.id.get).toString),
      "link"    -> routes.Characters.display(char.id.get).toString,
      "state"   -> (
        if     (getter.id.get == char.user_id                     ) { "owned" }
        else if(getter.id.get == base.map(_.master).getOrElse(-1) ) { "take"  }
        else                                                        { "none"  }
      )
    )
  )
  
}

object User {
  
  def genPass(password: String) =
    BCrypt.hashpw(password, BCrypt.gensalt())
  
  def parse: RowParser[User] = {
    get[Pk[Long]]("users.id"       ) ~
    get[String]  ("users.email"    ) ~
    get[String]  ("users.name"     ) ~
    get[String]  ("users.password" ) ~
    get[Int]     ("users.permision") ~
    get[Boolean] ("users.validated") ~
    get[Boolean] ("users.openid"   ) map {
      case id ~ email ~ name ~ password ~ perm ~ valid ~ openid =>
        User(id, email, name, password, Permisions(perm), valid, openid)
    }
  }
  
  def parseAll = {
    User.parse ~ Game.parse ~ Character.parse map {
      case user ~ game ~ character =>
        (user, game, character)
    }
  }
  
  def list(user: User): CharacterSet = {
    DB.withConnection { implicit connection =>
      CharacterSet(SQL(
        """
          select * from characters
            left join users on characters.user_id = users.id
            left join games on characters.game_id = games.id
            where users.id = {id} and characters.visible
            order by characters.name
        """
      ) on (
        'id -> user.id
      ) as (parseAll *))
    }
  }
  
  def not(user: User): Seq[User] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where id != {id}
            order by name
        """
      ) on (
        'id -> user.id
      ) as (User.parse *)
    }
  }
  
  def insert(email: String, name: String, password: String, openid: Boolean) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          insert into users
            (email ,  name ,  password , validated ,  openid) values (
            {email}, {name}, {password}, FALSE     , {openid}
          )
        """
      ).on(
        'email     -> email,
        'name      -> name,
        'password  -> genPass(password),
        'openid    -> openid
      ).executeUpdate()
    }
  }
  
  def delete(id: Long) = {
    DB.withConnection {
      implicit connection =>
      SQL(
        """
          delete from users
            where id = {id}
        """
      ).on(
        'id -> id
      ).executeUpdate
    }
  }
  
  def apply(email: String): Seq[User] = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where users.email = {email} or users.name = {email};
        """
      ).on(
        'email -> email
      ).as(User.parse *)
    }
  }
  
  def apply(id: Long): User =  {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where users.id = {id};
        """
      ).on(
        'id -> id
      ).as(User.parse.single)
    }
  }

  def byEmail(email: String): User = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where users.email = {email} or users.name = {email};
        """
      ).on(
        'email -> email
      ).as(User.parse.single)
    }
  }
  
  def id(username: String): Long = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          select id from users
            where email = {email}
        """
      ).on(
        'username -> username
      ).as(scalar[Long].single)
    }
  }
  
  def validate(email: String, password: String): Boolean = {
    val user = DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where email = {email}
        """
      ) on (
        'email    -> email
      ) as (User.parse *)
    }

    
    ( user.size == 1  &&
      user(0).valid   &&
      !user(0).openid &&
      BCrypt.checkpw(password, user(0).password) )
  }
  
  def exists(email: String): Boolean = {
    DB.withConnection { implicit connection =>
      (SQL(
        """
          select count(users.id) = 1 from users
            where email = {email}
        """
      ).on (
        'email    -> email
      ).as (scalar[Boolean].single))
    }
  }
  
  def options(): Seq[(String, String)] = {
    for(User(id, email, name, _, _, _, _) <-
      DB.withConnection { implicit connection =>
        SQL(
          """
            select * from users
              order by name
          """
        ).as(User.parse *) } )
      yield (id.toString -> s"$name :: $email")
  }
  
  def permision(user: User, value: Int) = {
    DB.withConnection { implicit connection =>
      SQL(
        """
          update users
            set permision = {value}
            where id = {id}
        """
      ).on(
        'value -> value,
        'id    -> user.id.get
      ).executeUpdate()
    }
  }
  
  def userSets(user: User, game: Game) = {
    (DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where users.id in (
              select user_id from gameassociation
                where game_id = {game})
            and users.id != {user}
        """
      ).on(
        'game -> game.id.get,
        'user -> user.id.get
      ).as(User.parse *)
    }, DB.withConnection { implicit connection =>
      SQL(
        """
          select * from users
            where users.id not in (
              select user_id from gameassociation
                where game_id = {game})
            and users.id != {user}
        """
      ).on(
        'game -> game.id.get,
        'user -> user.id.get
      ).as(User.parse *)
    })
  }
  
  def pictureName = "%d.png".format(
    DB.withConnection { implicit connection =>
      SQL(
        """
          select nextval('picture_seq'::regclass)
        """
      ).as(scalar[Long].single)
    }
  )
  
  lazy val htst = """((.*?)://)(.*)""".r
  lazy val md5  = MessageDigest.getInstance("MD5"  )
  lazy val sha1 = MessageDigest.getInstance("SHA-1")
  
  val ValidateEmail = """
    Thank you for joining %s.
    
      We need to verify your email address before you can access your account. Please
    visit the url below to verify your account.
    
      %s
    
    Thanks"""
  
  def getHashed(email: String) = {
    (new BigInteger(1,  md5.digest(email.getBytes())).toString(16)) +
    (new BigInteger(1, sha1.digest(email.getBytes())).toString(16))
  }
  
  def sendValidation(name: String, email: String)(implicit request: Request[AnyContent]) = {
    val htst(_, _, url)  = controllers.routes.Application.index.absoluteURL()
    
    if(Play.current.mode == Mode.Prod) {
      val mail = use[MailerPlugin].email
      
      mail.setSubject(s"$url Email Validation")
      mail.addRecipient(s"$name <$email>", email)
      mail.addFrom(s"noreply@$url")
      mail.send(ValidateEmail.format(url,
          controllers.routes.Auth.validate(getHashed(email)).absoluteURL()))
      
    } else {
      println(ValidateEmail.format(url,
          controllers.routes.Auth.validate(getHashed(email)).absoluteURL()))
    }
  }
  
  def nonValidated = DB.withConnection { implicit connection =>
    SQL(
      """
        select * from users
          where not users.validated
      """
    ).as(User.parse *)
  }
  
  def setValidated(user: User) = DB.withConnection { implicit connection =>
    SQL(
      """
        update users
          set validated = TRUE
          where id = {user_id}
      """
    ).on(
      'user_id -> user.id.get
    ).executeUpdate()
  }
  
  def userCheckin(hash: String) = {
    (for(user <- nonValidated if getHashed(user.email) == hash) yield user) match {
      case List(user) =>
        setValidated(user)
        true
      
      case _ =>
        false
    }
  }

  def changeAuth(id: Long, openid: Boolean, pass: String) = DB.withConnection { implicit connection =>
    SQL(
      """
        update users
          set openid = {openid}, password = {pass}
          where id = {id};
      """
    ).on(
      'pass   -> pass,
      'openid -> openid,
      'id     -> id
    ).executeUpdate()
  }

  def changePassword(user: User, pass: String) =
    changeAuth(user.id.get, false, genPass(pass))

  def changeOpenid  (user: User, pass: String) =
    changeAuth(user.id.get, user.openid, pass)
  
}