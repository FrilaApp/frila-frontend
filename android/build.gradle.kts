// Raiz do projeto Android do Frila. Nenhum plugin é aplicado aqui diretamente;
// cada módulo declara seus próprios plugins (ver android/core/dominio/build.gradle.kts).
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
