plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // ✅ เพิ่ม plugin สำหรับ Firebase
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin ควรอยู่ล่างสุด
}

android {
    namespace = "com.example.anti_scam_ai"  // กำหนด namespace ที่นี่
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.anti_scam_ai"
        minSdk = 27  // ปรับเป็น 27 ตามคำแนะนำจาก `backendless_sdk`
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    buildTypes {
        release {
            // ปกติควรเซ็ต signingConfigs ที่นี่ สำหรับ release build (แก้ตามจริงถ้าต้องการ)
            signingConfig = signingConfigs.getByName("debug") 
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase Authentication และ Google Sign-in
    implementation("com.google.firebase:firebase-auth-ktx:22.3.0")
    implementation("com.google.android.gms:play-services-auth:21.0.0")
}
