plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin ต้องอยู่ล่างสุดตามที่คุณใส่ไว้แล้ว
}

android {
    namespace = "com.example.anti_scam_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "25.2.9519653"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.anti_scam_ai"
        minSdk = 23 // Android 6.0 เพื่อให้รองรับ runtime permission
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin") // **เพิ่มตรงนี้เพื่อให้รู้จัก kotlin source**
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
