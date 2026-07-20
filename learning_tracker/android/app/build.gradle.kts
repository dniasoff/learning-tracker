import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jcom.torah.learning_tracker"
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
        applicationId = "com.jcom.torah.learning_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falling back to the debug signingConfig when key.properties is
            // absent is intentional for local development
            // (docs/deployment-guide.md) — `flutter run --release` / `flutter
            // build apk --release` must keep working on a machine with no
            // release keystore configured. The AUD-platform-03 fail-fast
            // check below lives outside this block deliberately — see its
            // comment for why.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// AUD-platform-03: refuse to silently produce a debug-signed "release"
// artifact when a real release build was explicitly requested. CI's
// "Build APK" workflow (.github/workflows/build.yml) sets
// REQUIRE_RELEASE_SIGNING=true only on its release job, so a misconfigured
// or missing KEYSTORE_BASE64 secret now fails the build loudly instead of
// silently uploading a debug-signed APK as the artifact
// "learning-tracker-release-apk". Local dev (no env var set) keeps the
// documented debug-signing fallback above, but no longer SILENTLY: a loud,
// repeated warning is logged whenever a release artifact is debug-signed, so
// it can never be mistaken for a distributable build (AUD-platform-03 AC1).
//
// This check is deliberately deferred to `gradle.taskGraph.whenReady`
// (i.e. task-execution time, once Gradle knows which tasks were actually
// requested) rather than evaluated eagerly inside `buildTypes { release {
// signingConfig = ... } }` above. Gradle configures every build type's
// block on every invocation regardless of which task is requested, so an
// eager check there would also fire — and break — a plain
// `assembleDebug`/`flutter build apk --debug` run made in an environment
// where REQUIRE_RELEASE_SIGNING happened to be set.
gradle.taskGraph.whenReady {
    val releaseArtifactRequested = allTasks.any { task ->
        task.project == project &&
            task.name.endsWith("Release") &&
            (task.name.startsWith("assemble") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("package"))
    }
    if (releaseArtifactRequested && !keystorePropertiesFile.exists()) {
        if (System.getenv("REQUIRE_RELEASE_SIGNING") == "true") {
            // CI (and anyone opting in): hard-fail — a release artifact must
            // never be silently debug-signed. See build.yml's release job.
            throw GradleException(
                "Release build requested with REQUIRE_RELEASE_SIGNING=true but " +
                    "android/key.properties is missing — refusing to silently sign the " +
                    "release artifact with the debug keystore (AUD-platform-03). Ensure the " +
                    "KEYSTORE_BASE64/KEY_ALIAS/KEY_PASSWORD/STORE_PASSWORD secrets are " +
                    "configured for this workflow run. See docs/deployment-guide.md."
            )
        } else {
            // Local dev: the debug-signing fallback is intentional and kept
            // (docs/deployment-guide.md) so `flutter run --release` /
            // `flutter build apk --release` still work with no keystore. But it
            // is no longer SILENT (AUD-platform-03 AC1): warn loudly and
            // repeatedly so a debug-signed "release" artifact is never produced
            // unknowingly and mistaken for a distributable build.
            val banner = "=".repeat(78)
            logger.warn(
                "\n$banner\n" +
                    "⚠️  AUD-platform-03: RELEASE artifact is being DEBUG-SIGNED because\n" +
                    "    android/key.properties is absent. This APK/AAB is NOT distributable —\n" +
                    "    do not upload or share it as a real release.\n" +
                    "    This is the intended local-dev fallback. To turn it into a hard error\n" +
                    "    (as CI does), set REQUIRE_RELEASE_SIGNING=true. See docs/deployment-guide.md.\n" +
                    banner + "\n"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
