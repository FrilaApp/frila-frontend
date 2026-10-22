@file:Suppress("UnstableApiUsage")

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "frila-android"

include(":core:dominio")
include(":core:rede")
include(":core:seguranca")
include(":core:designsystem")
include(":core:localizacao")
include(":feature:entrada")
include(":feature:vagas")
include(":feature:turnos")
include(":feature:perfil")
include(":core:notificacoes")
include(":app")
