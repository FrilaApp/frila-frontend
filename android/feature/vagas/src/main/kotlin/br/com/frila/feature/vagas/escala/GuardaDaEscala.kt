package br.com.frila.feature.vagas.escala

import java.util.concurrent.ConcurrentHashMap

/**
 * A escala em andamento de cada casa, guardada acima da tela (paridade com `GuardaDaEscala`/`GuardasPorCasa` do iOS).
 *
 * O [EscalaDeEventoViewModel] nasce a cada visita à tela e some com ela. Enquanto uma publicação tem resultado incerto (sem rede,
 * resposta perdida), o corpo e a `chave` de idempotência precisam sobreviver à saída da tela: voltar e publicar de novo com uma
 * `chave` nova publicaria a vaga em dobro. Quem vive aqui é só o estado com [EstadoEscalaDeEvento.pendente]; sucesso e recusa
 * definitiva tiram a casa da guarda, e o logout, a troca e a expiração da sessão esvaziam tudo ([limpar]).
 */
class GuardaDaEscala {
    private val porCasa = ConcurrentHashMap<String, EstadoEscalaDeEvento>()

    fun obter(casaId: String): EstadoEscalaDeEvento? = porCasa[casaId]

    fun guardar(casaId: String, estado: EstadoEscalaDeEvento) {
        porCasa[casaId] = estado
    }

    fun remover(casaId: String) {
        porCasa.remove(casaId)
    }

    /** Esvazia todas as casas: a escala pendente é da conta que saiu. */
    fun limpar() {
        porCasa.clear()
    }
}
