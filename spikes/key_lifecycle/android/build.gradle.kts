plugins {
    id("com.android.library") version "8.9.2"
    id("org.jetbrains.kotlin.android") version "2.1.20"
}

android {
    namespace = "com.navinjournal.security.spike"
    compileSdk = 35
    defaultConfig {
        minSdk = 23
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}

kotlin {
    jvmToolchain(17)
}
