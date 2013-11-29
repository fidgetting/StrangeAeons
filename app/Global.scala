/**
 * Created with IntelliJ IDEA.
 * User: norton
 * Date: 11/28/13
 * Time: 9:01 PM
 * To change this template use File | Settings | File Templates.
 */

import javax.imageio._

import play.api._
import libs._
import concurrent._

import Execution.Implicits._

import scala.concurrent._
import duration._

import fly.play.s3._
import org.imgscalr.Scalr
import java.io.{FileOutputStream, FileInputStream}

object Global extends GlobalSettings {

  override def onStart(app: Application) {

    val base_w = 75
    val base_h = 80
    val picture_ratio: Double =  base_h.toDouble / base_w.toDouble
    val storage = S3(Play.current.configuration.getString("aws.bucket").
      getOrElse("strange-aeons-filestore"))

    val imgMatch = """([^_]+\.png)""".r

    def sendFile(name: String, ctype: String, file: java.io.File) = {
      val istr = new FileInputStream(file)
      val dest = new Array[Byte](file.length().toInt)

      istr read dest
      storage add BucketFile(name, ctype, dest)
    }

    storage.list.map {
      case Right(iter) =>
        for(BucketItem(name, _) <- iter) {
          (storage get name).map {
            case Right(BucketFile(imgMatch(name), ctype, content, acl, Some(headers))) =>
              try {
                val tmpf = new java.io.File(s"/tmp/pic_$name")
                val outf = new java.io.File(s"/tmp/out_$name")
                val ostr = new FileOutputStream(tmpf)

                ostr.write(content)
                val img    = ImageIO.read(tmpf)
                val ratio  = img.getHeight.toDouble / img.getWidth.toDouble
                val thu    = Scalr.crop(Scalr.resize(img,
                  if(ratio > picture_ratio) Scalr.Mode.FIT_TO_WIDTH else Scalr.Mode.FIT_TO_HEIGHT,
                  if(ratio > picture_ratio) 75                      else 80), 75, 80)

                ImageIO.write(thu, "png", outf)
                sendFile(s"t_$name", ctype, outf)

                tmpf.delete
                outf.delete

              } catch {
                case e => Logger.warn(s"Exception: $name $e")
                case _ => Logger.warn(s"Exception: $name")
              }
            case _ => Logger.info(s"No Match: $name")
          }
        }
      case Left(_) =>
        Logger.warn("HUH?")
    }

  }

  override def onStop(app: Application) {
    Logger.info("Application shutdown...")
  }

}
