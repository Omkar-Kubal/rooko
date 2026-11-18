import java.net.URI
import java.security.AlgorithmParameters
import java.security.KeyFactory
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec
import java.security.spec.X509EncodedKeySpec
import java.util.Base64

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.devtools.ksp")
}

fun String.asBuildConfigString(): String =
    "\"${replace("\\", "\\\\").replace("\"", "\\\"")}\""

val detectorRegistryUrl = providers.gradleProperty("rookoDetectorRegistryUrl")
    .orElse("")
    .get()
val detectorRegistryPublicKey = providers.gradleProperty("rookoDetectorRegistryPublicKey")
    .orElse("")
    .get()

android {
    namespace = "com.appylab.rooko"
    buildFeatures {
        buildConfig = true
    }
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.appylab.rooko"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "DETECTOR_REGISTRY_URL", detectorRegistryUrl.asBuildConfigString())
        buildConfigField(
            "String",
            "DETECTOR_REGISTRY_PUBLIC_KEY_BASE64",
            detectorRegistryPublicKey.asBuildConfigString(),
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.caverock:androidsvg-aar:1.4")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.room:room-runtime:2.8.4")
    ksp("androidx.room:room-compiler:2.8.4")
    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.room:room-testing:2.8.4")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("org.robolectric:robolectric:4.17")
}

val validateDetectorRegistryReleaseConfig = tasks.register("validateDetectorRegistryReleaseConfig") {
    group = "verification"
    description = "Requires the pinned live detector registry endpoint and public key for release artifacts."
    doLast {
        val endpoint = runCatching { URI(detectorRegistryUrl) }.getOrNull()
        require(
            endpoint?.scheme == "https" && !endpoint.host.isNullOrBlank() &&
                endpoint.userInfo == null && endpoint.query == null && endpoint.fragment == null,
        ) {
            "Release builds require rookoDetectorRegistryUrl to be a fixed HTTPS URL without user info, query, or fragment."
        }

        val publicKeyBytes = runCatching {
            Base64.getDecoder().decode(detectorRegistryPublicKey.filterNot(Char::isWhitespace))
        }.getOrNull()
        require(publicKeyBytes != null && publicKeyBytes.isNotEmpty()) {
            "Release builds require rookoDetectorRegistryPublicKey as base64 DER SubjectPublicKeyInfo."
        }
        val publicKey = runCatching {
            KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(publicKeyBytes))
        }.getOrNull()
        val expectedParameters = AlgorithmParameters.getInstance("EC").apply {
            init(ECGenParameterSpec("secp256r1"))
        }.getParameterSpec(ECParameterSpec::class.java)
        val actualParameters = (publicKey as? ECPublicKey)?.params
        require(actualParameters != null && actualParameters.curve == expectedParameters.curve &&
            actualParameters.generator == expectedParameters.generator &&
            actualParameters.order == expectedParameters.order &&
            actualParameters.cofactor == expectedParameters.cofactor
        ) {
            "rookoDetectorRegistryPublicKey must be a DER P-256 public key."
        }
    }
}

tasks.configureEach {
    val isReleaseArtifactTask = name.endsWith("Release") &&
        (name.startsWith("assemble") || name.startsWith("bundle") ||
            name.startsWith("package") || name.startsWith("sign"))
    if (isReleaseArtifactTask) dependsOn(validateDetectorRegistryReleaseConfig)
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}
