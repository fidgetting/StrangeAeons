package controllers

import javax.imageio._

import play.api._
import mvc._
import data._
import libs._
import Forms._

import json._
import concurrent._
import iteratee._

import Execution.Implicits._

import models._
import views._

import fly.play.s3._
import scala.concurrent.duration._
import scala.concurrent.Await
import org.imgscalr.Scalr
import java.io.FileInputStream

object Application extends Controller with Secured {
  
  val Home = Redirect(routes.Application.home)
  
  val signupForm = Form(
    tuple(
      "email"    -> text,
      "name"     -> text,
      "password" -> text,
      "confirm"  -> text
    )
  )
  
  val storage = S3(Play.current.configuration.getString("aws.bucket").
      getOrElse("strange-aeons-filestore"))

  // -- Actions
  
  def index = Action { Home } 
  
  def home = withAuth { user => implicit request =>
    Ok(html.character.list(user, User.list(user)))
  }
  
  def search(term: String) = withAuth { user => implicit request =>
    Ok(html.character.list(user, Character.list(term)))
  }
  
  def list(name: String, game: String, char: String) = withAuth { user => implicit request =>
    Ok(html.character.list(user, Character.list(name, game, char)))
  }
  
  def user(name: String) = {
    list(name, "", "")
  }
  
  def game(id: Long) = inGame(id) { user => _ =>
    val game = Game(id)
    
    Ok(if(Game.isMaster(game.id.get)(user)) {
      html.gm.list(user, Character.list(game), User.userSets(user, game), game)
    } else {
      html.character.list(user, Character.list(game), Option(game))
    })
  }
  
  def javascriptRoutes = Action { implicit request =>
    import routes.javascript._
    Ok(Routes.javascriptRouter("jsRoutes")(
        routes.javascript.Application.upload,

        Auth.taken,
        
        Characters.save, Characters.update, Characters.character,
        Characters.system, Characters.delete, Characters.create,
        Characters.take, Characters.link, Characters.duplicate,
        Characters.setPublic, Characters.setVisible,
        
        Notes.list, Notes.save, Notes.update, Notes.delete,
        
        Games.newGame, Games.games, Games.save, Games.add, Games.remove,
        Games.characters,
        
        GameMaster.data, GameMaster.npcui, GameMaster.aspects, GameMaster.aspect,
        
        Admin.permisions, Admin.delete,

        Restful.get
      )
    ).as("text/javascript")
  }

  def sendFile(name: String, ctype: String, file: java.io.File) = {
    val istr = new FileInputStream(file)
    val dest = new Array[Byte](file.length().toInt)

    istr read dest
    storage add BucketFile(name, ctype, dest)
  }

  val base_w = 75
  val base_h = 80
  val picture_ratio: Double =  base_h.toDouble / base_w.toDouble
  def upload(id: Long) = canUpload(parse.multipartFormData)(id) { user => implicit request =>
    val name = (for {
      picture <- request.body.file("picture")
      user    <- username(request)
    } yield {
      val Some(ctype) = picture.contentType
      val picn = User.pictureName
      val file  = new java.io.File(s"/tmp/picture_$picn")
      val thumb = new java.io.File(s"/tmp/thumb_$picn")
      
      val orImg  = Scalr.resize(ImageIO.read(picture.ref.file), 400)
      val ratio  = orImg.getHeight.toDouble / orImg.getWidth.toDouble
      val tbImg = Scalr.crop(Scalr.resize(orImg,
        if(ratio > picture_ratio) Scalr.Mode.FIT_TO_WIDTH else Scalr.Mode.FIT_TO_HEIGHT,
        if(ratio > picture_ratio) 75                      else 80), 75, 80)
      
      ImageIO.write(orImg, "png", file)
      ImageIO.write(tbImg, "png", thumb)



      sendFile(     picn , ctype, file)
      sendFile(s"t_$picn", ctype, thumb)

      file.delete()
      thumb.delete()

      Character.updatePicture(id, picn)
      
      picn
    }).getOrElse("nonPerson.png")
    
    Ok(Json.obj("url" -> storage.url(name, 1000)))
  }
  
  def file(name: String) = Action { _ =>
    val result = ((storage get name).map {
      case Right(BucketFile(name, contentType, content, acl, Some(headers))) =>
        SimpleResult(
          header = ResponseHeader(200, Map(
              CONTENT_LENGTH -> headers("Content-Length"),
              CONTENT_TYPE   -> contentType)),
          body = Enumerator[Array[Byte]](content)
        )
        
      case _ =>
        Ok
      })
      
    Await.result(result, 60.seconds)
  }
  
}
