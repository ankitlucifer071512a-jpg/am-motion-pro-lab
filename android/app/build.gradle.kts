import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningPropertiesFile.isFile) {
        releaseSigningPropertiesFile.inputStream().use { load(it) }
    }
}

fun releaseSigningValue(property: String, environmentVariable: String): String? =
    System.getenv(environmentVariable)?.takeIf(String::isNotBlank)
        ?: releaseSigningProperties.getProperty(property)?.takeIf(String::isNotBlank)

val releaseStoreFilePath = releaseSigningValue("storeFile", "AM_MOTION_STORE_FILE")
val releaseStorePassword = releaseSigningValue("storePassword", "AM_MOTION_STORE_PASSWORD")
val releaseKeyAlias = releaseSigningValue("keyAlias", "AM_MOTION_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "AM_MOTION_KEY_PASSWORD")
val releaseSigningValuesPresent = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }
val releaseStoreFile = releaseStoreFilePath?.let { rootProject.file(it) }
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested) {
    require(releaseSigningValuesPresent && releaseStoreFile?.isFile == true) {
        "Release signing is not configured. Create android/key.properties with storeFile, " +
            "storePassword, keyAlias, and keyPassword, and provide the keystore at storeFile. " +
            "Alternatively set AM_MOTION_STORE_FILE, AM_MOTION_STORE_PASSWORD, " +
            "AM_MOTION_KEY_ALIAS, and AM_MOTION_KEY_PASSWORD."
    }
}

android {
    namespace = "com.example.my_first_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_first_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Required by model_viewer_plus for its embedded 3D viewer.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningValuesPresent) {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
