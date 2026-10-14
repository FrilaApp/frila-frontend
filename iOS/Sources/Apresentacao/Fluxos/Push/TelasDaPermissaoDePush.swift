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
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Image(systemName: "bell.badge.fill")
                    .font(.title)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                    .background(FrilaCor.controle, in: Circle())
                    .accessibilityHidden(true)
                Text(verbatim: TextosDoPush.Explicacao.titulo)
                    .font(FrilaTipo.tituloGrande)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: TextosDoPush.Explicacao.mensagem(perfil))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
                    ForEach(TextosDoPush.Explicacao.itens(perfil), id: \.self) { item in
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

                BotaoPrimario(verbatim: TextosDoPush.Explicacao.ativar, carregando: modelo.pedindo) {
                    Task { await modelo.ativar() }
                }
                .disabled(modelo.pedindo)
                .accessibilityIdentifier("ativar-notificacoes")
                BotaoSecundario(verbatim: TextosDoPush.Explicacao.agoraNao) { modelo.agoraNao() }
                    .accessibilityIdentifier("notificacoes-agora-nao")
                Text(verbatim: TextosDoPush.Explicacao.rodape)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .accessibilityIdentifier("explicacao-do-push")
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
