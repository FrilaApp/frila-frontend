package br.com.frila.app

import androidx.compose.runtime.Composable
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/**
 * Denunciar e bloquear o perfil público que uma tela mostra (CD-RF12): a chamada recebida do profissional e, no item 187, o perfil
 * público visto pela casa. O alvo é o `id` do `PerfilPublico` como chegou à tela, nunca o id de conta (RN10).
 */
internal fun tipoDeAlvoDe(perfil: PerfilPublicoDto): TipoDeAlvo =
    if (perfil.tipo == TipoDeAlvo.PROFISSIONAL.chave) TipoDeAlvo.PROFISSIONAL else TipoDeAlvo.ESTABELECIMENTO

/**
 * O bloqueio avulso do [perfil], ou `null` enquanto a tela ainda não o conhece. [chave] separa o view model por tela e por
 * perfil: outro perfil na mesma posição da pilha recria o estado do bloqueio em vez de herdar o do anterior.
 */
@Composable
internal fun bloqueioDoPerfil(perfil: PerfilPublicoDto?, chave: String): BloqueioDeAlvoViewModel? =
    perfil?.let { koinViewModel(key = "$chave-${it.id}", parameters = { parametersOf(tipoDeAlvoDe(it), it.id) }) }
