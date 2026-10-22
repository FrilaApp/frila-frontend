package br.com.frila.feature.perfil

import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.PerfilProfissionalDto

/** Status da tela de perfil. */
enum class StatusPerfil { CARREGANDO, SUCESSO, ERRO }

/** Status do fluxo de exclusão de conta (RF25/RN15/RNF08, UC16). */
enum class StatusExclusao { OCIOSO, DIALOGO_ABERTO, EXCLUINDO, SUCESSO, ERRO }

/** Estado da tela de perfil do profissional (RF03/RF16/RF25). */
data class EstadoPerfil(
    val status: StatusPerfil = StatusPerfil.CARREGANDO,
    val perfil: PerfilProfissionalDto? = null,
    val mensagemErro: String? = null,
    val statusExclusao: StatusExclusao = StatusExclusao.OCIOSO,
    val mensagemErroExclusao: String? = null,
    val resultadoExclusao: ExclusaoDeContaDto? = null,
)
