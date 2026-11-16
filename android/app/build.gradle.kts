// Shell da aplicação: navegação Compose, grafo Koin, Application e Activity únicos.
// Cartões Trello YRGYz50G, iWYMOk5C e IZeQjV0N.
import groovy.json.JsonSlurper
import java.util.Base64
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.baselineprofile)
}

// Revisão ANBU (PR #557): o build type release não pode assinar com o keystore de debug
// ('CN=Android Debug'), nem a oficial da loja. O keystore de release só existe fora do
// repositório (CI/máquina de release); sem essas variáveis, o release fica sem signingConfig
// — compila (R8/shrink continuam sendo exercitados) mas o APK sai sem assinatura, nunca com
// a assinatura de debug carimbada como se fosse a oficial.
val releaseKeystorePath: String? = System.getenv("FRILA_RELEASE_KEYSTORE_PATH")
val releaseKeystorePassword: String? = System.getenv("FRILA_RELEASE_KEYSTORE_PASSWORD")
val releaseKeyAlias: String? = System.getenv("FRILA_RELEASE_KEY_ALIAS")
val releaseKeyPassword: String? = System.getenv("FRILA_RELEASE_KEY_PASSWORD")
val temKeystoreDeRelease: Boolean = !releaseKeystorePath.isNullOrBlank() &&
    !releaseKeystorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank()

// Cartão IZeQjV0N: URL e chave publicável do Supabase entram por BuildConfig. O build debug usa o
// par DEV e o release usa o par PROD, com os mesmos nomes dos segredos do repositório e do iOS
// (iOS/Docs/Environments.md). A fonte é a variável de ambiente e, na falta dela,
// android/local.properties (ignorado pelo Git). Nenhum valor é impresso, só o nome da variável.
val propriedadesLocais = Properties().apply {
    val arquivo = rootProject.file("local.properties")
    if (arquivo.isFile) arquivo.inputStream().use { load(it) }
}

fun valorSupabase(nome: String): String? =
    (System.getenv(nome)?.takeIf { it.isNotBlank() } ?: propriedadesLocais.getProperty(nome))
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

fun literalBuildConfig(valor: String): String =
    "\"" + valor.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

val supabaseUrlDev: String? = valorSupabase("FRILA_SUPABASE_DEV_URL")
val supabaseChaveDev: String? = valorSupabase("FRILA_SUPABASE_DEV_PUBLISHABLE_KEY")
val supabaseUrlProd: String? = valorSupabase("FRILA_SUPABASE_PROD_URL")
val supabaseChaveProd: String? = valorSupabase("FRILA_SUPABASE_PROD_PUBLISHABLE_KEY")

// Debug sem valores continua compilando (testes unitários). O placeholder tem host `.invalid`, que
// nunca resolve: o app em debug falha na rede, não fala com um backend por engano.
if (supabaseUrlDev == null || supabaseChaveDev == null) {
    logger.warn(
        "Supabase (debug): defina FRILA_SUPABASE_DEV_URL e FRILA_SUPABASE_DEV_PUBLISHABLE_KEY " +
            "(variável de ambiente ou android/local.properties). Sem elas, o app debug não alcança o backend.",
    )
}

// Regras da chave publicável. Espelham ConfiguracaoDoBackend.kt, que valida de novo na inicialização
// do app. A tarefa verificarRegrasDeChaveSupabase confere esta cópia contra os mesmos casos que o
// teste Kotlin usa (src/test/resources/supabase-chaves-casos.tsv) e roda antes de testDebugUnitTest.
// Mudou uma regra: mude as duas cópias e acrescente o caso. O retorno nomeia o motivo, nunca o valor.
fun ehJwtDeServiceRole(chave: String): Boolean {
    val partes = chave.split('.')
    if (partes.size != 3) return false
    return runCatching {
        val payload = String(Base64.getUrlDecoder().decode(partes[1].trimEnd('=').replace('+', '-').replace('/', '_')))
        ((JsonSlurper().parseText(payload) as Map<*, *>)["role"] as? String)
            ?.equals("service_role", ignoreCase = true) == true
    }.getOrDefault(false)
}

fun motivoDeRejeicaoDaChave(chave: String): String? = when {
    chave.startsWith("TODO", ignoreCase = true) -> "é placeholder (TODO)"
    chave.startsWith("sb_secret_") -> "é chave secreta; use a chave publicável"
    ehJwtDeServiceRole(chave) -> "é um JWT com role service_role; use a chave publicável"
    else -> null
}

// Release nunca sai sem URL e chave reais: falha nomeando a variável.
val verificarSupabaseDeRelease = tasks.register("verificarConfiguracaoSupabaseDeRelease") {
    group = "verification"
    description = "Falha o build de release se a URL ou a chave publicável do Supabase faltar ou for inválida."
    val url = supabaseUrlProd
    val chave = supabaseChaveProd
    doLast {
        val problemas = buildList {
            if (url == null) {
                add("FRILA_SUPABASE_PROD_URL ausente")
            } else if (url.startsWith("TODO", ignoreCase = true)) {
                add("FRILA_SUPABASE_PROD_URL é placeholder (TODO)")
            }
            if (chave == null) {
                add("FRILA_SUPABASE_PROD_PUBLISHABLE_KEY ausente")
            } else {
                motivoDeRejeicaoDaChave(chave)?.let { add("FRILA_SUPABASE_PROD_PUBLISHABLE_KEY $it") }
            }
        }
        if (problemas.isNotEmpty()) {
            throw GradleException(
                "Build de release sem configuração do Supabase: ${problemas.joinToString("; ")}. " +
                    "Defina por variável de ambiente ou em android/local.properties.",
            )
        }
    }
}

