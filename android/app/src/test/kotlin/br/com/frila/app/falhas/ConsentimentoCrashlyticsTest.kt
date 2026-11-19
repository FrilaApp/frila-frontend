package br.com.frila.app.falhas

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes unitários para o gerenciador de consentimento do Crashlytics (LGPD art. 33, VIII).
 * Parecer P-059, Seção 4 (Aceite) e Despacho do Prisma.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class ConsentimentoCrashlyticsTest {

    private lateinit var contexto: Context

    private class FirebaseEspiao(override val configurado: Boolean = true) : FalhasDoFirebase {
        val operacoes = mutableListOf<String>()
        override fun apagarRelatoriosPendentes() {
            operacoes.add("apagarRelatoriosPendentes")
        }
        override fun definirColetaAtiva(ativa: Boolean) {
            operacoes.add("definirColetaAtiva:$ativa")
        }
    }

    @Before
    fun preparar() {
        contexto = ApplicationProvider.getApplicationContext()
        contexto.getSharedPreferences(GerenciadorConsentimentoCrashlytics.ARQUIVO_PREFERENCIAS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun `instalacao nova sem preferencia gravada mantem coleta desligada e precisa perguntar`() {
        val firebase = FirebaseEspiao()
        val consentimento = GerenciadorConsentimentoCrashlyticsReal(
            contexto = contexto,
            firebase = firebase,
            versaoTexto = "1.8",
        )

        assertFalse("Sem preferência, a coleta deve estar DESLIGADA", consentimento.coletaAtiva())
        assertTrue("Instalação nova precisa exibir a tela de consentimento", consentimento.precisaPerguntar())
        assertTrue(firebase.operacoes.isEmpty())
    }

    @Test
    fun `versao anterior gravada mantem coleta desligada e exige nova pergunta`() {
        val prefs = contexto.getSharedPreferences(GerenciadorConsentimentoCrashlytics.ARQUIVO_PREFERENCIAS, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO, true)
            .putString(GerenciadorConsentimentoCrashlytics.CHAVE_VERSAO_TEXTO, "1.7")
            .putString(GerenciadorConsentimentoCrashlytics.CHAVE_DATA_HORA, "2026-11-17T10:00:00Z")
            .commit()

        val firebase = FirebaseEspiao()
        val consentimento = GerenciadorConsentimentoCrashlyticsReal(
            contexto = contexto,
            firebase = firebase,
            versaoTexto = "1.8",
        )

        assertFalse("Versão 1.7 com texto 1.8 deve manter a coleta DESLIGADA até novo aceite", consentimento.coletaAtiva())
        assertTrue("Quando o texto muda, precisa perguntar novamente", consentimento.precisaPerguntar())
    }

    @Test
    fun `aceitar apaga relatorios pendentes ANTES de ligar o SDK e ativa a coleta`() {
        val firebase = FirebaseEspiao()
        val consentimento = GerenciadorConsentimentoCrashlyticsReal(
            contexto = contexto,
            firebase = firebase,
            versaoTexto = "1.8",
            relogio = { "2026-11-19T14:30:00Z" },
        )

        consentimento.definirConsentimento(true)

        // Ordem não negociável (Parecer P-059 §3 item 8): apagar pendentes antes de ligar a coleta
        assertEquals(
            listOf("apagarRelatoriosPendentes", "definirColetaAtiva:true"),
            firebase.operacoes,
        )
        assertTrue(consentimento.coletaAtiva())
        assertFalse("Após responder 1.8, não deve perguntar de novo", consentimento.precisaPerguntar())

        val prefs = contexto.getSharedPreferences(GerenciadorConsentimentoCrashlytics.ARQUIVO_PREFERENCIAS, Context.MODE_PRIVATE)
        assertTrue(prefs.getBoolean(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO, false))
        assertEquals("1.8", prefs.getString(GerenciadorConsentimentoCrashlytics.CHAVE_VERSAO_TEXTO, null))
        assertEquals("2026-11-19T14:30:00Z", prefs.getString(GerenciadorConsentimentoCrashlytics.CHAVE_DATA_HORA, null))
    }

    @Test
    fun `recusar com Agora nao desliga o SDK, apaga pendentes e nao insiste`() {
        val firebase = FirebaseEspiao()
        val consentimento = GerenciadorConsentimentoCrashlyticsReal(
            contexto = contexto,
            firebase = firebase,
            versaoTexto = "1.8",
        )

        consentimento.definirConsentimento(false)

        assertEquals(
            listOf("definirColetaAtiva:false", "apagarRelatoriosPendentes"),
            firebase.operacoes,
        )
        assertFalse(consentimento.coletaAtiva())
        assertFalse("Quem disse 'Agora não' não deve ser incomodado a cada abertura (Parecer P-059 §3 item 2)", consentimento.precisaPerguntar())

        val prefs = contexto.getSharedPreferences(GerenciadorConsentimentoCrashlytics.ARQUIVO_PREFERENCIAS, Context.MODE_PRIVATE)
        assertFalse(prefs.getBoolean(GerenciadorConsentimentoCrashlytics.CHAVE_CONSENTIMENTO, true))
        assertEquals("1.8", prefs.getString(GerenciadorConsentimentoCrashlytics.CHAVE_VERSAO_TEXTO, null))
    }

    @Test
    fun `revogar em configuracoes desliga SDK, apaga pendentes e desativa coleta`() {
        val firebase = FirebaseEspiao()
        val consentimento = GerenciadorConsentimentoCrashlyticsReal(
            contexto = contexto,
            firebase = firebase,
            versaoTexto = "1.8",
        )

        // Primeiro aceita
        consentimento.definirConsentimento(true)
        assertTrue(consentimento.coletaAtiva())
        firebase.operacoes.clear()

        // Depois revoga pelo switch de configurações
        consentimento.definirConsentimento(false)
        assertFalse(consentimento.coletaAtiva())
        assertEquals(
            listOf("definirColetaAtiva:false", "apagarRelatoriosPendentes"),
            firebase.operacoes,
        )
    }

    @Test
    fun `sem Firebase configurado no build nenhuma operacao quebra ou lanca excecao`() {
        val firebase = FalhasDoFirebaseReal(contexto)
        assertFalse("Sem google-services.json no build o Firebase não está configurado", firebase.configurado)

        // Não deve lançar exceção
        firebase.apagarRelatoriosPendentes()
        firebase.definirColetaAtiva(true)
        firebase.definirColetaAtiva(false)

        val consentimento = GerenciadorConsentimentoCrashlyticsReal(
            contexto = contexto,
            firebase = firebase,
            versaoTexto = "1.8",
        )

        assertFalse(consentimento.coletaAtiva())
        consentimento.definirConsentimento(true)
        assertTrue(consentimento.coletaAtiva())
        consentimento.definirConsentimento(false)
        assertFalse(consentimento.coletaAtiva())
    }
}
