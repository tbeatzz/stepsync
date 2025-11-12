// (opcional) import explícito si tu IDE lo pide
import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ⬇️ ESTE bloque es el que te faltaba / estaba mal ubicado
dependencyResolutionManagement {
    // Permití que los proyectos agreguen repos (el plugin de Flutter lo necesita)
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)

    repositories {
        google()
        mavenCentral()
        // si usás algo extra, podés sumar mavenLocal() o repos de terceros acá
    }
}


plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
