// Preferências sem dependência do Android: engine real exercitada em testes JVM.
plugins {
    kotlin("jvm")
    `java-library`
}

kotlin { jvmToolchain(17) }

dependencies {
    api(libs.androidx.datastore.preferences.core)
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit.jupiter.api)
    testRuntimeOnly(libs.junit.jupiter.engine)
    testImplementation(libs.kotlinx.coroutines.test)
}

tasks.test { useJUnitPlatform() }
