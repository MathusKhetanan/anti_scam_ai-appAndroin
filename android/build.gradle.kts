allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
        options.compilerArgs.add("-Xlint:-options") // ซ่อน warning ชั่วคราว
    }
}

// ✅ เพิ่ม plugin สำหรับ Firebase Google Services
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}

// ✅ เพิ่ม task clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
