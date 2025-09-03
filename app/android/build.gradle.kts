allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


plugins {
    kotlin("android") version "2.2.0" apply false 
    id("com.android.application") version "8.7.0" apply false
    id("com.google.gms.google-services") version "4.4.3" apply false
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
