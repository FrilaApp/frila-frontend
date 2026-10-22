package br.com.frila.feature.perfil

import br.com.frila.core.rede.PerfilProfissionalDto

/** Status da tela de perfil. */
enum class StatusPerfil { CARREGANDO, SUCESSO, ERRO }

/** Estado da tela de perfil do profissional (RF03/RF16). */
data class EstadoPerfil(
    val status: StatusPerfil = StatusPerfil.CARREGANDO,
    val perfil: PerfilProfissionalDto? = null,
    val mensagemErro: String? = null,
)
