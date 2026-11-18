import FrilaDominio
import SwiftUI

/// Cartão de vaga do feed (T2 do protótipo, forma "atual" do `CartaoDeVaga` do Fabrício). Quem é a casa e o modo
/// da vaga, "dá para ir?" (função, quando, onde), linha fina e "compensa?" (o valor é o maior texto do cartão).
/// O cartão inteiro é um alvo só; o botão de dentro só mostra o que o toque faz. O cartão em destaque é o único
/// com botão laranja e sombra suave; os demais levam o botão secundário.
/// Mantém o que o cartão do sistema (`CartaoVaga`) dizia: posições abertas, o que vem incluso, a reputação da
/// casa e o rótulo falado, que são comportamento do produto.
struct CartaoDeVagaDoFeed: View {
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    @Environment(\.cartaoDeVagaPressionado) private var pressionado
    let vaga: VagaNaLista
    let emDestaque: Bool
    var agora: Date = .now
    private let formatador = FormatadorFrila()

    /// Só o cartão em destaque tem sombra e botão laranja: o da primeira vaga de aceite direto da lista.
    static func destaque(em vagas: [VagaNaLista], agora: Date = .now) -> UUID? {
        vagas.first { vaga in
            FormatoDataVaga.modoEfetivo(modo: vaga.modo, posicoesAbertas: vaga.posicoesAbertas,
                                        inicio: vaga.periodo.inicio, agora: agora) == .urgencia
        }?.id
    }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            identidade
            viabilidade
                .padding(.top, FrilaEspaco.grupo)
            FrilaDivisoria()
            compensa
            botaoVisual
                .padding(.top, FrilaEspaco.grupo)
        }
        .padding(EdgeInsets(top: FrilaEspaco.grupo, leading: FrilaEspaco.bloco + 4,
                            bottom: FrilaEspaco.bloco + 4, trailing: FrilaEspaco.bloco + 4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pressionado && !emDestaque ? FrilaCor.superficiePressionada : FrilaCor.superficie, in: forma)
        .overlay(forma.strokeBorder(FrilaCor.divisoria, lineWidth: 1))
        .elevacaoFrila(emDestaque ? .suave : .nenhuma)
        .contentShape(forma)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: CartaoVaga(vaga, agora: agora).rotuloDeAcessibilidade))
    }

    // MARK: Quem

    /// A casa, o selo do modo e a reputação.
    private var identidade: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: FrilaEspaco.item) {
                    nome
                    Spacer(minLength: FrilaEspaco.item)
                    selo
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    selo
                    nome
                }
            }
            Text(verbatim: reputacao)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nome: some View {
        Text(verbatim: vaga.estabelecimento.nome)
            .font(FrilaTipo.nome)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var selo: some View {
        if modoEfetivo == .urgencia {
            SeloDeStatus("Urgência", estilo: .urgencia, icone: "bolt.fill")
        } else {
            SeloDeStatus("Por seleção", estilo: .contorno)
        }
    }

    private var reputacao: String {
        let reputacao = vaga.estabelecimento.reputacao
        if reputacao.semHistorico {
            return String(localized: "Ainda sem avaliações.", bundle: bundleApresentacao)
        }
        return String(localized: "\(reputacao.positivas) de \(reputacao.total) avaliações indicam que trabalhariam lá de novo", bundle: bundleApresentacao)
    }

    // MARK: Dá para ir?

    /// Função, quando e onde, com o ícone de cada dado.
    private var viabilidade: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            FrilaLinhaDeDado(icone: "briefcase") {
                Text(verbatim: vaga.funcao.nome)
            }
            FrilaLinhaDeDado(icone: "calendar") {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: FormatoDataVaga.quando(vaga.periodo.inicio, agora: agora))
                    Text(verbatim: FormatoDataVaga.janela(vaga.periodo))
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }
            FrilaLinhaDeDado(icone: "mappin.and.ellipse") {
                Text(verbatim: localizacao)
            }
        }
    }

    private var localizacao: String {
        let regiao = vaga.regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        let lugar = regiao.isEmpty ? vaga.local : regiao
        return "\(formatador.distancia(vaga.distanciaKm)), \(lugar)"
    }

    // MARK: Compensa?

    /// O valor é o maior texto do cartão, em tinta; o que vem incluso e as posições vão abaixo, em apoio.
    private var compensa: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            let disposicao = tamanhoDoTexto.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: FrilaEspaco.junto))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: FrilaEspaco.item))
            disposicao {
                Text(verbatim: formatador.dinheiro(vaga.valor))
                    .font(FrilaTipo.valorEmDestaque)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityLabel(Text(verbatim: FrilaMoney.spoken(cents: vaga.valor.centavos, por: "pessoa")))
                Text(verbatim: TextosDoProfissional.Detalhe.porPessoa)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }
            Text(verbatim: beneficios)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: posicoes)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var beneficios: String {
        switch (vaga.inclusos.refeicao, vaga.inclusos.transporte) {
        case (true, true): String(localized: "Refeição e transporte inclusos", bundle: bundleApresentacao)
        case (true, false): String(localized: "Refeição inclusa, sem transporte", bundle: bundleApresentacao)
        case (false, true): String(localized: "Sem refeição, transporte incluso", bundle: bundleApresentacao)
        case (false, false): String(localized: "Sem refeição nem transporte", bundle: bundleApresentacao)
        }
    }

    private var posicoes: String {
        TextosDoProfissional.Lista.posicoes(vaga.posicoesAbertas, modo: modoEfetivo)
    }

    private var modoEfetivo: ModoPreenchimento {
        FormatoDataVaga.modoEfetivo(modo: vaga.modo, posicoesAbertas: vaga.posicoesAbertas,
                                    inicio: vaga.periodo.inicio, agora: agora)
    }

    // MARK: Ação

    /// O rótulo do que o toque faz, com o desenho do botão: laranja no cartão em destaque, secundário nos outros.
    /// Não é um botão de verdade (o cartão inteiro é o alvo), então não entra na ordem de foco.
    private var botaoVisual: some View {
        let papel: EstiloDoBotaoFrila.Papel = emDestaque ? .primario : .secundario
        let cores = EstiloDoBotaoFrila.cores(papel: papel, emConferencia: false, pressionado: pressionado)
        let forma = FrilaForma.capsulaQueCresce()
        return Text("Ver detalhes da vaga", bundle: bundleApresentacao)
            .font(emDestaque ? FrilaTipo.botaoPrimario : FrilaTipo.rotuloSecundario)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, FrilaEspaco.bloco)
            .padding(.vertical, FrilaEspaco.item)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .foregroundStyle(cores.rotulo)
            .background(cores.fundo, in: forma)
            .overlay { if let borda = cores.borda { forma.strokeBorder(borda, lineWidth: 1) } }
            .accessibilityHidden(true)
    }
}

/// O estilo do botão que embrulha o cartão: diz ao cartão quando o dedo está em cima (D-DS-03), sem mexer no tamanho.
struct EstiloDoCartaoDeVagaDoFeed: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.cartaoDeVagaPressionado, configuration.isPressed)
    }
}

private struct CartaoDeVagaPressionadoChave: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var cartaoDeVagaPressionado: Bool {
        get { self[CartaoDeVagaPressionadoChave.self] }
        set { self[CartaoDeVagaPressionadoChave.self] = newValue }
    }
}
