// Fichier de configuration principal où vous pouvez ajouter des options communes à tous les sous-projets/modules.

buildscript {
    // Définir les versions dans une variable
    val kotlinVersion by extra("1.7.10")

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:7.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
        // NOTE: Ne placez pas vos dépendances d'application ici ; elles appartiennent
        // aux fichiers build.gradle.kts individuels de chaque module
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}