package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeNavegacao
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Endereços oficiais e canais institucionais do Frila
 * (paridade com `EnderecosOficiais.swift` e `TelaAjudaPerfil.swift`).
 */
data class EnderecosOficiais(
    val termosDeUso: String = "https://frilabr.com/termos",
    val politicaDePrivacidade: String = "https://frilabr.com/privacidade",
    val emailSuporte: String = "suporte@frilabr.com",
    /** Onde a web mora (`frilabr.com/app`): o link do convite de membro da casa sai daqui. */
    val origemDaWeb: String = "https://frilabr.com/app",
) {
    val urlSuporte: String get() = "mailto:$emailSuporte"

    /** O link que o administrador compartilha: `<origem>/convite#<token>`. O token vai no fragmento, que o navegador não manda ao servidor. */
    fun linkDoConvite(token: String): String = "$origemDaWeb/convite#$token"

    companion object {
        val padrao = EnderecosOficiais()
    }
}

/** Textos normativos em português brasileiro (guia de voz Frila / paridade iOS). */
object TextosAjudaPerfil {
    const val TITULO = "Ajuda"
    const val ROTULO_VOLTAR = "Voltar"
    const val SUPORTE_TITULO = "Fale com o suporte"
    const val SUPORTE_DICA = "Abre o e-mail para enviar mensagem ao suporte"
    const val SUPORTE_ROTULO_EMAIL = "E-mail de suporte"
    const val SUPORTE_PRAZO = "Respondemos o mais breve possível, com triagem em até 5 dias úteis."
    const val TERMOS_DE_USO = "Termos de uso"
    const val DICA_TERMOS = "Abre os termos de uso do Frila"
    const val POLITICA_PRIVACIDADE = "Política de privacidade"
    const val DICA_PRIVACIDADE = "Abre a política de privacidade do Frila"
    const val LICENCAS_TERCEIROS = "Licenças de código aberto"
    const val DICA_LICENCAS = "Abre as licenças de código aberto das bibliotecas utilizadas"
}

/**
 * Tela de Ajuda e Suporte do Perfil (Tela 38 do mapa de paridade v1.2 / `TelaAjudaPerfil.swift:548`).
 * Apresenta o canal de suporte oficial por e-mail com SLA de triagem, links para Termos de Uso e
 * Política de Privacidade, e atalho para o catálogo de licenças de terceiros.
 */
@Composable
fun TelaAjudaPerfil(
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    enderecos: EnderecosOficiais = EnderecosOficiais.padrao,
    aoNavegarParaTermos: ((String) -> Unit)? = null,
    aoNavegarParaPrivacidade: ((String) -> Unit)? = null,
    aoAbrirEmailSuporte: ((String) -> Unit)? = null,
    aoNavegarParaLicencas: (() -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    val abrirEmail = { aoAbrirEmailSuporte?.invoke(enderecos.emailSuporte) ?: Unit }
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { BarraDeTopoDoPerfil(aoVoltar = aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosAjudaPerfil.TITULO)

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                FrilaGrupoDeLinhas {
                    linha {
                        FrilaLinhaDeNavegacao(
                            titulo = TextosAjudaPerfil.SUPORTE_TITULO,
                            aoClicar = abrirEmail,
                            rotuloDaAcao = TextosAjudaPerfil.SUPORTE_DICA,
                        )
                    }
                }
                LinkFrila(
                    texto = enderecos.emailSuporte,
                    aoClicar = abrirEmail,
                    modifier = Modifier.semantics {
                        contentDescription = "${TextosAjudaPerfil.SUPORTE_ROTULO_EMAIL}: ${enderecos.emailSuporte}"
                    },
                )
                Text(text = TextosAjudaPerfil.SUPORTE_PRAZO, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }

            FrilaGrupoDeLinhas {
                linha {
                    FrilaLinhaDeNavegacao(
                        titulo = TextosAjudaPerfil.TERMOS_DE_USO,
                        aoClicar = { aoNavegarParaTermos?.invoke(enderecos.termosDeUso) },
                        rotuloDaAcao = TextosAjudaPerfil.DICA_TERMOS,
                    )
                }
                linha {
                    FrilaLinhaDeNavegacao(
                        titulo = TextosAjudaPerfil.POLITICA_PRIVACIDADE,
                        aoClicar = { aoNavegarParaPrivacidade?.invoke(enderecos.politicaDePrivacidade) },
                        rotuloDaAcao = TextosAjudaPerfil.DICA_PRIVACIDADE,
                    )
                }
                linha {
                    FrilaLinhaDeNavegacao(
                        titulo = TextosAjudaPerfil.LICENCAS_TERCEIROS,
                        aoClicar = { aoNavegarParaLicencas?.invoke() },
                        rotuloDaAcao = TextosAjudaPerfil.DICA_LICENCAS,
                    )
                }
            }
        }
    }
}
