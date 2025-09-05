plugins {
    kotlin("android") version "2.2.0" apply false
    id("com.android.application") version "8.7.0" apply false
    id("com.google.gms.google-services") version "4.4.3" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    // ✅ Avoid circular references
    project.buildDir = File("${rootProject.buildDir}/${project.name}")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
