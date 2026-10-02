plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    jvmToolchain(17)
}

val lifeOsKeystorePath = System.getenv("LIFE_OS_KEYSTORE_PATH")
val lifeOsKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val lifeOsKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val lifeOsKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasLifeOsReleaseSigning =
    !lifeOsKeystorePath.isNullOrBlank() &&
    !lifeOsKeystorePassword.isNullOrBlank() &&
    !lifeOsKeyAlias.isNullOrBlank() &&
    !lifeOsKeyPassword.isNullOrBlank() &&
    file(lifeOsKeystorePath).exists()


android {
    signingConfigs {
        if (hasLifeOsReleaseSigning) {
            create("lifeOsRelease") {
                storeFile = file(lifeOsKeystorePath!!)
                storePassword = lifeOsKeystorePassword
                keyAlias = lifeOsKeyAlias
                keyPassword = lifeOsKeyPassword
            }
        }
    }

    namespace = "com.example.counter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match Google Cloud Console → Android OAuth client (package name + SHA-1).
        applicationId = "com.example.counter"
        // Health integration requires API 26; Wear OS 3+ devices remain compatible.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // BUILD_STABILITY (§10): Satisfy manifest placeholders required by flutter_login_yandex. Replace with your Yandex OAuth client ID from Yandex Developer Console.
        manifestPlaceholders["YANDEX_CLIENT_ID"] = "your_yandex_client_id_here"
    }

    buildTypes {
        release {
            // CI uses the persistent LIFE OS release key from repository secrets.
            // Local builds without those secrets keep the debug fallback so development
            // remains possible, but published CI releases must use lifeOsRelease.
            signingConfig = if (hasLifeOsReleaseSigning) {
                signingConfigs.getByName("lifeOsRelease")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-wearable:18.1.0")
}
