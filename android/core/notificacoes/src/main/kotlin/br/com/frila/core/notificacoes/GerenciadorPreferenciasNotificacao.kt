package br.com.frila.core.notificacoes

import android.content.Context

/**
 * Preferência local (RF06) de receber ou não notificações de um canal. 100% local — não existe
 * endpoint/tabela remota para isto (MEDIDO: busca em openapi.yaml/migrações SQL não encontrou
 * nada; `/rpc/criterios_de_notificacao` é outra coisa, RF27/LGPD). Padrão: todos os canais
 * ativados (`true`) até o usuário desativar explicitamente.
 */
interface GerenciadorPreferenciasNotificacao {
    fun estaAtivado(canal: String): Boolean
    fun definirAtivado(canal: String, ativado: Boolean)
}

/** Implementação em memória — testes de unidade e qualquer consumidor sem `Context` real. */
class GerenciadorPreferenciasNotificacaoEmMemoria : GerenciadorPreferenciasNotificacao {
    private val estados = mutableMapOf<String, Boolean>()
    override fun estaAtivado(canal: String): Boolean = estados[canal] ?: true
    override fun definirAtivado(canal: String, ativado: Boolean) {
        estados[canal] = ativado
    }
}

/**
 * Implementação de produção: `SharedPreferences` privado (`preferencias_notificacoes`), uma
 * chave booleana por canal.
 */
class GerenciadorPreferenciasNotificacaoSharedPrefs(context: Context) : GerenciadorPreferenciasNotificacao {
    private val preferencias = context.applicationContext
        .getSharedPreferences(NOME_PREFERENCIAS, Context.MODE_PRIVATE)

    override fun estaAtivado(canal: String): Boolean = preferencias.getBoolean(canal, true)

    override fun definirAtivado(canal: String, ativado: Boolean) {
        preferencias.edit().putBoolean(canal, ativado).apply()
    }

    companion object {
        const val NOME_PREFERENCIAS = "preferencias_notificacoes"
    }
}
