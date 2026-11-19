import FrilaDominio
import SwiftUI

/// "Por que recebo vagas" (RF27), com os critérios em grupos de linhas e o pedido de revisão.
/// A folha de Meu perfil fornece a pilha de navegação e o Fechar.
public struct TelaPorQueReceboVagas: View {
    /// Em `@State`, e não `@Bindable`: a folha de Meu perfil recria esta view a cada re-render do
    /// perfil, e o view model criado no `init` tem de sobreviver a isso para a carga da `.task`
    /// chegar à tela.
    @State private var viewModel: PorQueReceboVagasViewModel
    @FocusState private var focoNoRelato: Bool

    public init(viewModel: PorQueReceboVagasViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public init(api: any ApiCliente) {
        self.init(viewModel: PorQueReceboVagasViewModel(api: api))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                Text(verbatim: TextosPerfilConta.explicacaoVagas)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("perfil-explicacao-vagas")
                    .frame(maxWidth: .infinity, alignment: .leading)
                criterios
                secaoContestar
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .scrollDismissesKeyboard(.interactively)
        .frilaKeyboardDismissScope()
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosPerfilConta.porQueRecebo))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .accessibilityIdentifier("tela-por-que-recebo")
    }

    // MARK: Critérios

    @ViewBuilder
    private var criterios: some View {
        switch viewModel.estado {
        case .carregando:
            EstadoCarregando()
        case .vazio:
            EstadoVazio(verbatim: TextosPorQueReceboVagas.vazioTitulo, mensagem: TextosPorQueReceboVagas.vazioMensagem)
                .accessibilityIdentifier("criterios-vazio")
        case .semRede:
            EstadoErro(verbatim: TextosPorQueReceboVagas.erroSemRede) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("criterios-sem-rede")
        case .erro:
            EstadoErro(verbatim: TextosPorQueReceboVagas.erroCarregar) { Task { await viewModel.carregar() } }
                .accessibilityIdentifier("criterios-erro")
        case let .conteudo(criterios):
            cartao(TextosPorQueReceboVagas.secaoFuncao, identificador: "criterios-funcoes") {
                if criterios.funcoes.isEmpty {
                    linha(TextosPorQueReceboVagas.semFuncao)
                } else {
                    ForEach(criterios.funcoes) { funcao in linha(funcao.nome) }
                }
            }
            cartao(TextosPorQueReceboVagas.secaoHorarios, identificador: "criterios-horarios",
                   nota: criterios.disponibilidades.isEmpty ? nil : TextosPorQueReceboVagas.horariosExplicacao) {
                if criterios.disponibilidades.isEmpty {
                    linha(TextosPorQueReceboVagas.semHorarios)
                } else {
                    ForEach(criterios.disponibilidades, id: \.self) { janela in
                        linha(PorQueReceboVagasViewModel.descricao(janela))
                    }
                }
            }
            cartao(TextosPorQueReceboVagas.secaoDistancia, identificador: "criterios-distancia") {
                linha(PorQueReceboVagasViewModel.descricaoDistancia(criterios.distanciaMaximaKm))
            }
            cartao(TextosPorQueReceboVagas.secaoEquipes, identificador: "criterios-equipes",
                   nota: criterios.equipesDeConfianca.isEmpty ? nil : TextosPorQueReceboVagas.equipesExplicacao) {
                if criterios.equipesDeConfianca.isEmpty {
                    linha(TextosPorQueReceboVagas.semEquipes)
                } else {
                    ForEach(criterios.equipesDeConfianca) { equipe in linha(equipe.nome) }
                }
            }
            cartao(TextosPorQueReceboVagas.secaoFrequencia, identificador: "criterios-frequencia") {
                linha(TextosPorQueReceboVagas.frequencia(criterios.notificacoesNoMaximoACadaMin))
            }
        }
    }

    /// Um critério: o nome em rótulo de grupo, as linhas de leitura num grupo de linhas e, se houver, a nota logo abaixo.
    /// O bloco inteiro é um elemento só para o leitor de tela, com o identificador do critério.
    private func cartao(_ titulo: String, identificador: String, nota textoDaNota: String? = nil,
                        @ViewBuilder conteudo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaGrupoDeLinhas(verbatim: titulo, linhasComIcone: false) {
                conteudo()
            }
            if let textoDaNota { nota(textoDaNota) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identificador)
    }

    /// Linha de leitura de um grupo: o valor em corpo, com a margem e o alvo mínimo das linhas do sistema.
    private func linha(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, FrilaMedidaDeLinha.margem)
            .padding(.vertical, FrilaEspaco.item)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
    }

    private func nota(_ texto: String) -> some View {
        Text(verbatim: texto)
            .font(FrilaTipo.apoio)
            .foregroundStyle(FrilaCor.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Contestar

    private var secaoContestar: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosPorQueReceboVagas.secaoContestar)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let protocolo = viewModel.protocolo {
                cartaoProtocolo(protocolo)
            } else if viewModel.contestacaoJaAberta {
                AvisoFrila(verbatim: TextosPorQueReceboVagas.contestacaoJaAberta, tom: .informativo)
                    .accessibilityIdentifier("status-revisao-ja-aberta")
            } else if viewModel.mostrarFormulario {
                formulario
            } else {
                nota(TextosPorQueReceboVagas.contestarExplicacao)
                BotaoPrimario(verbatim: TextosPorQueReceboVagas.botaoContestar) {
                    viewModel.abrirFormulario()
                }
                .accessibilityIdentifier("botao-contestar-despacho")
                .padding(.top, FrilaEspaco.item)
            }

            if let erro = viewModel.mensagemErro {
                AvisoFrila(verbatim: erro, tom: .erro)
                    .accessibilityIdentifier("aviso-erro-revisao")
            }
        }
    }

    /// O pedido de revisão: rótulo visível acima do campo, a dica e o contador (o 10 é o mínimo, não um limite) e os dois
    /// botões. Problema não tem cor: o visto do relato válido e o contador vão em tinta.
    private var formulario: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosPorQueReceboVagas.labelRelato)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                text: $viewModel.relato,
                prompt: Text(verbatim: TextosPorQueReceboVagas.promptRelato).foregroundStyle(FrilaCor.textoSecundario),
                axis: .vertical
            ) {
                Text(verbatim: TextosPorQueReceboVagas.labelRelato)
            }
            .lineLimit(4...8)
            .textFieldStyle(.plain)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .caixaDoCampoFrila(emFoco: focoNoRelato)
            .focused($focoNoRelato)
            .accessibilityIdentifier("campo-relato-despacho")
            .frilaFormField(id: "despacho-relato", isFocused: focoNoRelato, onDismiss: { focoNoRelato = false })

            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.item) {
                if viewModel.relatoValido {
                    Image(systemName: "checkmark")
                        .font(FrilaTipo.legenda.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityIdentifier("icone-relato-valido-despacho")
                }
                Text(verbatim: TextosPorQueReceboVagas.dicaRelato)
                    .font(FrilaTipo.legenda)
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.texto : FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                // V24: o 10 é o mínimo, não um limite. Acima dele o contador para em "10/10",
                // com o visto, em vez de "40/10", que parecia ter passado do limite.
                Text(verbatim: Self.contador(viewModel.relato))
                    .font(FrilaTipo.legenda.monospacedDigit())
                    .foregroundStyle(viewModel.relatoValido ? FrilaCor.texto : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-despacho")
                    .accessibilityLabel(Text(verbatim: viewModel.relatoValido ? TextosPorQueReceboVagas.relatoValidoAcessibilidade : Self.contador(viewModel.relato)))
            }

            layoutDosBotoes {
                BotaoPrimario(verbatim: TextosPorQueReceboVagas.botaoEnviar, carregando: viewModel.enviando) {
                    Task { await viewModel.contestar() }
                }
                .accessibilityIdentifier("botao-enviar-revisao")

                BotaoSecundario(verbatim: TextosPorQueReceboVagas.cancelar) {
                    viewModel.cancelarFormulario()
                }
                .accessibilityIdentifier("botao-cancelar-revisao")
            }
            .padding(.top, FrilaEspaco.item)
        }
    }

    /// Os dois botões empilhados em todos os tamanhos: lado a lado, "Enviar pedido" já quebrava em
    /// duas linhas no tamanho padrão (V24 da conferência visual da 1.1), e em AX se estrangulavam
    /// (QA do #105 na conta suspensa).
    private var layoutDosBotoes: AnyLayout { AnyLayout(VStackLayout(spacing: FrilaEspaco.item)) }

    /// Caracteres do relato até o mínimo de 10: "3/10" e, a partir dele, "10/10".
    static func contador(_ relato: String) -> String {
        "\(min(relato.trimmingCharacters(in: .whitespacesAndNewlines).count, 10))/10"
    }

    /// O protocolo do pedido enviado: o fato e os três dados (número, data e prazo), cada um com o rótulo em apoio acima.
    private func cartaoProtocolo(_ protocolo: Protocolo) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            FrilaLinhaDeDado(icone: "checkmark") {
                Text(verbatim: TextosPorQueReceboVagas.pedidoEnviado)
                    .font(FrilaTipo.rotuloSecundario)
            }
            .accessibilityIdentifier("status-revisao-enviada")

            dado(TextosPorQueReceboVagas.protocoloNumero) {
                // V23: o UUID inteiro quebrava deixando um "3" sozinho na linha. O número que o
                // suporte usa é o curto (contrato 0.2.40), o mesmo da Ajuda no turno: "#A0000000".
                Text(verbatim: "#" + protocolo.protocoloCurto)
                    .font(FrilaTipo.corpo.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("protocolo-revisao-despacho")
            }

            dado(TextosPorQueReceboVagas.protocoloData) {
                Text(verbatim: Self.formatarData(protocolo.criadaEm))
                    .font(FrilaTipo.corpo)
            }

            dado(TextosPorQueReceboVagas.prazoRespostaTitulo) {
                Text(verbatim: Self.formatarDataCivil(protocolo.prazoRespostaAte))
                    .font(FrilaTipo.rotuloSecundario)
                    .accessibilityIdentifier("prazo-resposta-revisao")
            }

            nota(TextosPorQueReceboVagas.mensagemEnviado)
        }
        .cartaoFrila()
    }

    private func dado(_ rotulo: String, @ViewBuilder valor: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            valor()
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func formatarData(_ data: Date) -> String {
        let formatador = DateFormatter()
        formatador.locale = FormatadorFrila.locale
        formatador.timeZone = FormatadorFrila.fuso
        formatador.dateFormat = "dd/MM/yyyy"
        return formatador.string(from: data)
    }

    private static func formatarDataCivil(_ data: DataCivil) -> String {
        String(format: "%02d/%02d/%04d", data.dia, data.mes, data.ano)
    }
}
