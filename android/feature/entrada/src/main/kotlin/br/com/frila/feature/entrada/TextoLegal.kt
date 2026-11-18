package br.com.frila.feature.entrada

import androidx.compose.runtime.Composable
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import br.com.frila.core.designsystem.tema.FrilaTema

/** Onde os Termos de Uso e a Política de Privacidade moram (os mesmos endereços da folha "Ajuda" do Perfil). */
internal const val URL_TERMOS_DE_USO = "https://frilabr.com/termos"
internal const val URL_POLITICA_DE_PRIVACIDADE = "https://frilabr.com/privacidade"

/**
 * Frase legal com os dois links no meio: "[antes]Termos de Uso[conector]Política de Privacidade[depois]".
 * Os links vão em tinta e sublinhados, como o [br.com.frila.core.designsystem.componentes.LinkFrila]; abrem no
 * navegador. Componente do módulo: se outra tela precisar, sobe para o design system.
 */
@Composable
internal fun fraseComLinksLegais(
    antes: String,
    termos: String,
    conector: String,
    privacidade: String,
    depois: String,
): AnnotatedString {
    val estiloDoLink = TextLinkStyles(
        style = SpanStyle(color = FrilaTema.cores.tinta, textDecoration = TextDecoration.Underline),
    )
    return buildAnnotatedString {
        append(antes)
        withLink(LinkAnnotation.Url(URL_TERMOS_DE_USO, estiloDoLink)) { append(termos) }
        append(conector)
        withLink(LinkAnnotation.Url(URL_POLITICA_DE_PRIVACIDADE, estiloDoLink)) { append(privacidade) }
        append(depois)
    }
}
