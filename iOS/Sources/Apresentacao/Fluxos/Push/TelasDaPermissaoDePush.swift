import FrilaDominio
import SwiftUI

/// A explicação que vem antes do pedido do sistema: diz para que serve a notificação e deixa a
/// pessoa escolher. Sem ela, o pedido do sistema apareceria sem contexto, e ele só aparece uma vez.
/// Segue o quadro "PermissaoNotificacao" do MidFi do Fabrício: círculo de 72 pt, título, apoio e itens com visto.
public struct TelaExplicacaoDoPush: View {
    @ScaledMetric(relativeTo: .subheadline) private var diametroDoVisto: CGFloat = 24
    private let modelo: PermissaoDePushModelo
    private let perfil: PerfilConta

    public init(modelo: PermissaoDePushModelo, perfil: PerfilConta) {
        self.modelo = modelo
        self.perfil = perfil
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                cabecalho

                if perfil == .profissional {
                    amostraNotificacaoProfissional
                    beneficiosProfissional
                } else {
                    beneficiosContratante
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.top, FrilaEspaco.medio)
            .padding(.bottom, FrilaEspaco.enorme * 3)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .accessibilityIdentifier("explicacao-do-push")
        .barraInferiorFixa {
            barraInferiorConteudo
        }
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Image(systemName: "bell.badge.fill")
                .font(.title)
                .foregroundStyle(FrilaCor.texto)
                .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                .background(FrilaCor.controle, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: TextosDoPush.Explicacao.titulo(perfil))
                    .font(FrilaTipo.tituloGrande)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: TextosDoPush.Explicacao.mensagem(perfil))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
        }
    }

    // MARK: - Amostra Ilustrativa Profissional

    private var amostraNotificacaoProfissional: some View {
        HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
            Text("F", bundle: bundleApresentacao)
                .font(FrilaTipo.resumo.weight(.bold))
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .frame(width: 38, height: 38)
                .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: TextosDoPush.Explicacao.amostraCargoHorario)
                        .font(FrilaTipo.meta.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                    Spacer(minLength: FrilaEspaco.minimo)
                    Text(verbatim: TextosDoPush.Explicacao.amostraAgora)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                Text(verbatim: TextosDoPush.Explicacao.amostraDetalhe)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                .strokeBorder(FrilaCor.divisoria, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    // MARK: - Benefícios Profissionais

    private var beneficiosProfissional: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(TextosDoPush.Explicacao.itens(.profissional), id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(FrilaCor.controle)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(FrilaTipo.microRotulo)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: item)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Benefícios Contratante

    private var beneficiosContratante: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            ForEach(TextosDoPush.Explicacao.itens(.contratante), id: \.self) { item in
                HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
                    Image(systemName: "checkmark")
                        .font(FrilaTipo.microRotulo)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(width: diametroDoVisto, height: diametroDoVisto)
                        .background(FrilaCor.controle, in: Circle())
                        .accessibilityHidden(true)
                    Text(verbatim: item)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.texto)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
    }

    // MARK: - Barra inferior fixa

    private var barraInferiorConteudo: some View {
        VStack(spacing: FrilaEspaco.compacto) {
            BotaoPrimario(verbatim: TextosDoPush.Explicacao.ativar, carregando: modelo.pedindo) {
                Task { await modelo.ativar() }
            }
            .disabled(modelo.pedindo)
            .accessibilityIdentifier("ativar-notificacoes")

            Button {
                modelo.agoraNao()
            } label: {
                Text(verbatim: TextosDoPush.Explicacao.agoraNao)
                    .font(FrilaTipo.meta.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(modelo.pedindo)
            .accessibilityIdentifier("notificacoes-agora-nao")

            Text(verbatim: TextosDoPush.Explicacao.rodape)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
        .frame(maxWidth: .infinity)
    }
}

/// O aviso fixo de quem está sem notificação, em Vagas e em Minhas vagas. Com a permissão negada,
/// o caminho é pelos Ajustes do sistema; se o sistema ainda não perguntou, é a tela de explicação.
/// Com a permissão concedida, ou sem o modelo no ambiente (prévias), não ocupa espaço.
/// O bloco segue o aviso neutro do quadro "VagasSemNotificacao" do MidFi do Fabrício.
public struct AvisoDePermissaoDePush: View {
    @Environment(PermissaoDePushModelo.self) private var modelo: PermissaoDePushModelo?
    private let perfil: PerfilConta

    public init(perfil: PerfilConta) {
        self.perfil = perfil
    }

    public var body: some View {
        if let modelo {
            switch modelo.estado {
            case .negada:
                aviso(TextosDoPush.Aviso.negada(perfil), tom: .alerta, botao: TextosDoPush.Aviso.abrirAjustes, id: "abrir-ajustes-de-notificacao") {
                    modelo.abrirAjustes()
                }
                .accessibilityIdentifier("aviso-push-negado")
            case .naoPedida:
                aviso(TextosDoPush.Aviso.naoPedida(perfil), tom: .informativo, botao: TextosDoPush.Explicacao.ativar, id: "explicar-notificacoes") {
                    Task { await modelo.reabrir() }
                }
                .accessibilityIdentifier("aviso-push-nao-pedido")
            case .concedida, nil:
                EmptyView()
            }
        }
    }

    private func aviso(_ texto: String, tom: AvisoFrila.Tom, botao: String, id: String, acao: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            AvisoFrila(verbatim: texto, tom: tom)
            BotaoSecundario(verbatim: botao, acao: acao)
                .accessibilityIdentifier(id)
        }
        .accessibilityElement(children: .contain)
    }
}

private extension View {
    @ViewBuilder
    func barraInferiorFixa<Content: View>(@ViewBuilder conteudo: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                conteudo()
            }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FrilaCor.divisoria)
                        .frame(height: 1)
                    conteudo()
                }
                .background(.regularMaterial)
            }
        }
    }
}
