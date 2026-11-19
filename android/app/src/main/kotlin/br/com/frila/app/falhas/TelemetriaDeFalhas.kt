package br.com.frila.app.falhas

/** Onde um erro da API seria gravado. Separado da telemetria para o teste espiar que nada chega aqui com a coleta desligada. */
interface DestinoDeFalhas {
    fun gravar(codigo: String, rpc: String, duracaoNs: Long)
}

/** Igual ao `TelemetriaCrashlytics` do iOS: só código, rota e duração; nada de usuário, e nada gravado com a coleta desligada. */
class TelemetriaDeFalhas(
    private val leitorColetaLigada: () -> Boolean,
    private val destino: DestinoDeFalhas,
) {
    constructor(coletaLigada: Boolean, destino: DestinoDeFalhas) : this({ coletaLigada }, destino)

    val coletaLigada: Boolean get() = leitorColetaLigada()

    fun registrarErroDaApi(codigo: String, rpc: String, duracaoNs: Long) {
        // Coleta desligada: nada vai ao Crashlytics, nem fica guardado no aparelho para depois.
        if (!leitorColetaLigada()) return
        destino.gravar(codigo, rpc, duracaoNs)
    }
}
