package br.com.frila.app.falhas

/** Onde um erro da API seria gravado. Separado da telemetria para o teste espiar que nada chega aqui com a coleta desligada. */
interface DestinoDeFalhas {
    fun gravar(codigo: String, rpc: String, duracaoNs: Long)
}

/** Igual ao `TelemetriaCrashlytics` do iOS: só código, rota e duração; nada de usuário, e nada gravado com a coleta desligada. */
class TelemetriaDeFalhas(private val coletaLigada: Boolean, private val destino: DestinoDeFalhas) {
    fun registrarErroDaApi(codigo: String, rpc: String, duracaoNs: Long) {
        // Coleta desligada: nada vai ao Crashlytics, nem fica guardado no aparelho para depois.
        if (!coletaLigada) return
        destino.gravar(codigo, rpc, duracaoNs)
    }
}
