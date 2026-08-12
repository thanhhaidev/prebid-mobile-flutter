group = "com.prebid.prebid_mobile_sdk_max"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // AppLovin MAX SDK + adapters are hosted on AppLovin's Maven repo.
        maven { url = uri("https://artifacts.applovin.com/android") }
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.prebid.prebid_mobile_sdk_max"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    // Prebid MAX adapters. Pulls in the AppLovin MAX SDK (applovin-sdk)
    // transitively — the reason this is a separate package.
    implementation("org.prebid:prebid-mobile-sdk-max-adapters:3.3.0")
}
