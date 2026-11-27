package br.com.frila.app

import android.net.Uri

/** O toque num push: o `tipo` e os ids que o `ResolvedorDeDeepLinkPush` põe em `frila://aviso`. */
data class AvisoDoToque(
    val tipo: String,
    val vagaId: String? = null,
    val turnoId: String? = null,
    val posicaoId: String? = null,
    val chamadaId: String? = null,
)

/**
 * O aviso do link que a `EntradaDoAvisoActivity` (não exportada) pôs na `CaixaDoAvisoDoToque`. Nunca do Intent da
 * `MainActivity`: ela é exportada, e outro app consegue mandar um `frila://aviso` direto a ela.
 */
internal fun avisoDoLink(link: String?): AvisoDoToque? {
    val uri = link?.let(Uri::parse)?.takeIf { it.scheme == "frila" && it.host == HOST_DO_AVISO } ?: return null
    val tipo = uri.getQueryParameter("tipo")?.takeIf(String::isNotBlank) ?: return null
    return AvisoDoToque(
        tipo = tipo,
        vagaId = uri.getQueryParameter("vaga_id"),
        turnoId = uri.getQueryParameter("turno_id"),
        posicaoId = uri.getQueryParameter("posicao_id"),
        chamadaId = uri.getQueryParameter("chamada_id"),
    )
}

internal const val HOST_DO_AVISO = "aviso"

private val UUID_REGEX = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

private fun String?.uuid(): String? = this?.trim()?.takeIf { UUID_REGEX.matches(it) }

/**
 * A tela que o toque abre, pelo tipo e pelo papel da conta, como o `RoteadorDePush` do iOS (`DestinoDoProfissional`).
 * Nulo: não navega, e o app fica na raiz do papel. A casa nunca vai a tela do profissional: os avisos de vaga com
 * candidatos a ver abrem os candidatos da vaga ([rotaDaCasa]); o resto, Minhas vagas.
 */
internal fun rotaDoAviso(aviso: AvisoDoToque, papel: PapelDaRaiz): String? {
    // A situação da conta decide a tela, como na abertura do app; o `RoteadorDePush` do iOS reavalia a conta. Vale para
    // os dois papéis.
    if (aviso.tipo == "suspensao" || aviso.tipo == "reativacao") return Rotas.ABERTURA
    if (papel is PapelDaRaiz.Contratante) return rotaDaCasa(aviso, papel.estabelecimentoId) ?: papel.rotaDeMinhasVagas
    return when (aviso.tipo) {
        "vaga", "candidatura_recusada", "selecao_encerrada" -> aviso.vagaId.uuid()?.let(Rotas::detalhe)
        "confirmacao", "lembrete_24h", "lembrete_3h", "inicio_sem_checkin", "fim_sem_checkout", "turno_nao_verificado" ->
            aviso.turnoId.uuid()?.let(Rotas::turnoAviso)
        // O cancelamento nunca traz `turno_id`. Com `posicao_id`, a pessoa tinha a posição e o turno cancelado está em
        // Meus turnos; sem ele, era candidata de uma vaga recolhida.
        "cancelamento" -> if (aviso.posicaoId.uuid() != null) Rotas.MEUS_TURNOS else aviso.vagaId.uuid()?.let(Rotas::detalhe)
        "avaliacao_disponivel" -> aviso.turnoId.uuid()?.let(Rotas::avaliacao)
        "vagas_agrupadas" -> Rotas.FEED
        "chamada_recebida", "chamada_lembrete", "chamada_cancelada", "chamada_expirada", "chamada_encerrada" ->
            aviso.chamadaId.uuid()?.let(RotasChamadaProfissional::recebida)
        // Os da casa (`vaga_sem_elegiveis`, `atraso_15min`, `vaga_vazia`, `checkin`, `checkin_manual_pendente`,
        // `selecao_lembrete`, `chamada_aceita`, `chamada_recusada`, lembretes de fim de turno), `midia_recusada` e tipo
        // desconhecido não abrem tela.
        else -> null
    }
}

/**
 * O destino da casa, como o `AvisoDoContratante` do iOS (`.turno` e `.vaga`), onde o Android tem a tela: o turno da
 * casa em uso, achado pelo `turno_id` no painel dela, e os candidatos da vaga (`candidatos_da_vaga` só devolve
 * candidaturas pendentes). Vaga direta (`chamada_*`), seleção encerrada e os lembretes de fim de turno abririam a lista
 * vazia com "Ninguém se candidatou ainda", que ali é falso: ficam em Minhas vagas.
 */
private fun rotaDaCasa(aviso: AvisoDoToque, estabelecimentoId: String): String? = when (aviso.tipo) {
    "confirmacao", "lembrete_24h", "lembrete_3h", "fim_sem_checkout", "checkin", "checkin_manual_pendente", "atraso_15min" ->
        aviso.turnoId.uuid()?.let { Rotas.turnoDoContratanteAviso(estabelecimentoId, it) }
    // A avaliação da casa abre direto pelo turno (o iOS abre o turno, de onde a casa avalia).
    "avaliacao_disponivel" -> aviso.turnoId.uuid()?.let(Rotas::avaliacaoDoContratante)
    "vaga_sem_elegiveis", "vaga_vazia", "selecao_lembrete", "cancelamento" -> aviso.vagaId.uuid()?.let { Rotas.candidatosDaVaga(it) }
    else -> null
}
