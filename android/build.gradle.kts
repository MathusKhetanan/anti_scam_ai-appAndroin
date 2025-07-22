
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.4.2")
        classpath("com.google.gms:google-services:4.4.0") // Firebase Google Services plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// กำหนดตำแหน่ง build directory (ถ้าต้องการเปลี่ยน)
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "11"
        targetCompatibility = "11"
        options.compilerArgs.add("-Xlint:-options") // ซ่อน warning ชั่วคราว
    }
}

// ลง plugin google-services แต่ยังไม่ apply ที่ root
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}

// task clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
