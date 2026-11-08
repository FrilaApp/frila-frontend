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
    fun estaAutenticado(): Boolean

    /** RN15: preferência de desbloqueio biométrico, sempre `false` sem sessão/após logout. */
    fun isBiometriaAtivada(): Boolean
    fun definirBiometriaAtivada(ativada: Boolean)
}
