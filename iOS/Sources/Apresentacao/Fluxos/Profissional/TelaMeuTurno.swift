import FrilaDominio
import SwiftUI

public struct TelaMeuTurno: View {
    @Bindable private var viewModel: MeuTurnoViewModel
    private let formatador = FormatadorFrila()

    public init(viewModel: MeuTurnoViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                cabecalho
                cartaoTurno
                cartaoContato
                if viewModel.podeAvaliar {
                    cartaoAvaliacao
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDoProfissional.Turnos.tituloMeuTurno)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.carregar() }
        .accessibilityIdentifier("tela-meu-turno")
    }

    private var cabecalho: some View {
        Text(TextosDoProfissional.Turnos.confirmadoTitulo)
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
    }

    private var cartaoTurno: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text("\(viewModel.turno.vaga.funcao) · \(viewModel.turno.contraparte.nome)")
                .font(.headline)
            Text("\(formatador.intervalo(viewModel.turno.vaga.periodo)) · \(formatador.dinheiro(viewModel.turno.valorAcordado))")
                .font(.subheadline)

            HStack(spacing: FrilaEspaco.minimo) {
                Text(viewModel.turno.vaga.local)
                if let urlMapas = viewModel.urlMapas {
                    Link(destination: urlMapas) {
                        Image(systemName: "map")
                            .foregroundStyle(FrilaCor.primaria)
                    }
                    .accessibilityIdentifier("atalho-mapas")
                    .accessibilityLabel(TextosDoProfissional.Turnos.verNoMapas)
                    .accessibilityHint(String(localized: "Abre o endereço no Apple Maps", bundle: bundleApresentacao))
                }
                Text("· \(TextosDoProfissional.Turnos.quemRecebe): \(viewModel.quemRecebeExibicao)")
            }
            .font(.subheadline)
            .foregroundStyle(FrilaCor.textoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    private var cartaoContato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(TextosDoProfissional.Candidatura.contato.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            if viewModel.contatoExpirado {
                Text(TextosDoProfissional.Turnos.contatoEncerrado)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contato-expirado-aviso")
            } else if let contato = viewModel.contato {
                Text("\(contato.nome) · \(contato.telefone)")
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("contato-telefone")

                if let urlWhatsApp = viewModel.urlWhatsApp {
                    Link(destination: urlWhatsApp) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text(TextosDoProfissional.Candidatura.abrirWhatsApp)
                        }
                    }
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .accessibilityIdentifier("botao-whatsapp")
                    .accessibilityHint(String(localized: "Abre a conversa no WhatsApp com mensagem pré-formatada", bundle: bundleApresentacao))
                }

                Text(TextosDoProfissional.Turnos.lembretesEVisibilidade)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
            } else if viewModel.carregandoContato {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityIdentifier("contato-do-turno")
    }

    private var cartaoAvaliacao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(TextosDoProfissional.Avaliacao.cartaoTitulo.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            if viewModel.jaAvaliado {
                if let resposta = viewModel.respostaAvaliacao {
                    Text(TextosDoProfissional.Avaliacao.statusResposta(resposta))
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("texto-status-avaliacao")
                } else {
                    Text(TextosDoProfissional.Avaliacao.statusAvaliado)
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("texto-status-avaliacao")
                }

                NavigationLink {
                    TelaAvaliacao(viewModel: viewModel.criarAvaliacaoViewModel())
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(TextosDoProfissional.Avaliacao.botaoVerAvaliacao)
                    }
                }
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityIdentifier("botao-ver-avaliacao")
            } else {
                Text(TextosDoProfissional.Avaliacao.cartaoChamada)
                    .font(.subheadline)
                    .foregroundStyle(FrilaCor.textoSecundario)

                NavigationLink {
                    TelaAvaliacao(viewModel: viewModel.criarAvaliacaoViewModel())
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(TextosDoProfissional.Avaliacao.botaoAvaliar)
                    }
                }
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .accessibilityIdentifier("botao-abrir-avaliacao")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityIdentifier("cartao-avaliacao-turno")
    }
}

