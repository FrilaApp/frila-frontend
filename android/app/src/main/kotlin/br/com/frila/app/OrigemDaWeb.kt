package br.com.frila.app

/**
 * Onde a web do Frila mora em cada ambiente do app: o debug fala com o Supabase DEV e abre a web DEV; o release fala com
 * o Prod e abre a web Prod. Só o link do convite de membro da casa usa isto hoje (o link que o administrador compartilha
 * tem de abrir uma web que conheça o convite).
 */
internal object OrigemDaWeb {
    /** A prévia da web de dev (Worker `frila-web-dev`, Supabase DEV). */
    const val DEV = "https://frila-web-dev.frilabr.workers.dev/app"

    /** A web de produção (Worker `frila-web`, rotas `frilabr.com/app*`). */
    const val PRODUCAO = "https://frilabr.com/app"

    fun doAmbiente(debug: Boolean = BuildConfig.DEBUG): String = if (debug) DEV else PRODUCAO
}
