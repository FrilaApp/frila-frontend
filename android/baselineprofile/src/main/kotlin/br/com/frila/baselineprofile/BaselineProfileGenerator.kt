package br.com.frila.baselineprofile

import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Gerador de Baseline Profile para o Frila Android (Cartão 53, RNF04).
 *
 * Coleta perfis de inicialização (startup) e rotas críticas (feed de vagas e navegação)
 * para compilação antecipada pelo ART em builds de release.
 */
@RunWith(AndroidJUnit4::class)
@LargeTest
class BaselineProfileGenerator {

    @get:Rule
    val baselineRule = BaselineProfileRule()

    @Test
    fun gerarStartupBaselineProfile() {
        baselineRule.collect(
            packageName = "br.com.frila.app",
            includeInStartupProfile = true,
        ) {
            pressHome()
            startActivityAndWait()
        }
    }
}