val verificarRegrasDeChaveSupabase = tasks.register("verificarRegrasDeChaveSupabase") {
    group = "verification"
    description = "Confere a regra de chave deste script contra os casos compartilhados com o teste Kotlin."
    val casos = file("src/test/resources/supabase-chaves-casos.tsv")
    inputs.file(casos)
    doLast {
        val linhas = casos.readLines().filter { it.isNotBlank() && !it.startsWith("#") }
        if (linhas.size < 8) throw GradleException("supabase-chaves-casos.tsv tem só ${linhas.size} casos; esperados 8 ou mais.")
        val divergentes = linhas.mapIndexedNotNull { indice, linha ->
            val (veredito, chave) = linha.split('\t', limit = 2)
            val aceitou = motivoDeRejeicaoDaChave(chave.trim()) == null
            if ((veredito == "aceita") != aceitou) "caso ${indice + 1} ($veredito)" else null
        }
        if (divergentes.isNotEmpty()) {
            throw GradleException("A regra de chave do Gradle diverge do veredito esperado em: ${divergentes.joinToString(", ")}.")
        }
    }
}
tasks.matching { it.name == "testDebugUnitTest" }.configureEach {
    dependsOn(verificarRegrasDeChaveSupabase)
}

// Também cobre benchmarkRelease e nonMinifiedRelease (baseline profile), que herdam os campos do release.
tasks.matching { it.name.startsWith("generate") && it.name.endsWith("ReleaseBuildConfig") }.configureEach {
    dependsOn(verificarSupabaseDeRelease)
}

android {
    namespace = "br.com.frila.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "br.com.frila.app"
        minSdk = 28
        targetSdk = 35
        versionCode = 2
        versionName = "1.2.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
        // RN15 (cartão Cdv0sS5w): LeitorDeAmbienteAndroid lê BuildConfig.DEBUG para tolerar
        // assinatura divergente em build local de desenvolvimento.
        buildConfig = true
    }

    if (temKeystoreDeRelease) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            buildConfigField("String", "SUPABASE_URL", literalBuildConfig(supabaseUrlProd.orEmpty()))
            buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", literalBuildConfig(supabaseChaveProd.orEmpty()))
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (temKeystoreDeRelease) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        debug {
            buildConfigField(
                "String",
                "SUPABASE_URL",
                literalBuildConfig(supabaseUrlDev ?: "https://sem-configuracao.invalid"),
            )
            buildConfigField(
                "String",
                "SUPABASE_PUBLISHABLE_KEY",
                literalBuildConfig(supabaseChaveDev ?: "sem-configuracao"),
            )
            isMinifyEnabled = false
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.jvmArgs(
                "--add-opens=java.base/java.lang=ALL-UNNAMED",
                "--add-opens=java.base/java.util=ALL-UNNAMED",
                "--add-opens=java.base/java.io=ALL-UNNAMED",
                "--add-opens=java.base/java.net=ALL-UNNAMED",
                "--add-opens=java.base/java.security=ALL-UNNAMED",
                "--add-opens=java.base/java.text=ALL-UNNAMED",
                "--add-opens=java.base/jdk.internal.access=ALL-UNNAMED",
                "--add-opens=java.desktop/java.awt.font=ALL-UNNAMED",
                "--add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED",
            )
        }
        managedDevices {
            devices {
                maybeCreate<com.android.build.api.dsl.ManagedVirtualDevice>("pixel2api28").apply {
                    device = "Pixel 2"
                    apiLevel = 28
                    systemImageSource = "aosp"
                }
            }
        }
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
    implementation(project(":core:preferencias"))
    implementation(project(":core:rede"))
    implementation(project(":core:seguranca"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:notificacoes"))
    implementation(project(":core:localizacao"))
    implementation(project(":feature:entrada"))
    implementation(project(":feature:vagas"))
    implementation(project(":feature:turnos"))
    implementation(project(":feature:perfil"))
    implementation(project(":feature:conta"))
    implementation(project(":feature:suporte"))
    implementation(project(":feature:equipe"))
    implementation(project(":feature:estabelecimento"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    implementation(libs.lifecycle.viewmodel.ktx)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.androidx.datastore.preferences)

    implementation(libs.koin.core)
    implementation(libs.koin.android)
    implementation(libs.koin.androidx.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.ktor.client.core)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.play.services.location)
    implementation(libs.androidx.security.crypto)
    implementation(libs.androidx.biometric)
    implementation(libs.androidx.profileinstaller)
    baselineProfile(project(":baselineprofile"))

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(platform(libs.firebase.bom))
    testImplementation(libs.junit.jupiter.api)
    testImplementation(libs.junit.jupiter.params)
    testImplementation(libs.junit4)
    testRuntimeOnly(libs.junit.jupiter.engine)
    testRuntimeOnly(libs.junit.vintage.engine)
    testImplementation(libs.mockk)
    testImplementation(libs.koin.test)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.ktor.client.mock)
    testImplementation(libs.kotlinx.serialization.json)
    testImplementation(libs.robolectric)

    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso.core)
    androidTestImplementation(libs.junit4)
    androidTestImplementation(libs.ktor.client.mock)
    androidTestImplementation(libs.kotlinx.coroutines.test)
}

tasks.withType<Test> {
    useJUnitPlatform()
}
