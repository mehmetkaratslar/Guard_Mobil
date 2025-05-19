plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase için gerekli
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "guard.com.guard"
    compileSdk = 35

    defaultConfig {
        applicationId = "guard.com.guard"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        manifestPlaceholders["firebaseAuthWebClientId"] = "584140094374-cr72nn4vkcge7mv102brslmdlmd4hb5d.apps.googleusercontent.com"
        multiDexEnabled = true // Çoklu DEX desteği etkinleştirildi
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true // Kod küçültme etkinleştirildi
            isShrinkResources = true // Kaynak küçültme etkinleştirildi
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug") // Debug imzalama geçici olarak kullanılıyor
        }
        getByName("debug") {
            // Impeller'ı eski cihazlar için devre dışı bırak
            resValue("string", "io.flutter.embedding.android.EnableImpeller", "false")
        }
    }

    buildFeatures {
        buildConfig = true // BuildConfig oluşturmayı etkinleştir
    }

    // Eski cihazlarda performans optimizasyonu için ek ayarlar
    dexOptions {
        javaMaxHeapSize = "4g" // DEX işlemi için daha fazla bellek ayır
    }

    // Paketleme seçenekleri
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}" // Çakışan lisans dosyalarını hariç tut
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Core library desugaring
    implementation("androidx.multidex:multidex:2.0.1") // Çoklu DEX desteği için
}