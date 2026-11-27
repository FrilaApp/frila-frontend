package br.com.frila.feature.equipe.casa

import br.com.frila.core.dominio.modelo.PapelMembro
import java.util.Locale

/** Textos da equipe da casa, do convite e da troca de casa (pedido 18-02; paridade de conteúdo com `contratante-membros.ts` da web). */
object TextosEquipeDaCasa {
    // Entradas (Perfil)
    const val ENTRADA_EQUIPE = "Equipe da casa"
    const val ENTRADA_CONVITE = "Tenho um convite"
    const val ENTRADA_TROCAR = "Trocar de casa"

    // Equipe da casa
    const val TITULO = "Equipe da casa"
    const val ROTULO_VOLTAR = "Voltar"
    const val EXPLICACAO = "Quem você convidar entra com o próprio e-mail e passa a usar o Frila por esta casa, como administrador ou operador."
    const val SO_ADMINISTRADOR = "Só o administrador da casa gerencia as pessoas."
    const val CARREGANDO = "Carregando as pessoas da casa…"
    const val LISTA = "Quem faz parte da casa"
    const val VAZIA = "Nenhuma pessoa na lista da casa."
    const val VOCE = "Você"
    const val DESDE = "Desde %s"

    const val PAPEL_ADMINISTRADOR = "Administrador"
    const val PAPEL_OPERADOR = "Operador"

    // Convidar
    const val CONVIDAR = "Convidar alguém"
    const val EMAIL = "E-mail de quem você vai convidar"
    const val PAPEL = "Papel"
    const val GERAR_CONVITE = "Gerar convite"
    const val GERANDO = "Gerando…"
    const val CONVITE_PRONTO = "Convite pronto. Mande o link à pessoa. Ele vale uma vez, até %s."
    const val CONVITE_PRONTO_SEM_PRAZO = "Convite pronto. Mande o link à pessoa. Ele vale uma vez."
    const val CONVITE_PARA = "Convite para %s"
    const val LINK_DO_CONVITE = "Link do convite"
    const val COMPARTILHAR = "Compartilhar convite"
    const val COMPARTILHAR_TITULO = "Convite para a casa no Frila"
    private const val COMPARTILHAR_POLITICA =
        "O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. Política de Privacidade: https://frilabr.com/privacidade"
    const val COMPARTILHAR_MENSAGEM_COM_PRAZO =
        "%s convidou você para a equipe da casa no Frila, como %s. Para aceitar, abra o link abaixo e entre no Frila com o e-mail %s. O convite vale uma vez, até %s. $COMPARTILHAR_POLITICA\n%s"
    const val COMPARTILHAR_MENSAGEM_SEM_PRAZO =
        "%s convidou você para a equipe da casa no Frila, como %s. Para aceitar, abra o link abaixo e entre no Frila com o e-mail %s. O convite vale uma vez. $COMPARTILHAR_POLITICA\n%s"

    /** Monta a mensagem compartilhada do convite (com ou sem prazo, papel em minúsculo, e-mail aparado e link na última linha). */
    fun mensagemDoConvite(
        casa: String?,
        papel: PapelMembro,
        email: String,
        prazo: String?,
        link: String,
    ): String {
        val nomeDaCasa = casa?.trim()?.takeIf { it.isNotEmpty() } ?: "A casa"
        val papelTexto = papel.chave.lowercase(Locale.forLanguageTag("pt-BR"))
        val emailAparado = email.trim()
        val prazoAparado = prazo?.trim()?.takeIf { it.isNotEmpty() }
        val linkAparado = link.trim()
        return if (prazoAparado != null) {
            COMPARTILHAR_MENSAGEM_COM_PRAZO.format(nomeDaCasa, papelTexto, emailAparado, prazoAparado, linkAparado)
        } else {
            COMPARTILHAR_MENSAGEM_SEM_PRAZO.format(nomeDaCasa, papelTexto, emailAparado, linkAparado)
        }
    }

    // Ações sobre a pessoa
    const val REMOVER = "Remover"
    const val REMOVER_DE = "Remover %s"
    const val TRANSFERIR = "Tornar administrador"
    const val TRANSFERIR_DE = "Tornar %s administrador"
    const val CONFIRMAR_REMOCAO = "Remover esta pessoa?"
    const val EFEITO_REMOCAO = "%s deixará de ter acesso a esta casa."
    const val CONFIRMAR_TRANSFERENCIA = "Tornar administrador?"
    const val EFEITO_TRANSFERENCIA = "%s poderá administrar a casa. Seu acesso não é removido por esta ação."
    const val CONFIRMAR = "Confirmar"
    const val CANCELAR = "Cancelar"
    const val REMOVIDA = "Pessoa removida da casa."
    const val TRANSFERIDA = "A pessoa agora é administradora da casa."

    // Erros (do campo e da ação)
    const val EMAIL_INVALIDO = "Informe um e-mail válido."
    const val PAPEL_INVALIDO = "Escolha o papel."
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Não é possível gerenciar as pessoas da casa agora."
    const val INDISPONIVEL = "Esta casa ou pessoa não está mais disponível. Reabra a lista."
    const val ULTIMO_ADMINISTRADOR = "Não é possível remover o último administrador. Torne outra pessoa administradora antes."
    const val SESSAO = "Sua sessão expirou. Entre de novo."
    const val SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO = "Não foi possível concluir agora. Tente novamente."
    const val ERRO_DA_LISTA = "Não foi possível ler as pessoas da casa."
    const val TENTAR_NOVAMENTE = "Tentar novamente"

    // Tenho um convite
    const val CONVITE_TITULO = "Tenho um convite"
    const val CONVITE_EXPLICACAO = "Cole aqui o link do convite que você recebeu."
    const val CONVITE_CAMPO = "Link ou código do convite"
    const val CONVITE_ACEITAR = "Aceitar convite"
    const val CONVITE_ACEITANDO = "Aceitando…"
    const val CONVITE_ACEITO_TITULO = "Convite aceito"
    const val CONVITE_ACEITO = "Você agora faz parte da casa como %s."
    const val CONVITE_ACEITO_SEM_PAPEL = "Você agora faz parte da casa."
    const val CONVITE_ABRIR_CASA = "Abrir a casa"
    const val CONVITE_FORMATO_INVALIDO = "Link ou código inválido. Cole o link inteiro do convite, ou só o código, sem mais nada."
    const val CONVITE_INVALIDO = "Este convite não vale mais: já foi usado, venceu ou o código está errado. Peça um novo a quem convidou."
    const val CONVITE_DE_OUTRO_EMAIL = "Este convite foi feito para outro e-mail. Entre com o e-mail que recebeu o convite."
    const val CONVITE_PERFIL_INCOMPATIVEL = "Convites de casa são para contas de quem contrata. A sua conta é de profissional."
    const val CONVITE_INCERTO = "Não foi possível confirmar agora. Tente de novo; se o convite já tiver sido aceito, a casa aparece na sua conta."

    // Trocar de casa
    const val TROCAR_TITULO = "Trocar de casa"
    const val TROCAR_EXPLICACAO = "Escolha de qual casa você quer cuidar agora."
    const val TROCAR_ATUAL = "Casa em uso"
    const val TROCAR_CARREGANDO = "Carregando suas casas…"
    const val TROCAR_FALHA = "Não foi possível carregar suas casas."

    // Rota
    const val ROTA_TITULO_FALHA = "Não foi possível abrir a equipe"
    const val ROTA_FALHA = "Não foi possível carregar a casa. Verifique sua conexão e tente novamente."
    const val ROTA_NAO_E_MEMBRO = "Você não é membro desta casa."
}
