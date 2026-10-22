package br.com.frila.core.notificacoes

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context

/** Especificação de um canal, separada da criação real para ficar testável sem instrumentação. */
data class EspecificacaoDeCanal(
    val id: String,
    val nome: String,
    val importancia: Int,
    val descricao: String,
)

/**
 * Canais de notificação do app (Android 8.0+ / API 26+), criados uma vez em
 * `Application.onCreate()` (ver `docs/android/04-seguranca-e-sessao.md` §4).
 */
object GerenciadorDeCanais {
    const val CANAL_URGENCIA = "canal_urgencia"
    const val CANAL_TURNOS = "canal_turnos"
    const val CANAL_SISTEMA = "canal_sistema"

    /**
     * As especificações em si, sem tocar em `NotificationManager` — é isto que
     * `GerenciadorDeCanaisTest` confere, em JVM pura.
     */
    fun especificacoes(): List<EspecificacaoDeCanal> = listOf(
        EspecificacaoDeCanal(
            id = CANAL_URGENCIA,
            nome = "Vagas urgentes",
            importancia = NotificationManager.IMPORTANCE_HIGH,
            descricao = "Novas vagas urgentes e convites — som e vibração.",
        ),
        EspecificacaoDeCanal(
            id = CANAL_TURNOS,
            nome = "Turnos",
            importancia = NotificationManager.IMPORTANCE_DEFAULT,
            descricao = "Lembretes de turno, check-in/check-out e atrasos.",
        ),
        EspecificacaoDeCanal(
            id = CANAL_SISTEMA,
            nome = "Geral",
            importancia = NotificationManager.IMPORTANCE_DEFAULT,
            descricao = "Informações administrativas e suporte.",
        ),
    )

    /** Cria de fato os canais no sistema — precisa de um `Context` real, fora do escopo dos testes de unidade. */
    fun criarCanais(context: Context) {
        val gerenciador = context.getSystemService(NotificationManager::class.java) ?: return
        especificacoes().forEach { espec ->
            val canal = NotificationChannel(espec.id, espec.nome, espec.importancia).apply {
                description = espec.descricao
            }
            gerenciador.createNotificationChannel(canal)
        }
    }
}
