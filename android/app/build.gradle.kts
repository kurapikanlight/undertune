plugins {
    id("com.android.application")
}

val undertuneVersion = rootProject.file("../app/pubspec.yaml").readLines()
    .first { it.startsWith("version:") }.substringAfter(":").trim()

android {
    namespace = "com.kafeyn.undertune"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Separate install while the new app is validated.
        applicationId = "com.kafeyn.undertune"
        applicationIdSuffix = providers.gradleProperty("undertuneApplicationSuffix").getOrElse(".flutter")
        minSdk = 23
        targetSdk = 36
        versionCode = undertuneVersion.substringAfter("+", "1").toInt()
        versionName = undertuneVersion.substringBefore("+")
    }

    signingConfigs.getByName("debug") {
        storeFile = file(System.getenv("UNDERTUNE_DEBUG_KEYSTORE")
            ?: "${System.getProperty("user.home")}/.android/debug.keystore")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Development AOT build. Configure a production key before publishing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Scripted releases produce device APKs without dropping universal support.
    splits {
        abi {
            isEnable = providers.gradleProperty("undertuneSplitApks").orNull == "true"
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }
}


dependencies {
    testImplementation("junit:junit:4.13.2")
    debugImplementation("com.kafeyn.undertune_ui:flutter_debug:1.0")
    releaseImplementation("com.kafeyn.undertune_ui:flutter_release:1.0")
    implementation("com.github.InfinityLoop1308.PipePipeExtractor:extractor:v5.4.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
}

// Live network checks must run again even when source inputs are unchanged.
tasks.withType<Test>().configureEach {
    if (System.getenv("UNDERTUNE_LIVE_TEST") == "1") {
        outputs.upToDateWhen { false }
    }
}
