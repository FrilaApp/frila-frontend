package br.com.frila.feature.vagas.feed

import android.content.SharedPreferences

/**
 * Persistência local de preferências do filtro de vagas (RF05/RN01).
 * Permite manter a faixa de remuneração por hora selecionada entre sessões.
 */
interface ArmazenamentoPreferenciasFiltro {
    fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean)
    fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao?
    fun limparFaixaRemuneracaoHora()
}

data class PreferenciaFaixaRemuneracao(
    val minima: Float,
    val maxima: Float,
    val ativa: Boolean,
)

/** Implementação em memória para testes unitários em JVM pura. */
class ArmazenamentoPreferenciasFiltroEmMemoria(
    private var preferencia: PreferenciaFaixaRemuneracao? = null,
) : ArmazenamentoPreferenciasFiltro {

    override fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean) {
        preferencia = PreferenciaFaixaRemuneracao(minimo, maximo, ativa)
    }

    override fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao? = preferencia

    override fun limparFaixaRemuneracaoHora() {
        preferencia = null
    }
}

/** Implementação Android usando SharedPreferences do dispositivo. */
class ArmazenamentoPreferenciasFiltroSharedPreferences(
    private val preferences: SharedPreferences,
) : ArmazenamentoPreferenciasFiltro {

    override fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean) {
        preferences.edit()
            .putFloat(CHAVE_MINIMO, minimo)
            .putFloat(CHAVE_MAXIMO, maximo)
            .putBoolean(CHAVE_ATIVA, ativa)
            .apply()
    }

    override fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao? {
        if (!preferences.contains(CHAVE_MINIMO) || !preferences.contains(CHAVE_MAXIMO)) {
            return null
        }
        val minimo = preferences.getFloat(CHAVE_MINIMO, 25f)
        val maximo = preferences.getFloat(CHAVE_MAXIMO, 100f)
        val ativa = preferences.getBoolean(CHAVE_ATIVA, false)
        return PreferenciaFaixaRemuneracao(minima = minimo, maxima = maximo, ativa = ativa)
    }

    override fun limparFaixaRemuneracaoHora() {
        preferences.edit()
            .remove(CHAVE_MINIMO)
            .remove(CHAVE_MAXIMO)
            .remove(CHAVE_ATIVA)
            .apply()
    }

    companion object {
        private const val CHAVE_MINIMO = "filtro_remuneracao_hora_minimo"
        private const val CHAVE_MAXIMO = "filtro_remuneracao_hora_maximo"
        private const val CHAVE_ATIVA = "filtro_remuneracao_hora_ativa"
    }
}
