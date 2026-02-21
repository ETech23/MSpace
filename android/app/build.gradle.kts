plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.artisan_marketplace_new"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.artisan_marketplace_new"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "MSpace")
            resValue("string", "admob_app_id", "ca-app-pub-3940256099942544~3347511713")
        }

        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "MSpace")
            val admobAppId = System.getenv("ADMOB_APP_ID_ANDROID")
                ?: "ca-app-pub-0000000000000000~0000000000"
            resValue("string", "admob_app_id", admobAppId)
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Required for Java 8+ APIs on older devices
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM — add this to avoid version conflicts
    implementation(platform("com.google.firebase:firebase-bom:33.3.0"))

    // Firebase services your app likely uses
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")

    // Flutter local notifications (Android dependency handled automatically)
}

flutter {
    source = "../.."
}
