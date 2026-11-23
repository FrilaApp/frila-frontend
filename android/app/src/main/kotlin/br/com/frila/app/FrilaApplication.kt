package br.com.frila.app

import android.app.Application
import br.com.frila.core.rede.RegistradorDeTelemetria
import br.com.frila.core.rede.EventoDeTelemetria
import android.util.Log
import br.com.frila.app.desempenho.MedidorDeColdStart
import br.com.frila.app.falhas.ColetaDeFalhas
import br.com.frila.app.falhas.FalhasDoFirebase
import br.com.frila.app.falhas.FalhasDoFirebaseReal
import br.com.frila.app.falhas.GerenciadorConsentimentoCrashlytics
import br.com.frila.app.falhas.RelatorioDeFalhas
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import br.com.frila.core.seguranca.LeitorDeAmbiente
import br.com.frila.core.seguranca.VerificadorDeIntegridade
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.android.ext.koin.androidContext
import org.koin.core.component.KoinComponent
import org.koin.core.component.get
import org.koin.core.component.inject
import org.koin.core.context.startKoin

class FrilaApplication : Application(), KoinComponent {

    private val leitorDeAmbiente: LeitorDeAmbiente by inject()

    override fun onCreate() {
        super.onCreate()
        MedidorDeColdStart.iniciar()
        limparRelatoriosDeFalhaPendentes()

        startKoin {
            androidContext(this@FrilaApplication)
            modules(todosOsModulos)
        }

        GerenciadorDeCanais.criarCanais(this)
        registrarIntegridade()
        cancelarGeofencesAntigos()
        val telemetria = get<RegistradorDeTelemetria>()
        telemetria.disparar(EventoDeTelemetria.APP_ABERTO)
        telemetria.acompanharConectividade(get())
    }

    /**
     * O geofence de aproximação saiu do app; o que uma versão anterior deixou registrado é cancelado aqui, em segundo plano
     * ([LimpezaDeGeofencesAntigos]). Nunca pode ser a causa de uma falha de inicialização do app.
     */
    private fun cancelarGeofencesAntigos() {
        try {
            val limpeza = get<LimpezaDeGeofencesAntigos>()
            CoroutineScope(SupervisorJob() + Dispatchers.IO).launch { limpeza.executar() }
        } catch (_: Exception) {
        }
    }

    /**
     * L1-6 / Parecer P-059: a coleta de falhas sai desligada (manifesto) e só liga após consentimento explícito.
     * Na abertura, se desligada, qualquer relatório guardado pelo SDK é apagado (como no iOS).
     * Nunca pode ser a causa de uma falha de inicialização do app.
     */
    private fun limparRelatoriosDeFalhaPendentes() {
        try {
            val consentimento = get<GerenciadorConsentimentoCrashlytics>()
            val firebase = get<FalhasDoFirebase>()
            RelatorioDeFalhas.iniciarSeConfigurado(consentimento.coletaAtiva(), firebase)
        } catch (_: Exception) {
        }
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
