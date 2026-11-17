package br.com.frila.core.rede

/** Foto de perfil do chamador (RN14, RN15; contrato 0.2.54). Esqueleto do teste vermelho (L1-0b): sem comportamento. */
class ServicoMidia(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    private val cliente: ClienteSupabase get() = provedorDeCliente()

    suspend fun solicitarUploadMidia(mime: String, bytes: Int, tipo: String = "foto_perfil", estabelecimentoId: String? = null): UploadMidiaDto =
        TODO("L1-0b")

    suspend fun enviarFoto(urlDeUpload: String, jpeg: ByteArray): Unit = TODO("L1-0b")

    suspend fun confirmarUploadMidia(midiaId: String): MidiaDto = TODO("L1-0b")

    suspend fun removerMidia(midiaId: String): MidiaDto = TODO("L1-0b")

    suspend fun pedirNovaAnaliseMidia(midiaId: String): MidiaDto = TODO("L1-0b")

    suspend fun minhasMidias(): List<MidiaDto> = TODO("L1-0b")
}
