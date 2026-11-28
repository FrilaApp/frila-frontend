package br.com.frila.feature.vagas.candidatos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ServicoNoPerfilDto

/**
 * O perfil rico no cartão do candidato, como o `blocoPerfilRico` do iOS (`CandidatosDaVaga.swift:568-640`), na mesma ordem e com
 * os mesmos cortes: serviços (resumo, inclusos e especialidades), apresentação em até 3 linhas, experiência e onde trabalhou (2
 * linhas), cursos (2 linhas), idiomas e regiões. Campo vazio não ocupa espaço. Os textos são os do perfil público do Android
 * (`TextosChamadaCasa`, em `:feature:chamadas`, que `:feature:vagas` não enxerga).
 */
@Composable
internal fun PerfilRicoDoCandidato(perfil: PerfilPublicoDto, candidaturaId: String) {
    val cores = FrilaTema.cores
    val servicos = perfil.servicos.orEmpty()
    if (servicos.isNotEmpty()) {
        Column(
            modifier = Modifier.testTag("servicos-do-candidato-$candidaturaId").semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
        ) {
            servicos.forEach { servico ->
                TextosPerfilRicoDoCandidato.resumoDoServico(servico)?.let {
                    Text(text = it, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
                }
                servico.inclui?.takeIf { it.isNotBlank() }?.let { Text(text = it, style = FrilaTipo.apoio, color = cores.tintaSuave) }
                servico.especialidades.orEmpty().takeIf { it.isNotEmpty() }?.let { especialidades ->
                    Text(text = especialidades.joinToString(", ") { it.nome }, style = FrilaTipo.apoio, color = cores.tintaSuave)
                }
            }
        }
    }

    perfil.apresentacao?.takeIf { it.isNotBlank() }?.let { apresentacao ->
        Text(
            text = apresentacao,
            style = FrilaTipo.corpo,
            color = cores.tinta,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.testTag("apresentacao-do-candidato-$candidaturaId"),
        )
    }

    val onde = perfil.ondeTrabalhei?.takeIf { it.isNotEmpty() }
    if (perfil.experienciaFaixa != null || onde != null) {
        Column(
            modifier = Modifier.testTag("experiencia-do-candidato-$candidaturaId").semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
        ) {
            perfil.experienciaFaixa?.let {
                Text(text = TextosPerfilRicoDoCandidato.experiencia(it), style = FrilaTipo.apoio, color = cores.tinta)
            }
            onde?.let { Text(text = it, style = FrilaTipo.apoio, color = cores.tintaSuave, maxLines = 2, overflow = TextOverflow.Ellipsis) }
        }
    }

    perfil.cursos?.takeIf { it.isNotEmpty() }?.let { cursos ->
        Text(
            text = cursos.joinToString(" • "),
            style = FrilaTipo.apoio,
            color = cores.tintaSuave,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.testTag("cursos-do-candidato-$candidaturaId"),
        )
    }

    perfil.idiomas?.takeIf { it.isNotEmpty() }?.let { idiomas ->
        Text(
            text = idiomas.joinToString(", ") { TextosPerfilRicoDoCandidato.idioma(it) },
            style = FrilaTipo.apoio,
            color = cores.tintaSuave,
            modifier = Modifier.testTag("idiomas-do-candidato-$candidaturaId"),
        )
    }

    val regioes = perfil.regioes.orEmpty()
    if (perfil.atendeTodoDf == true || regioes.isNotEmpty()) {
        Text(
            text = if (perfil.atendeTodoDf == true) TextosPerfilRicoDoCandidato.TODO_O_DF else regioes.joinToString(", ") { it.nome },
            style = FrilaTipo.apoio,
            color = cores.tintaSuave,
            modifier = Modifier.testTag("regioes-do-candidato-$candidaturaId"),
        )
    }
}

/** Os textos do perfil público (`TextosChamadaCasa` e `resumoDoServico` de `:feature:chamadas`; o iOS tem os mesmos). */
internal object TextosPerfilRicoDoCandidato {
    const val TODO_O_DF = "Atender em todo o DF"

    /** "R$ 150,00 por diária de 8 h", "R$ 40,00 • Hora" ou "A combinar". */
    fun resumoDoServico(servico: ServicoNoPerfilDto): String? {
        val valor = servico.valorCentavos
        return when {
            servico.unidade == "diaria" && valor != null && servico.horasIncluidas != null ->
                "${Dinheiro(valor).formatado()} por diária de ${servico.horasIncluidas} h"
            servico.unidade == "a_combinar" -> unidade("a_combinar")
            valor == null -> unidade(servico.unidade)
            else -> "${Dinheiro(valor).formatado()} • ${unidade(servico.unidade)}"
        }
    }

    fun unidade(unidade: String): String = when (unidade) {
        "hora" -> "Hora"
        "diaria" -> "Diária"
        "evento" -> "Evento"
        "pacote" -> "Pacote"
        "por_pessoa" -> "Por pessoa"
        "a_combinar" -> "A combinar"
        else -> unidade
    }

    fun experiencia(faixa: String): String = when (faixa) {
        "menos_de_1_ano" -> "Menos de 1 ano"
        "de_1_a_3_anos" -> "1 a 3 anos"
        "de_3_a_5_anos" -> "3 a 5 anos"
        "de_5_a_10_anos" -> "5 a 10 anos"
        "mais_de_10_anos" -> "Mais de 10 anos"
        else -> faixa
    }

    fun idioma(idioma: String): String = when (idioma) {
        "portugues" -> "Português"
        "ingles" -> "Inglês"
        "espanhol" -> "Espanhol"
        "libras" -> "Libras"
        "outro" -> "Outro"
        else -> idioma
    }
}
