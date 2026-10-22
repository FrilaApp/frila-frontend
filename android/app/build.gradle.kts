// Shell da aplicação: navegação Compose, grafo Koin, Application e Activity únicos.
// Cartões Trello YRGYz50G e iWYMOk5C.
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "br.com.frila.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "br.com.frila.app"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

configurations.all {
    resolutionStrategy {
        // AGP 8.5.2 (compileSdk 35) não suporta várias versões mais novas puxadas
        // transitivamente por navigation-compose / koin-androidx-compose. Força a linha
        // compatível em vez de brigar com o catálogo de versões.
        force(
            "androidx.activity:activity:1.9.3",
            "androidx.activity:activity-ktx:1.9.3",
            "androidx.activity:activity-compose:1.9.3",
            "androidx.core:core:1.13.1",
            "androidx.core:core-ktx:1.13.1",
        )
    }
}

dependencies {
    implementation(project(":core:dominio"))
    implementation(project(":core:rede"))
    implementation(project(":core:seguranca"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:notificacoes"))
    implementation(project(":core:localizacao"))
    implementation(project(":feature:entrada"))
    implementation(project(":feature:vagas"))
    implementation(project(":feature:turnos"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.lifecycle.viewmodel.ktx)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.kotlinx.coroutines.core)

    implementation(libs.koin.core)
    implementation(libs.koin.android)
    implementation(libs.koin.androidx.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.ktor.client.core)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.play.services.location)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    testImplementation(platform(libs.compose.bom))
    testImplementation(platform(libs.firebase.bom))
    testImplementation(libs.junit.jupiter.api)
    testImplementation(libs.junit.jupiter.params)
    testRuntimeOnly(libs.junit.jupiter.engine)
    testImplementation(libs.mockk)
    testImplementation(libs.koin.test)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.ktor.client.mock)
    testImplementation(libs.kotlinx.serialization.json)
}

tasks.withType<Test> {
    useJUnitPlatform()
}
