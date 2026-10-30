package br.com.frila.app

import android.app.Application
import android.util.Log
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import br.com.frila.core.seguranca.LeitorDeAmbiente
import br.com.frila.core.seguranca.VerificadorDeIntegridade
import org.koin.android.ext.koin.androidContext
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import org.koin.core.context.startKoin

class FrilaApplication : Application(), KoinComponent {

    private val leitorDeAmbiente: LeitorDeAmbiente by inject()

    override fun onCreate() {
        super.onCreate()

        startKoin {
            androidContext(this@FrilaApplication)
            modules(todosOsModulos)
        }

        GerenciadorDeCanais.criarCanais(this)
        registrarIntegridade()
    }

    /**
     * RN15 (cartão Cdv0sS5w): só telemetria/auditoria — nunca bloqueia, nunca lança. Hoje loga
     * localmente; quando existir um pipeline de telemetria remota no app, o relatório deve ser
     * enviado para lá em vez de (ou além de) `Log` (DEDUZIDO: nenhum pipeline de telemetria
     * remota existe no repositório ainda).
     */
    private fun registrarIntegridade() {
        try {
            val relatorio = VerificadorDeIntegridade.verificar(leitorDeAmbiente)
            if (!relatorio.integro) {
                Log.w("Integridade", "RN15: dispositivo não íntegro — $relatorio")
            }
        } catch (_: Exception) {
            // Jamais pode ser a causa de uma falha de inicialização do app.
        }
    }
}
