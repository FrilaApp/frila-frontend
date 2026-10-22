// Módulo Kotlin puro (JVM): sessão segura e isolamento de conta, sem dependência do SDK Android.
// A implementação real com Android Keystore / EncryptedSharedPreferences fica para o módulo
// `:app` ou um adaptador Android próprio; aqui vive a interface e a lógica testável em JVM pura
// (ver docs/android/04-seguranca-e-sessao.md).
plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":core:dominio"))
    implementation(project(":core:rede"))

    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit.jupiter.api)
    testImplementation(libs.junit.jupiter.params)
    testRuntimeOnly(libs.junit.jupiter.engine)
    testImplementation(libs.mockk)
}

tasks.test {
    useJUnitPlatform()
}
