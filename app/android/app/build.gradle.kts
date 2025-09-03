plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.geoat.app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
     // JVM Toolchain ensures consistency
    

    defaultConfig {
      
        applicationId = "com.geoat.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
           
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}




dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.2.0"))

  implementation("com.google.firebase:firebase-analytics")

}

flutter {
    source = "../.."
}

// Task to copy APK to Flutter's expected location
afterEvaluate {
    tasks.register<Copy>("copyApkToFlutterLocation") {
        dependsOn("assembleDebug")
        from("${buildDir}/outputs/apk/debug/")
        into("${project.rootDir}/../../build/app/outputs/flutter-apk/")
        include("*.apk")
        doFirst {
            file("${project.rootDir}/../../build/app/outputs/flutter-apk/").mkdirs()
        }
    }

    tasks.named("assembleDebug") {
        finalizedBy("copyApkToFlutterLocation")
    }
}
