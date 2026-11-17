package br.com.frila.app

/** Lê a foto escolhida no seletor do sistema e devolve o JPEG pronto para subir. Fica atrás de uma interface para o teste do grafo trocar por um falso. */
fun interface PreparadorDaFotoDePerfil {
    suspend fun preparar(referencia: String): ByteArray
}
