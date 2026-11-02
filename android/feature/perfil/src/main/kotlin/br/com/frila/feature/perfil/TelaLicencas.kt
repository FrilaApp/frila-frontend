package br.com.frila.feature.perfil

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios

/**
 * Modelo de dados de licença de dependência de código aberto (paridade com `TelaLicencas.swift`).
 */
data class LicencaDePacote(
    val id: String,
    val nome: String,
    val versao: String,
    val tipo: String,
    val url: String,
    val texto: String,
    val aviso: String? = null,
)

/** Textos normativos em português brasileiro (guia de voz Frila). */
object TextosLicencas {
    const val TITULO = "Licenças de código aberto"
    const val ROTULO_VOLTAR = "Voltar"
    const val ROTULO_VERSAO = "Versão"
    const val ROTULO_LICENCA = "Licença"
    const val ROTULO_REPOSITORIO = "Repositório"
    const val ROTULO_TEXTO_LICENCA = "Texto da licença"
    const val ROTULO_AVISOS = "Avisos do pacote"
    const val DICA_ABRIR = "Abre o texto da licença"
}

/** Catálogo de licenças das dependências em produção no Android do Frila. */
object CatalogoLicencasAndroid {
    private const val TEXTO_APACHE_2: String = """Copyright 2026 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License."""

    val licencas: List<LicencaDePacote> = listOf(
        LicencaDePacote(
            id = "kotlin",
            nome = "Kotlin Standard Library & Coroutines",
            versao = "2.0.20",
            tipo = "Apache-2.0",
            url = "https://github.com/JetBrains/kotlin",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2010-2024 JetBrains s.r.o. and Kotlin Programming Language contributors.",
        ),
        LicencaDePacote(
            id = "jetpack-compose",
            nome = "AndroidX Jetpack Compose",
            versao = "2024.09.00",
            tipo = "Apache-2.0",
            url = "https://developer.android.com/jetpack/compose",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2019-2024 The Android Open Source Project.",
        ),
        LicencaDePacote(
            id = "ktor",
            nome = "Ktor Client",
            versao = "2.3.12",
            tipo = "Apache-2.0",
            url = "https://github.com/ktorio/ktor",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2014-2024 JetBrains s.r.o. and contributors.",
        ),
        LicencaDePacote(
            id = "koin",
            nome = "Koin Dependency Injection",
            versao = "3.5.6",
            tipo = "Apache-2.0",
            url = "https://github.com/InsertKoinIO/koin",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2017-2024 Arnaud Giuliani and Koin contributors.",
        ),
        LicencaDePacote(
            id = "datastore",
            nome = "AndroidX Preferences DataStore",
            versao = "1.1.1",
            tipo = "Apache-2.0",
            url = "https://developer.android.com/topic/libraries/architecture/datastore",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2020 The Android Open Source Project.",
        ),
        LicencaDePacote(
            id = "material3",
            nome = "AndroidX Material 3",
            versao = "1.3.0",
            tipo = "Apache-2.0",
            url = "https://m3.material.io",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2021 The Android Open Source Project.",
        ),
    )
}

/**
 * Tela principal de lista de licenças de código aberto do app Frila (Cartão v1.2 / Paridade com `TelaLicencas.swift`).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaLicencas(
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    catalogo: List<LicencaDePacote> = CatalogoLicencasAndroid.licencas,
) {
    var licencaSelecionada by remember { mutableStateOf<LicencaDePacote?>(null) }

    if (licencaSelecionada != null) {
        TelaDetalheLicenca(
            licenca = licencaSelecionada!!,
            aoVoltar = { licencaSelecionada = null },
        )
    } else {
        Scaffold(
            modifier = modifier.fillMaxSize(),
            topBar = {
                CenterAlignedTopAppBar(
                    title = {
                        Text(
                            text = TextosLicencas.TITULO,
                            style = MaterialTheme.typography.titleLarge,
                            modifier = Modifier.semantics { heading() },
                        )
                    },
                    navigationIcon = {
                        IconButton(
                            onClick = aoVoltar,
                            modifier = Modifier
                                .sizeIn(
                                    minWidth = FrilaMetricas.alvoMinimo,
                                    minHeight = FrilaMetricas.alvoMinimo,
                                )
                                .semantics { contentDescription = TextosLicencas.ROTULO_VOLTAR },
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = null,
                            )
                        }
                    },
                )
            },
        ) { paddingInterno ->
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingInterno)
                    .background(MaterialTheme.colorScheme.background),
            ) {
                items(catalogo, key = { it.id }) { licenca ->
                    ItemLicenca(
                        licenca = licenca,
                        aoClicar = { licencaSelecionada = licenca },
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = FrilaEspacamento.medio),
                        color = MaterialTheme.colorScheme.outlineVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun ItemLicenca(
    licenca: LicencaDePacote,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .clickable(onClick = aoClicar)
            .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.compacto)
            .semantics {
                contentDescription = "${licenca.nome}, ${licenca.versao}, ${licenca.tipo}. ${TextosLicencas.DICA_ABRIR}"
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio),
        ) {
            Text(
                text = licenca.nome,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = "${licenca.versao} · ${licenca.tipo}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/**
 * Detalhe com texto legal integral e avisos da licença (paridade com `TelaDetalheDaLicenca`).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaDetalheLicenca(
    licenca: LicencaDePacote,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = licenca.nome,
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier
                            .sizeIn(
                                minWidth = FrilaMetricas.alvoMinimo,
                                minHeight = FrilaMetricas.alvoMinimo,
                            )
                            .semantics { contentDescription = TextosLicencas.ROTULO_VOLTAR },
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = null,
                        )
                    }
                },
            )
        },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.surfaceVariant,
                shape = RoundedCornerShape(FrilaRaios.medio),
            ) {
                Column(
                    modifier = Modifier.padding(FrilaEspacamento.medio),
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio),
                ) {
                    Text(
                        text = "${TextosLicencas.ROTULO_VERSAO}: ${licenca.versao}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "${TextosLicencas.ROTULO_LICENCA}: ${licenca.tipo}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "${TextosLicencas.ROTULO_REPOSITORIO}: ${licenca.url}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            licenca.aviso?.let { aviso ->
                Text(
                    text = TextosLicencas.ROTULO_AVISOS,
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    text = aviso,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = TextosLicencas.ROTULO_TEXTO_LICENCA,
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { heading() },
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        color = MaterialTheme.colorScheme.surfaceContainerLowest,
                        shape = RoundedCornerShape(FrilaRaios.pequeno),
                    )
                    .padding(FrilaEspacamento.compacto),
            ) {
                Text(
                    text = licenca.texto,
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            Spacer(modifier = Modifier.height(FrilaEspacamento.grande))
        }
    }
}
