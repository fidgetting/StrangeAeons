import sbt._
import Keys._
import play.Project._

object ApplicationBuild extends Build {

  val appName         = "StrangeAeons"
  val appVersion      = "0.1-ALPHA"

  val appDependencies = Seq(
    "com.typesafe" %% "play-plugins-mailer" % "2.1.0",
    "org.mindrot" % "jbcrypt" % "0.3m",
    "nl.rhinofly" %% "api-s3" % "2.6.1",
    "org.imgscalr" % "imgscalr-lib" % "4.2",
    jdbc,
    anorm
  )


  val main = play.Project(appName, appVersion, appDependencies).settings(
    coffeescriptOptions := Seq("bare"),
    sources in doc in Compile := List(),
    resolvers += "Rhinofly Internal Repository" at "http://maven-repository.rhinofly.net:8081/artifactory/libs-release-local",
    resolvers += "The Buzz Media Maven Repository" at "http://maven.thebuzzmedia.com"
  )

}
