// VISUAL PROVISÓRIO: a tela de explicação e o estado negado ainda não têm design (#8). Os textos
// estão em `TextosDoPush`.

import FrilaDominio
import SwiftUI

/// A explicação que vem antes do pedido do sistema: diz para que serve a notificação e deixa a
/// pessoa escolher. Sem ela, o pedido do sistema apareceria sem contexto, e ele só aparece uma vez.
public struct TelaExplicacaoDoPush: View {
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
                    .font(.largeTitle)
                    .foregroundStyle(FrilaCor.primaria)
                    .accessibilityHidden(true)
                Text(verbatim: TextosDoPush.Explicacao.titulo)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: TextosDoPush.Explicacao.mensagem(perfil))
                    .font(.body)
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    ForEach(TextosDoPush.Explicacao.itens(perfil), id: \.self) { item in
                        Label {
                            Text(verbatim: item)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(FrilaCor.sucesso)
                        }
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
                    .font(.footnote)
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
                    Task { await modelo.oferecer() }
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
