group = "io.github.thanhhaidev.prebid_mobile_sdk_max"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.21"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
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
}

// Kotlin is applied by the Flutter Gradle plugin (or AGP 9's built-in Kotlin),
// so this works in apps on AGP 8 and 9 alike.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "io.github.thanhhaidev.prebid_mobile_sdk_max"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            // android.jar stubs return defaults instead of throwing: the
            // Prebid ad units touch Android classes when constructed.
            isReturnDefaultValues = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // Prebid MAX adapters. Pulls in the AppLovin MAX SDK (applovin-sdk)
    // transitively — the reason this is a separate package.
    implementation("org.prebid:prebid-mobile-sdk-max-adapters:3.4.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
    // The real org.json: android.jar only has stubs that throw in unit tests.
    testImplementation("org.json:json:20240303")
}
