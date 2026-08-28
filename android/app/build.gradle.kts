plugins {
    id("com.android.application")
    // ⚠️ **قبل بلوجن فلاتر.** ده اللي بيقرا `google-services.json`
    // ويحوّله لموارد جوّه الـAPK — من غيره فاير بيز بيرمي
    // «Default FirebaseApp is not initialized» وقت التشغيل.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ⚠️ **ماتضيفش بلوك `dependencies` بالـBoM وfirebase-analytics** زي
// ما كونسول فاير بيز بيقترح. ده للمشاريع الأندرويد الأصلية —
// في فلاتر باكدجات `firebase_core` و`firebase_messaging` بتجيب
// مكتباتها بنفسها، وإضافة الـBoM بإيدك بتعمل تعارض إصدارات.

android {
    namespace = "com.promax.reps"
    // باكدجات الكاميرا والملفات محتاجة API 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.promax.reps"
        // image_picker / file_picker محتاجين 21+
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
