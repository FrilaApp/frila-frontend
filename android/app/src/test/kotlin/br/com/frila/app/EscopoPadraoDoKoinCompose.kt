package br.com.frila.app

import androidx.compose.runtime.CompositionLocal
import org.koin.compose.LocalKoinApplication
import org.koin.compose.LocalKoinScope
import org.koin.core.annotation.KoinInternalApi
import org.koin.mp.KoinPlatform

/**
 * O `koinInject()` da `AppNavegacao`, sem `KoinApplication` em volta (como na `MainActivity`), lê o escopo de `LocalKoinScope`, e o
 * Compose guarda o valor padrão desse local para o processo todo: o primeiro Koin que uma composição usa fica preso, e os testes
 * seguintes, com outro Koin, recebem um escopo fechado (`ClosedScopeException`). Quem abre a `MainActivity` num teste chama [reiniciar]
 * antes e depois, para o padrão ser lido de novo do Koin vigente e a ordem das classes de teste não importar. O mesmo vale para o
 * `getKoin()` do Compose (`LocalKoinApplication`), que a `AppNavegacao` usa para os serviços opcionais, como o avaliador da abertura.
 *
 * Mexe em campos privados do Compose; se uma versão nova os mudar, o teste falha na hora com `NoSuchFieldException`, não em silêncio.
 */
internal object EscopoPadraoDoKoinCompose {
    // `scopeRegistry` é API interna do Koin: é o que o próprio padrão do `LocalKoinScope` lê.
    @OptIn(KoinInternalApi::class)
    fun reiniciar() {
        relerPadrao(LocalKoinScope) { KoinPlatform.getKoin().scopeRegistry.rootScope }
        relerPadrao(LocalKoinApplication) { KoinPlatform.getKoin() }
    }

    private fun relerPadrao(local: CompositionLocal<*>, valor: () -> Any) {
        val padrao = CompositionLocal::class.java.getDeclaredField("defaultValueHolder")
            .apply { isAccessible = true }
            .get(local)
        padrao.javaClass.getDeclaredField("current\$delegate")
            .apply { isAccessible = true }
            .set(padrao, lazy(valor))
    }
}
