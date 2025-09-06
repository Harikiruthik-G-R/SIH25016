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

        // ✅ Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

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
    // ✅ Core library desugaring required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))
    implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}

// Ensure Flutter output directory exists
tasks.register("createFlutterApkDir") {
    doLast {
        val flutterApkDir = file("${rootProject.projectDir}/../build/app/outputs/flutter-apk/")
        flutterApkDir.mkdirs()
        println("Created directory: ${flutterApkDir.absolutePath}")
    }
}

// Task to copy APK to Flutter's expected location
afterEvaluate {
    // Make sure the directory is created before any build
    tasks.named("preBuild") {
        dependsOn("createFlutterApkDir")
    }

    // Fixed task to copy debug APK with correct naming
    tasks.register<Copy>("copyDebugApkToFlutterLocation") {
        dependsOn("assembleDebug")
        val flutterApkDir = file("${rootProject.projectDir}/../build/app/outputs/flutter-apk/")
        from("${buildDir}/outputs/apk/debug/")
        into(flutterApkDir)
        include("*.apk")
        rename { filename ->
            if (filename.endsWith("-debug.apk")) {
                "app-debug.apk"
            } else {
                filename
            }
        }
        doFirst {
            flutterApkDir.mkdirs()
            println("Copying debug APK to: ${flutterApkDir.absolutePath}")
        }
        doLast {
            println("Debug APK copied to Flutter expected location: ${flutterApkDir.absolutePath}")
        }
    }

    // Fixed task to copy release APK with correct naming
    tasks.register<Copy>("copyReleaseApkToFlutterLocation") {
        dependsOn("assembleRelease")
        val flutterApkDir = file("${rootProject.projectDir}/../build/app/outputs/flutter-apk/")
        from("${buildDir}/outputs/apk/release/")
        into(flutterApkDir)
        include("*.apk")
        rename { filename ->
            if (filename.endsWith("-release.apk")) {
                "app-release.apk"
            } else {
                filename
            }
        }
        doFirst {
            flutterApkDir.mkdirs()
            println("Copying release APK to: ${flutterApkDir.absolutePath}")
        }
        doLast {
            println("Release APK copied to Flutter expected location: ${flutterApkDir.absolutePath}")
        }
    }

    tasks.named("assembleDebug") {
        finalizedBy("copyDebugApkToFlutterLocation")
    }

    tasks.named("assembleRelease") {
        finalizedBy("copyReleaseApkToFlutterLocation")
    }
}