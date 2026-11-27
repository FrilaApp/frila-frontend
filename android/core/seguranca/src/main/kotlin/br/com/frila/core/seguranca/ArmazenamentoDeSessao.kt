package br.com.frila.core.seguranca

/**
 * Porta de domínio para persistência segura de sessão. A implementação de produção
 * (Android Keystore + `EncryptedSharedPreferences`, ver `docs/android/04-seguranca-e-sessao.md`)
 * vive no módulo `:app` ou num adaptador Android dedicado; esta interface e
 * [ArmazenamentoDeSessaoEmMemoria] permitem testar a lógica de sessão em JVM pura, sem emulador.
 */
interface ArmazenamentoDeSessao {
    fun salvarSessao(sessao: Sessao)
    fun obterSessao(): Sessao?
    fun limparSessao()

    /**
     * Grava [nova] só se a sessão guardada ainda tem o refresh token [esperado]. A comparação e a gravação são uma
     * operação só, sem outro escritor entre as duas (#794: a renovação de A não pode sobrescrever a sessão de B).
     * Devolve `false` quando a sessão mudou ou sumiu, ou quando a gravação falhou: nada ficou guardado, e quem chama não pode tratar [nova] como a sessão vigente.
     */
    fun salvarSeRefreshTokenIgual(esperado: String, nova: Sessao): Boolean

    /**
     * Apaga a sessão só se ela ainda tem o refresh token [esperado], numa operação atômica como [salvarSeRefreshTokenIgual].
     * Devolve `false` quando a sessão mudou ou sumiu; nada é apagado.
     */
    fun limparSeRefreshTokenIgual(esperado: String): Boolean
    fun estaAutenticado(): Boolean

    /** RN15: preferência de desbloqueio biométrico, sempre `false` sem sessão/após logout. */
    fun isBiometriaAtivada(): Boolean
    fun definirBiometriaAtivada(ativada: Boolean)
}
