// Shell da aplicação: navegação Compose, grafo Koin, Application e Activity únicos.
// Cartões Trello YRGYz50G e iWYMOk5C.
import java.util.Base64
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.baselineprofile)
}

// C0-10 (push): o plugin do Google Services só entra com o google-services.json presente (fica fora do git, ver
// .gitignore). O debug usa o do DEV (src/debug/) e o release o do PROD (src/release/). Sem o arquivo, como na CI, o app
// compila sem Firebase: o registro do aparelho só não acontece.
if (file("src/debug/google-services.json").exists() || file("src/release/google-services.json").exists()) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
    // L1-6: o mesmo critério. A coleta do Crashlytics fica DESLIGADA no manifesto; o plugin só gera o ID do build e envia o mapeamento do R8.
    apply(plugin = libs.plugins.firebase.crashlytics.plugin.get().pluginId)
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

// Supabase (pedido 16-26): a URL e a chave PUBLICÁVEL vão para o BuildConfig. Debug = par DEV,
// release = par PROD. Fonte: variável de ambiente ou android/local.properties (ignorado pelo Git).
// Nenhum valor é impresso: as mensagens citam só o nome da variável. A regra da chave proibida é a
// mesma de ConfiguracaoSupabase.kt (mude as duas juntas; os testes unitários cobrem a de lá).
val propriedadesLocais = Properties().apply {
    val arquivo = rootProject.file("local.properties")
    if (arquivo.isFile) arquivo.inputStream().use { load(it) }
}

fun valorDoSupabase(nome: String): String =
    System.getenv(nome)?.trim()?.takeIf { it.isNotEmpty() } ?: propriedadesLocais.getProperty(nome)?.trim().orEmpty()

fun problemasDoParSupabase(ambiente: String, url: String, chave: String): List<String> {
    val nomeUrl = "FRILA_SUPABASE_${ambiente}_URL"
    val nomeChave = "FRILA_SUPABASE_${ambiente}_PUBLISHABLE_KEY"
    val cargaDoJwt = chave.split('.').takeIf { it.size == 3 }?.let { partes ->
        runCatching { String(Base64.getUrlDecoder().decode(partes[1].trimEnd('='))) }.getOrNull()
    }
    return listOfNotNull(
        when {
            url.isEmpty() -> "$nomeUrl ausente"
            url.startsWith("TODO", ignoreCase = true) -> "$nomeUrl é placeholder (TODO)"
            !url.startsWith("https://") -> "$nomeUrl não usa https"
            else -> null
        },
        when {
            chave.isEmpty() -> "$nomeChave ausente"
            chave.startsWith("TODO", ignoreCase = true) -> "$nomeChave é placeholder (TODO)"
            chave.startsWith("sb_secret_") -> "$nomeChave é chave secreta (sb_secret_); use a publicável"
            cargaDoJwt != null && Regex("\"role\"\\s*:\\s*\"service_role\"").containsMatchIn(cargaDoJwt) ->
                "$nomeChave é um JWT com role service_role; use a publicável"
            else -> null
        },
    )
}

fun literalJava(valor: String): String = "\"" + valor.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

/** Host que nunca resolve (RFC 2606): o debug sem o par DEV compila e o app avisa no log. */
val urlSupabaseSemConfiguracao = "https://supabase-nao-configurado.invalid"
val supabaseDevUrl = valorDoSupabase("FRILA_SUPABASE_DEV_URL")
val supabaseDevChave = valorDoSupabase("FRILA_SUPABASE_DEV_PUBLISHABLE_KEY")
val supabaseProdUrl = valorDoSupabase("FRILA_SUPABASE_PROD_URL")
val supabaseProdChave = valorDoSupabase("FRILA_SUPABASE_PROD_PUBLISHABLE_KEY")
// Debug: sem o par DEV, compila sem servidor; com o par (mesmo só metade), ele tem de valer. Release:
// sempre exige o par PROD válido. As checagens rodam só nas tarefas do próprio tipo de build, então
// testes e builds de debug não dependem do par PROD.
val parDevAusente = supabaseDevUrl.isEmpty() && supabaseDevChave.isEmpty()
val problemasDoSupabaseDebug =
    if (parDevAusente) emptyList() else problemasDoParSupabase("DEV", supabaseDevUrl, supabaseDevChave)
val problemasDoSupabaseRelease = problemasDoParSupabase("PROD", supabaseProdUrl, supabaseProdChave)

val conferirSupabaseDoDebug = tasks.register("conferirSupabaseDoDebug") {
    description = "Recusa um par DEV do Supabase incompleto ou com chave proibida (sem imprimir valores)."
    val problemas = problemasDoSupabaseDebug
    doLast {
        if (problemas.isNotEmpty()) {
            throw GradleException(
                "Supabase do debug (par DEV): ${problemas.joinToString("; ")}. Corrija a variável de ambiente ou " +
                    "android/local.properties, ou tire as duas para compilar sem servidor.",
            )
        }
    }
}
val conferirSupabaseDoRelease = tasks.register("conferirSupabaseDoRelease") {
    description = "Falha o release sem o par PROD do Supabase ou com chave proibida (sem imprimir valores)."
    val problemas = problemasDoSupabaseRelease
    doLast {
        if (problemas.isNotEmpty()) {
            throw GradleException(
                "Supabase do release (par PROD): ${problemas.joinToString("; ")}. Defina FRILA_SUPABASE_PROD_URL e " +
                    "FRILA_SUPABASE_PROD_PUBLISHABLE_KEY por variável de ambiente ou em android/local.properties.",
            )
        }
    }
}
tasks.matching { it.name == "preDebugBuild" }.configureEach { dependsOn(conferirSupabaseDoDebug) }
// Inclui os tipos de release do plugin de baseline profile (nonMinifiedRelease, benchmarkRelease).
tasks.matching { it.name.startsWith("pre") && it.name.endsWith("ReleaseBuild") }
    .configureEach { dependsOn(conferirSupabaseDoRelease) }

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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (temKeystoreDeRelease) {
                signingConfig = signingConfigs.getByName("release")
            }
            buildConfigField("String", "SUPABASE_URL", literalJava(supabaseProdUrl))
            buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", literalJava(supabaseProdChave))
        }
        debug {
            isMinifyEnabled = false
            buildConfigField("String", "SUPABASE_URL", literalJava(supabaseDevUrl.ifEmpty { urlSupabaseSemConfiguracao }))
            buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", literalJava(supabaseDevChave))
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
    implementation(project(":feature:chamadas"))

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
    implementation(libs.firebase.crashlytics)

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
