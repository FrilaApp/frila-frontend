package br.com.frila.app.falhas

import android.content.Context
import android.content.SharedPreferences
import java.time.Instant

/**
 * Gerenciador de consentimento para envio de relatórios de falha ao Firebase Crashlytics (LGPD art. 33, VIII).
 *
 * Parecer P-059 / Pedido 19-03 / Cartão vXEjqVEH:
 * - O manifesto vem com `firebase_crashlytics_collection_enabled = false` e `firebase_sessions_enabled = false`.
 * - Sem preferência gravada (instalação nova): coleta DESLIGADA.
 * - Versão atual do texto da política/parecer: 1.8.
 * - Ao aceitar: chama `deleteUnsentReports()` ANTES de `setCrashlyticsCollectionEnabled(true)`, e grava preferência com versão e data/hora.
 * - Ao recusar ou revogar: chama `setCrashlyticsCollectionEnabled(false)`, apaga relatórios pendentes (`deleteUnsentReports()`), e grava `false`.
 * - Se a versão do texto mudar, a coleta volta a desligada e `precisaPerguntar()` passa a retornar true.
 */
interface GerenciadorConsentimentoCrashlytics {
    /** Versão atual do texto do consentimento exibido ao usuário (Política 1.8). */
    val versaoTextoAtual: String get() = VERSAO_TEXTO_PADRAO

    /** Se a coleta está ativamente autorizada para a versão atual do texto. */
    fun coletaAtiva(): Boolean

    /** Se o usuário ainda não respondeu à pergunta para a versão atual do texto. */
    fun precisaPerguntar(): Boolean

    /** Define o consentimento (true para "Permitir envio", false para "Agora não" ou revogação). */
    fun definirConsentimento(concedido: Boolean)

    companion object {
        const val VERSAO_TEXTO_PADRAO = "1.8"
        const val ARQUIVO_PREFERENCIAS = "consentimento_crashlytics"
        const val CHAVE_CONSENTIMENTO = "consentimento_concedido"
        const val CHAVE_VERSAO_TEXTO = "versao_texto"
        const val CHAVE_DATA_HORA = "data_hora_resposta"
    }
}

class GerenciadorConsentimentoCrashlyticsReal(
    private val preferencias: SharedPreferences,
    private val firebase: FalhasDoFirebase,
    private val leitorManifesto: () -> Boolean,
    override val versaoTextoAtual: String = GerenciadorConsentimentoCrashlytics.VERSAO_TEXTO_PADRAO,
    private val relogio: () -> String = { Instant.now().toString() },
) : GerenciadorConsentimentoCrashlytics {

    constructor(
        contexto: Context,
        firebase: FalhasDoFirebase = FalhasDoFirebaseReal(contexto),
        versaoTexto: String = GerenciadorConsentimentoCrashlytics.VERSAO_TEXTO_PADRAO,
        relogio: () -> String = { Instant.now().toString() },
    ) : this(
        preferencias = contexto.getSharedPreferences(GerenciadorConsentimentoCrashlytics.ARQUIVO_PREFERENCIAS, Context.MODE_PRIVATE),
        firebase = firebase,
        leitorManifesto = { ColetaDeFalhas.ligadaNoManifesto(contexto) },
        versaoTextoAtual = versaoTexto,
        relogio = relogio,
    )

    override fun coletaAtiva(): Boolean {
        // Sem preferência ou com valor falso: desligada
        if (!preferencias.contains(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO)) return false
        val concedido = preferencias.getBoolean(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO, false)
        val versao = preferencias.getString(GerenciadorConsentimentoCrashlytics.CHAVE_VERSAO_TEXTO, null)
        // Só true com a versão atual do texto liga a coleta
        return concedido && versao == versaoTextoAtual
    }

    override fun precisaPerguntar(): Boolean {
        // Precisa perguntar se nunca respondeu ou se a resposta registrada for de outra versão de texto
        val versaoGravada = preferencias.getString(GerenciadorConsentimentoCrashlytics.CHAVE_VERSAO_TEXTO, null)
        val temResposta = preferencias.contains(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO)
        return !temResposta || versaoGravada != versaoTextoAtual
    }

    override fun definirConsentimento(concedido: Boolean) {
        if (concedido) {
            // Parecer P-059 §3 item 8: Chamar deleteUnsentReports() ANTES de ligar, para não mandar o guardado anterior
            firebase.apagarRelatoriosPendentes()
            firebase.definirColetaAtiva(true)
        } else {
            // Parecer P-059 §3 item 4: Chamar setCrashlyticsCollectionEnabled(false) e apagar pendentes
            firebase.definirColetaAtiva(false)
            firebase.apagarRelatoriosPendentes()
        }
        preferencias.edit()
            .putBoolean(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO, concedido)
            .putString(GerenciadorConsentimentoCrashlytics.CHAVE_VERSAO_TEXTO, versaoTextoAtual)
            .putString(GerenciadorConsentimentoCrashlytics.CHAVE_DATA_HORA, relogio())
            .apply()
    }
}
