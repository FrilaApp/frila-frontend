package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.UriHandler
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeNavegacao
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

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
    private const val TEXTO_APACHE_2: String = """                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS"""

    /**
     * Texto da SIL Open Font License 1.1, igual ao de `core/designsystem/src/main/res/raw/prodigy_sans_bold_ofl.txt`
     * (sem a linha de copyright, que muda por fonte). A Prodigy Sans é derivada da Work Sans.
     */
    private const val TEXTO_OFL_1_1: String = """
This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at:
http://scripts.sil.org/OFL


-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded, 
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE."""

    val licencas: List<LicencaDePacote> = listOf(
        LicencaDePacote(
            id = "kotlin",
            nome = "Kotlin Standard Library",
            versao = "2.0.20",
            tipo = "Apache-2.0",
            url = "https://github.com/JetBrains/kotlin",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2010-2024 JetBrains s.r.o. and Kotlin Programming Language contributors.",
        ),
        LicencaDePacote(
            id = "kotlinx-coroutines",
            nome = "Kotlinx Coroutines",
            versao = "1.8.1",
            tipo = "Apache-2.0",
            url = "https://github.com/Kotlin/kotlinx.coroutines",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2000-2024 JetBrains s.r.o. and Kotlin Programming Language contributors.",
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
            id = "material3",
            nome = "AndroidX Material 3",
            versao = "1.3.0",
            tipo = "Apache-2.0",
            url = "https://m3.material.io",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2021 The Android Open Source Project.",
        ),
        LicencaDePacote(
            id = "lifecycle",
            nome = "AndroidX Lifecycle",
            versao = "2.8.4",
            tipo = "Apache-2.0",
            url = "https://developer.android.com/jetpack/androidx/releases/lifecycle",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2017-2024 The Android Open Source Project.",
        ),
        LicencaDePacote(
            id = "navigation-compose",
            nome = "AndroidX Navigation Compose",
            versao = "2.8.3",
            tipo = "Apache-2.0",
            url = "https://developer.android.com/jetpack/androidx/releases/navigation",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2020-2024 The Android Open Source Project.",
        ),
        LicencaDePacote(
            id = "activity-compose",
            nome = "AndroidX Activity Compose",
            versao = "1.9.3",
            tipo = "Apache-2.0",
            url = "https://developer.android.com/jetpack/androidx/releases/activity",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright (C) 2020-2024 The Android Open Source Project.",
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
            id = "kotlinx-serialization",
            nome = "Kotlinx Serialization",
            versao = "1.7.1",
            tipo = "Apache-2.0",
            url = "https://github.com/Kotlin/kotlinx.serialization",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2017-2024 JetBrains s.r.o. and Kotlin Programming Language contributors.",
        ),
        LicencaDePacote(
            id = "firebase-messaging",
            nome = "Firebase Cloud Messaging",
            versao = "35.1.0",
            tipo = "Apache-2.0",
            url = "https://firebase.google.com/docs/cloud-messaging",
            texto = TEXTO_APACHE_2,
            aviso = "Copyright 2024 Google LLC.",
        ),
        LicencaDePacote(
            id = "prodigy-sans",
            nome = "Prodigy Sans",
            versao = "Bold",
            tipo = "OFL-1.1",
            url = "https://github.com/weiweihuanghuang/Work-Sans",
            texto = "Copyright 2020 The Prodigy Sans Project Authors (https://github.com/weiweihuanghuang/Work-Sans)\n" +
                TEXTO_OFL_1_1,
            aviso = "Fonte dos títulos e dos valores em destaque. Copyright 2020 The Prodigy Sans Project Authors.",
        ),
        LicencaDePacote(
            id = "work-sans",
            nome = "Work Sans (base da Prodigy Sans)",
            versao = "Bold",
            tipo = "OFL-1.1",
            url = "https://github.com/weiweihuanghuang/Work-Sans",
            texto = "Copyright 2019 The Work Sans Project Authors (https://github.com/weiweihuanghuang/Work-Sans)\n" +
                TEXTO_OFL_1_1,
            aviso = "Copyright 2019 The Work Sans Project Authors.",
        ),
    )
}


/**
 * Tela principal de lista de licenças de código aberto do app Frila (Cartão v1.2 / Paridade com `TelaLicencas.swift`).
 *
 * Tela de leitura (sem laranja): um grupo de linhas que abrem o detalhe de cada pacote, com versão e licença.
 */
@Composable
fun TelaLicencas(
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    catalogo: List<LicencaDePacote> = CatalogoLicencasAndroid.licencas,
) {
    var licencaSelecionada by remember { mutableStateOf<LicencaDePacote?>(null) }

    val aberta = licencaSelecionada
    if (aberta != null) {
        TelaDetalheLicenca(
            licenca = aberta,
            aoVoltar = { licencaSelecionada = null },
        )
    } else {
        Scaffold(
            modifier = modifier.fillMaxSize(),
            containerColor = FrilaTema.cores.fundo,
            topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        ) { paddingInterno ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingInterno)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = FrilaEspacamento.grupo)
                    .padding(top = FrilaEspacamento.item, bottom = FrilaEspacamento.grupo),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
            ) {
                TituloDaTela(TextosLicencas.TITULO)
                FrilaGrupoDeLinhas {
                    catalogo.forEach { licenca ->
                        linha {
                            FrilaLinhaDeNavegacao(
                                titulo = licenca.nome,
                                subtitulo = "${licenca.versao} · ${licenca.tipo}",
                                aoClicar = { licencaSelecionada = licenca },
                                modifier = Modifier.semantics {
                                    contentDescription =
                                        "${licenca.nome}, ${licenca.versao}, ${licenca.tipo}. ${TextosLicencas.DICA_ABRIR}"
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Detalhe com texto legal integral e avisos da licença (paridade com `TelaDetalheDaLicenca`). Leitura: o nome do
 * pacote é o título, versão, licença e repositório vão num cartão e o texto legal fica em apoio.
 */
@Composable
fun TelaDetalheLicenca(
    licenca: LicencaDePacote,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val abrirLink = LocalUriHandler.current

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(top = FrilaEspacamento.item, bottom = FrilaEspacamento.secao),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(licenca.nome)

            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    Text(
                        text = "${TextosLicencas.ROTULO_VERSAO}: ${licenca.versao}",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                    Text(
                        text = "${TextosLicencas.ROTULO_LICENCA}: ${licenca.tipo}",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                        Text(text = TextosLicencas.ROTULO_REPOSITORIO, style = FrilaTipo.apoio, color = cores.tintaSuave)
                        LinkFrila(
                            texto = licenca.url,
                            aoClicar = { abrirRepositorio(abrirLink, licenca.url) },
                            modifier = Modifier.semantics {
                                contentDescription = "${TextosLicencas.ROTULO_REPOSITORIO}: ${licenca.url}"
                            },
                        )
                    }
                }
            }

            licenca.aviso?.let { aviso ->
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosLicencas.ROTULO_AVISOS)
                    Text(text = aviso, style = FrilaTipo.apoio, color = cores.tintaSuave)
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosLicencas.ROTULO_TEXTO_LICENCA)
                CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                    Text(text = licenca.texto, style = FrilaTipo.apoio, color = cores.tinta)
                }
            }
        }
    }
}

/** Abre o repositório no navegador; sem navegador no aparelho, o toque não faz nada em vez de derrubar a tela. */
private fun abrirRepositorio(abridor: UriHandler, url: String) {
    try {
        abridor.openUri(url)
    } catch (_: Exception) {
        // Sem aplicativo para abrir o link: a URL segue escrita na tela.
    }
}
