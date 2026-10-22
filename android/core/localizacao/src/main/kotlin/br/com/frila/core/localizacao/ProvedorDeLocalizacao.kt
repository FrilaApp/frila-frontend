package br.com.frila.core.localizacao

import br.com.frila.core.dominio.modelo.Coordenada

/**
 * Leitura de localização para o check-in presencial (RF13/RN06/RN22). A leitura é sempre sob
 * demanda, no instante do toque — nunca em segundo plano (RN22, minimização LGPD): o app não
 * guarda um histórico de posições, só a coordenada do momento exato do check-in, e só para
 * calcular a distância; a coordenada em si nunca sai do aparelho.
 */
interface ProvedorDeLocalizacao {

    /**
     * Lê a coordenada atual. Retorna `null` sem lançar exceção quando não há permissão, o GPS
     * está desativado ou a localização não pôde ser obtida a tempo — o check-in continua
     * possível nesses casos, só que no modo `manual` (RN06).
     */
    suspend fun obterCoordenadaAtual(): Coordenada?

    /** Verdadeiro se ao menos uma das permissões de localização (fina ou aproximada) foi concedida. */
    fun temPermissaoDeLocalizacao(): Boolean
}
