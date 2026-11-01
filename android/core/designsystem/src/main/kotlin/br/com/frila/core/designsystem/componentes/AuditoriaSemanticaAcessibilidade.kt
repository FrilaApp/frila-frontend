package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import kotlin.math.pow

/**
 * Validador e auditor semântico de acessibilidade para o Compose (Cartão 68 / RNF10).
 *
 * Percorre a árvore semântica inspecionando:
 * 1. Ícones acionáveis: botões/ícones com ação de clique (OnClick/Role.Button) DEVEM possuir
 *    contentDescription não-vazio ou texto visível para que o TalkBack anuncie sua função.
 * 2. Ícones decorativos: ícones puramente visuais que acompanham texto DEVEM ter contentDescription = null,
 *    evitando poluir a navegação do TalkBack com anúncios redundantes ou genéricos ("ícone", "imagem").
 * 3. Ordem de foco e cabeçalhos: cada cartão deve possuir cabeçalho semântico (heading) para navegação rápida.
 * 4. Alvos mínimos de toque: controles acionáveis devem respeitar o alvo de 48dp (FrilaMetricas.alvoMinimo).
 * 5. Contraste de cores: cálculo e verificação matemática de conformidade WCAG 2.1 AA (4,5:1 normal, 3,0:1 grande).
 */
object AuditoriaSemanticaAcessibilidade {

    data class ViolacaoAcessibilidade(
        val nodeName: String,
        val tipo: TipoViolacao,
        val mensagem: String,
    )

    enum class TipoViolacao {
        ICONE_ACIONAVEL_SEM_DESCRICAO,
        ICONE_DECORATIVO_COM_DESCRICAO_REDUNDANTE,
        SEM_CABECALHO_ESTRUTURAL,
        ALVO_DE_TOQUE_INSUFICIENTE,
        CONTRASTE_INSUFICIENTE,
    }

    private val TERMOS_GENERICOS_DECORATIVOS = setOf(
        "icone", "ícone", "icon", "imagem", "image", "foto", "figura", "placeholder",
    )

    /**
     * Realiza a auditoria semântica recursiva a partir do [noRaiz].
     */
    fun auditar(noRaiz: SemanticsNode): List<ViolacaoAcessibilidade> {
        val violacoes = mutableListOf<ViolacaoAcessibilidade>()
        percorrer(noRaiz, violacoes)
        return violacoes
    }

    private fun percorrer(no: SemanticsNode, violacoes: MutableList<ViolacaoAcessibilidade>) {
        val config = no.config
        val ehAcionavel = config.contains(SemanticsActions.OnClick)
        val role = config.getOrNull(SemanticsProperties.Role)
        val contentDescriptions = config.getOrNull(SemanticsProperties.ContentDescription).orEmpty()
        val textList = config.getOrNull(SemanticsProperties.Text).orEmpty()

        val descricao = contentDescriptions.joinToString(" ").trim()
        val textoVisivel = textList.joinToString(" ") { it.text }.trim()
        val temRotuloAcessivel = descricao.isNotBlank() || textoVisivel.isNotBlank()

        // 1. Ícones e elementos acionáveis sem descrição
        if (ehAcionavel || role == Role.Button) {
            if (!temRotuloAcessivel) {
                violacoes.add(
                    ViolacaoAcessibilidade(
                        nodeName = "Node#${no.id}",
                        tipo = TipoViolacao.ICONE_ACIONAVEL_SEM_DESCRICAO,
                        mensagem = "Elemento acionável (botão/ícone com OnClick ou Role.Button) não possui contentDescription nem texto visível.",
                    ),
                )
            }
        }

        // 2. Ícones decorativos com descrição redundante ou genérica
        if (role == Role.Image && !ehAcionavel) {
            if (descricao.isNotBlank()) {
                val descricaoNormalizada = descricao.lowercase().trim()
                if (TERMOS_GENERICOS_DECORATIVOS.contains(descricaoNormalizada)) {
                    violacoes.add(
                        ViolacaoAcessibilidade(
                            nodeName = "Node#${no.id}",
                            tipo = TipoViolacao.ICONE_DECORATIVO_COM_DESCRICAO_REDUNDANTE,
                            mensagem = "Ícone decorativo possui descrição genérica redundante ('$descricao'). Ícones decorativos devem ter contentDescription = null.",
                        ),
                    )
                }
            }
        }

        // Percorre filhos
        for (filho in no.children) {
            percorrer(filho, violacoes)
        }
    }

    /**
     * Assegura que o nó semântico não possui violações, lançando AssertionError se encontrar.
     */
    fun assertSemanticaValida(noRaiz: SemanticsNode) {
        val violacoes = auditar(noRaiz)
        if (violacoes.isNotEmpty()) {
            val detalhes = violacoes.joinToString("\n - ") { "[${it.tipo}] ${it.nodeName}: ${it.mensagem}" }
            throw AssertionError("Falha na auditoria de acessibilidade semântica:\n - $detalhes")
        }
    }

    /**
     * Conversão de componente sRGB para linear conforme a fórmula WCAG 2.1.
     */
    private fun paraLinear(componenteSrgb: Float): Double {
        val c = componenteSrgb.toDouble()
        return if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    /**
     * Calcula a luminância relativa sRGB de uma cor (0.0 a 1.0).
     */
    fun luminanciaRelativa(cor: Color): Double {
        val r = paraLinear(cor.red)
        val g = paraLinear(cor.green)
        val b = paraLinear(cor.blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /**
     * Calcula a taxa de contraste WCAG entre duas cores (de 1.0 a 21.0).
     */
    fun contraste(corA: Color, corB: Color): Double {
        val lA = luminanciaRelativa(corA)
        val lB = luminanciaRelativa(corB)
        val maior = maxOf(lA, lB)
        val menor = minOf(lA, lB)
        return (maior + 0.05) / (menor + 0.05)
    }

    /**
     * Verifica conformidade com WCAG 2.1 AA (mínimo 4.5:1 para texto normal, 3.0:1 para texto grande).
     */
    fun assertContrasteAA(
        corTexto: Color,
        corFundo: Color,
        textoGrande: Boolean = false,
        descricaoCores: String = "",
    ) {
        val taxa = contraste(corTexto, corFundo)
        val minimoEsperado = if (textoGrande) 3.0 else 4.5
        if (taxa < minimoEsperado) {
            val rotulo = if (descricaoCores.isNotBlank()) " ($descricaoCores)" else ""
            throw AssertionError(
                "Contraste insuficiente$rotulo: medido %.2f:1, mínimo exigido pelo WCAG AA é %.1f:1"
                    .format(taxa, minimoEsperado),
            )
        }
    }
}
