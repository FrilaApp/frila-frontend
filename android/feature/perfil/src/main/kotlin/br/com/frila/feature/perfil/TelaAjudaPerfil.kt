package br.com.frila.feature.perfil

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/**
 * Endereços oficiais e canais institucionais do Frila
 * (paridade com `EnderecosOficiais.swift` e `TelaAjudaPerfil.swift`).
 */
data class EnderecosOficiais(
    val termosDeUso: String = "https://frila.netlify.app/termos",
    val politicaDePrivacidade: String = "https://frila.netlify.app/privacidade",
    val emailSuporte: String = "suporte@frilabr.com",
) {
    val urlSuporte: String get() = "mailto:$emailSuporte"

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
@OptIn(ExperimentalMaterial3Api::class)
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
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosAjudaPerfil.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosAjudaPerfil.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
        ) {
            ItemSuporte(
                enderecos = enderecos,
                aoAbrirEmail = { aoAbrirEmailSuporte?.invoke(enderecos.emailSuporte) },
            )

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant,
                modifier = Modifier.padding(vertical = FrilaEspacamento.minimo),
            )

            ItemNavegavelAjuda(
                titulo = TextosAjudaPerfil.TERMOS_DE_USO,
                descricaoAcessibilidade = TextosAjudaPerfil.DICA_TERMOS,
                aoClicar = { aoNavegarParaTermos?.invoke(enderecos.termosDeUso) },
            )

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant,
                modifier = Modifier.padding(vertical = FrilaEspacamento.minimo),
            )

            ItemNavegavelAjuda(
                titulo = TextosAjudaPerfil.POLITICA_PRIVACIDADE,
                descricaoAcessibilidade = TextosAjudaPerfil.DICA_PRIVACIDADE,
                aoClicar = { aoNavegarParaPrivacidade?.invoke(enderecos.politicaDePrivacidade) },
            )

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant,
                modifier = Modifier.padding(vertical = FrilaEspacamento.minimo),
            )

            ItemNavegavelAjuda(
                titulo = TextosAjudaPerfil.LICENCAS_TERCEIROS,
                descricaoAcessibilidade = TextosAjudaPerfil.DICA_LICENCAS,
                aoClicar = { aoNavegarParaLicencas?.invoke() },
            )
        }
    }
}

@Composable
private fun ItemSuporte(
    enderecos: EnderecosOficiais,
    aoAbrirEmail: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = FrilaEspacamento.minimo),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                .clickable(
                    role = Role.Button,
                    onClickLabel = TextosAjudaPerfil.SUPORTE_DICA,
                    onClick = aoAbrirEmail,
                )
                .padding(vertical = FrilaEspacamento.pequeno),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = TextosAjudaPerfil.SUPORTE_TITULO,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Icon(
                imageVector = Icons.Default.Email,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Text(
            text = enderecos.emailSuporte,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .fillMaxWidth()
                .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                .clickable(
                    role = Role.Button,
                    onClickLabel = TextosAjudaPerfil.SUPORTE_DICA,
                    onClick = aoAbrirEmail,
                )
                .padding(vertical = FrilaEspacamento.pequeno)
                .semantics {
                    contentDescription = "${TextosAjudaPerfil.SUPORTE_ROTULO_EMAIL}: ${enderecos.emailSuporte}"
                },
        )

        Text(
            text = TextosAjudaPerfil.SUPORTE_PRAZO,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = FrilaEspacamento.pequeno),
        )
    }
}

@Composable
private fun ItemNavegavelAjuda(
    titulo: String,
    descricaoAcessibilidade: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .clickable(
                role = Role.Button,
                onClickLabel = descricaoAcessibilidade,
                onClick = aoClicar,
            )
            .padding(vertical = FrilaEspacamento.pequeno),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = titulo,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
