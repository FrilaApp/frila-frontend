package br.com.frila.app

import android.app.Application
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin

class FrilaApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        startKoin {
            androidContext(this@FrilaApplication)
            modules(todosOsModulos)
        }

        GerenciadorDeCanais.criarCanais(this)
    }
}
