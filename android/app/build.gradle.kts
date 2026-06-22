import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "uz.lima.lima"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (Java 8+ time APIs on old Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "uz.lima.lima"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Use release signing if key.properties exists, otherwise fall back
            // to debug keys so `flutter run --release` still works locally
            // (guarded below: release artifacts refuse to build without it).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8: shrink + obfuscate for production builds.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring — required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Guard: a release APK/AAB signed with debug keys is rejected by Google Play.
// Without key.properties the fallback above would silently produce exactly
// that, so fail loudly instead. Local debug-signed release runs are still
// possible with an explicit opt-in: -PallowDebugSigning=true.
tasks.configureEach {
    if ((name == "assembleRelease" || name == "bundleRelease") &&
        !keystorePropertiesFile.exists()
    ) {
        doFirst {
            if (!project.hasProperty("allowDebugSigning")) {
                throw GradleException(
                    "android/key.properties not found: the release build would be " +
                        "signed with DEBUG keys and rejected by Google Play. " +
                        "Provide android/key.properties (keyAlias, keyPassword, " +
                        "storeFile, storePassword), or pass -PallowDebugSigning=true " +
                        "to build a debug-signed release locally on purpose."
                )
            }
        }
    }
}
