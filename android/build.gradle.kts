// android/build.gradle.kts (root del proyecto Android)

// 🔹 Nada de plugins acá (van en :app)
// 🔹 Sin allprojects { repositories { ... } }  -> ahora viven en settings.gradle.kts

import org.gradle.api.file.Directory

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // Si lo necesitás para ordenar la evaluación:
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
