package br.com.frila.feature.vagas.escala

/**
 * A escala em andamento de cada casa, guardada acima da tela (paridade com `GuardaDaEscala`/`GuardasPorCasa` do iOS).
 *
 * O [EscalaDeEventoViewModel] nasce a cada visita à tela e some com ela. Enquanto uma publicação tem resultado incerto (sem rede,
 * resposta perdida), o corpo e a `chave` de idempotência precisam sobreviver à saída da tela: voltar e publicar de novo com uma
 * `chave` nova publicaria a vaga em dobro. Quem vive aqui é só o estado com [EstadoEscalaDeEvento.pendente]; sucesso e recusa
 * definitiva tiram a casa da guarda, e o logout, a troca e a expiração da sessão esvaziam tudo ([limpar]).
 *
 * Cada [limpar] muda a geração, como na `GuardaDaBusca`: o view model guarda e remove com a geração em que nasceu, então a tela da
 * conta que saiu, aberta durante o logout, não devolve à guarda a escala que o logout apagou (a resposta da publicação em voo chega
 * depois) nem apaga a que a conta seguinte deixou na mesma casa.
 */
class GuardaDaEscala {
    private val porCasa = HashMap<String, EstadoEscalaDeEvento>()
    private var geracaoAtual = 0

    /** O que está guardado para a casa e a geração de agora, lidos juntos: o view model chama ao nascer e devolve a geração depois. */
    fun abrir(casaId: String): Pair<EstadoEscalaDeEvento?, Int> = synchronized(this) { porCasa[casaId] to geracaoAtual }

    fun obter(casaId: String): EstadoEscalaDeEvento? = synchronized(this) { porCasa[casaId] }

    /** Só guarda se nenhum [limpar] aconteceu desde que o view model nasceu ([geracaoDaVisita]). */
    fun guardar(casaId: String, estado: EstadoEscalaDeEvento, geracaoDaVisita: Int) {
        synchronized(this) {
            if (geracaoDaVisita == geracaoAtual) porCasa[casaId] = estado
        }
    }

    /** Como [guardar], só remove na mesma geração. */
    fun remover(casaId: String, geracaoDaVisita: Int) {
        synchronized(this) {
            if (geracaoDaVisita == geracaoAtual) porCasa.remove(casaId)
        }
    }

    /** Esvazia todas as casas: a escala pendente é da conta que saiu. */
    fun limpar() {
        synchronized(this) {
            porCasa.clear()
            geracaoAtual++
        }
    }
}
