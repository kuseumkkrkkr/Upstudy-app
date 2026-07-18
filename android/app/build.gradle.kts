import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 필요한 변수: Flutter가 Base64로 전달한 dart-defines 문자열.
// 작동 원리: 앱 코드와 Android 매니페스트가 동일한 카카오 네이티브 앱 키를 사용하도록 키·값을 복원한다.
fun decodeDartDefines(rawDefines: String?): Map<String, String> {
    if (rawDefines.isNullOrBlank()) return emptyMap()
    return rawDefines.split(',').mapNotNull { encoded ->
        runCatching {
            val decoded = String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            val separator = decoded.indexOf('=')
            if (separator <= 0) null else decoded.substring(0, separator) to decoded.substring(separator + 1)
        }.getOrNull()
    }.toMap()
}

android {
    namespace = "com.example.s11"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.s11"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val dartDefines = decodeDartDefines(project.findProperty("dart-defines")?.toString())
        val kakaoNativeAppKey: String =
            System.getenv("KAKAO_NATIVE_APP_KEY")
                ?: project.findProperty("KAKAO_NATIVE_APP_KEY") as String?
                ?: dartDefines["KAKAO_NATIVE_APP_KEY"]
                ?: ""
        manifestPlaceholders += mapOf(
            "KAKAO_APP_KEY" to kakaoNativeAppKey,
            "KAKAO_SCHEME" to if (kakaoNativeAppKey.isNotBlank()) "kakao$kakaoNativeAppKey" else ""
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
