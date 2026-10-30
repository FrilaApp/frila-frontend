package br.com.frila.app

import androidx.navigation.NavController

/**
 * Substitui o `{chave}` de [padrao] pelo valor correspondente em [argumentos]. Genérico — não
 * conhece rota específica, só o formato de placeholder usado em [Rotas] (`detalhe/{vagaId}`,
 * `avaliacao/{turnoId}`, etc.).
 */
private fun preencherRota(padrao: String, argumentos: Map<String, String>): String {
    var resultado = padrao
    for ((chave, valor) in argumentos) resultado = resultado.replace("{$chave}", valor)
    return resultado
}

/**
 * Gate de desbloqueio biométrico (RN15) em memória, independente de como o app chegou a uma
 * rota autenticada. MEDIDO (Shisui, PR #591): `rotaInicial()` só decidia a tela de abertura —
 * um deep link (`frila://vagas/{vagaId}`, `frila://meus_turnos`, `frila://suporte`) chega via
 * `NavController.handleDeepLink` e pula direto para o destino, nunca passando por
 * `rotaInicial()`. [aoMudarDestino] é chamado em TODA mudança de destino do `NavController`
 * (via [instalarGuardaBiometrico]), não só a inicial — por isso pega o deep link também.
 *
 * `desbloqueada` começa `true` quando a biometria não está ativada (nada a bloquear) e vira
 * `true` permanentemente após a primeira autenticação bem-sucedida nesta execução do processo —
 * não se tranca de novo sozinha; só volta a bloquear num novo processo.
 */
class GuardaBiometrico(sessaoDesbloqueadaInicial: Boolean) {
    var desbloqueada: Boolean = sessaoDesbloqueadaInicial
        private set

    private var destinoPendente: String? = null

    /**
     * Chamada a cada mudança de destino. Devolve [Rotas.DESBLOQUEIO] quando a rota precisa ser
     * interceptada (sessão travada e rota fora de [ROTAS_SEM_GATE]), guardando [rota] com
     * [argumentos] já preenchidos para [aoDesbloquearComSucesso] devolver depois. Devolve `null`
     * quando a navegação pode seguir normalmente.
     */
    fun aoMudarDestino(rota: String?, argumentos: Map<String, String> = emptyMap()): String? {
        if (desbloqueada || rota == null || rota in ROTAS_SEM_GATE) return null
        destinoPendente = preencherRota(rota, argumentos)
        return Rotas.DESBLOQUEIO
    }

    /**
     * Libera a sessão e devolve o destino que o usuário tentou acessar antes de ser
     * interceptado — [Rotas.FEED] se não havia nenhum (ex.: abertura normal do app com
     * biometria ativada, sem deep link). Consome o destino pendente: uma segunda chamada sem
     * nova interceptação volta a cair em [Rotas.FEED].
     */
    fun aoDesbloquearComSucesso(): String {
        desbloqueada = true
        val destino = destinoPendente ?: Rotas.FEED
        destinoPendente = null
        return destino
    }

    /**
     * Chamado quando a sessão é limpa fora de um desbloqueio bem-sucedido (ex.: "Entrar com
     * outra conta"). `limparSessao()` já apaga a flag `isBiometriaAtivada()` no armazenamento —
     * sem isto, o gate continuaria travado em memória para o próximo login nesta mesma execução
     * do processo, mesmo a flag real já estando desligada.
     */
    fun liberarAposLimparSessao() {
        desbloqueada = true
        destinoPendente = null
    }

    companion object {
        /** Rotas do fluxo de login/desbloqueio em si — nunca fazem sentido gatear a si mesmas. */
        val ROTAS_SEM_GATE = setOf(Rotas.ENTRADA, Rotas.CODIGO, Rotas.CADASTRO, Rotas.DESBLOQUEIO)
    }
}

/**
 * Liga [guarda] ao [navController]: toda mudança de destino passa por
 * [GuardaBiometrico.aoMudarDestino] primeiro. Quem chama é responsável por remover o listener
 * devolvido quando o composable sair de cena (`DisposableEffect`/`onDispose`), para não vazar o
 * listener depois que o `NavController` for descartado.
 */
@Suppress("DEPRECATION") // Bundle.get(String) genérico — os valores aqui são sempre String (args de rota).
fun instalarGuardaBiometrico(navController: NavController, guarda: GuardaBiometrico): NavController.OnDestinationChangedListener {
    val listener = NavController.OnDestinationChangedListener { controlador, destino, argumentos ->
        val mapaDeArgumentos = argumentos
            ?.keySet()
            ?.associateWith { chave -> argumentos.get(chave)?.toString().orEmpty() }
            .orEmpty()
        val redirecionamento = guarda.aoMudarDestino(destino.route, mapaDeArgumentos)
        if (redirecionamento != null) {
            controlador.navigate(redirecionamento) {
                popUpTo(destino.id) { inclusive = true }
            }
        }
    }
    navController.addOnDestinationChangedListener(listener)
    return listener
}
