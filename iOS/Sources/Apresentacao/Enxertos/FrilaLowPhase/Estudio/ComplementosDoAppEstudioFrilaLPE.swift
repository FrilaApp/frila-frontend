import FrilaDominio
import SwiftUI

// O que o app acrescenta ao estúdio da origem, no desenho dela (tokens FrilaLPE): o modo da vaga
// (urgência ou seleção, MS-RF01/D2), que o contrato tem e o protótipo não, e os avisos de fila,
// pendência e erro do `PublicarVagaViewModel`. Mesmos textos e identificadores do formulário antigo.

/// Modo da vaga no fim da etapa Turno: a seleção depende do início escolhido ali em cima.
struct ModoDaVagaEstudioFrilaLPE: View {
    @Bindable var vaga: PublicarVagaViewModel
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space12) {
            Text(verbatim: TextosPublicarVaga.modo)
                .frilaLPEType(FrilaLPEFormType.fieldLabel, dynamic: true)
                .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))

            FrilaLPESegmentedControl(
                items: itens,
                selection: $vaga.modo,
                isDark: isDark,
                height: FrilaLPEGeometry.buttonHeightStandard
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(TextosPublicarVaga.modo)
            .accessibilityIdentifier("modo-vaga-picker")
            .disabled(vaga.camposBloqueados)

            Text(verbatim: vaga.modo == .selecao ? TextosPublicarVaga.modoSelecaoExplicacao : TextosPublicarVaga.modoUrgenciaExplicacao)
                .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                .foregroundStyle(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("modo-vaga-explicacao")

            if !vaga.selecaoDisponivel {
                Text(verbatim: TextosPublicarVaga.modoSelecaoSoComAntecedencia)
                    .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                    .foregroundStyle(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("modo-selecao-indisponivel")
            }

            if let prazo = vaga.prazoDeEscolha {
                Text(verbatim: String(format: TextosPublicarVaga.modoSelecaoPrazo, FormatadorFrila().dataEHora(prazo)))
                    .frilaLPEType(FrilaLPEFormType.support, dynamic: true)
                    .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("prazo-de-escolha-publicacao")

                if vaga.janelaDeEscolhaCurta {
                    AvisoEstudioFrilaLPE(icone: "exclamationmark.triangle", texto: TextosPublicarVaga.modoSelecaoPrazoCurto, isDark: isDark)
                        .accessibilityIdentifier("prazo-de-escolha-curto")
                }
            }

            if let erro = vaga.erros[.modo] {
                Label(erro, systemImage: "exclamationmark.circle.fill")
                    .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                    .foregroundStyle(FrilaLPEColor.dynamicError(isDark: isDark))
                    .accessibilityIdentifier("erro-publicacao-modo")
            }
        }
    }

    /// Seleção só é oferecida com o início a mais de 24 horas (MS-RF01), como no formulário antigo.
    private var itens: [FrilaLPESegmentedItem<ModoPreenchimento>] {
        var itens = [FrilaLPESegmentedItem(tag: ModoPreenchimento.urgencia, title: TextosPublicarVaga.modoUrgencia)]
        if vaga.selecaoDisponivel {
            itens.append(FrilaLPESegmentedItem(tag: ModoPreenchimento.selecao, title: TextosPublicarVaga.modoSelecao))
        }
        return itens
    }
}

/// Avisos do app no topo do formulário: publicação pendente, recusa da fila, erro e continuação sem rede.
struct AvisosDoEstudioFrilaLPE: View {
    let vaga: PublicarVagaViewModel
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space12) {
            if vaga.restaurandoPublicacao {
                AvisoEstudioFrilaLPE(icone: "arrow.triangle.2.circlepath", texto: TextosPublicarVaga.verificandoPendente, isDark: isDark)
            } else if vaga.camposBloqueados {
                AvisoEstudioFrilaLPE(icone: "info.circle", texto: TextosPublicarVaga.pendenteDescricao, isDark: isDark)
            }
            if let erro = vaga.erros[.estabelecimento] {
                AvisoEstudioFrilaLPE(icone: "exclamationmark.triangle", texto: erro, isDark: isDark)
            }
            if let recusa = vaga.recusaDaFila {
                VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
                    AvisoEstudioFrilaLPE(icone: "exclamationmark.triangle", texto: TextosDaFila.texto(recusa.tipo), isDark: isDark)
                        .accessibilityIdentifier("aviso-publicacao-recusada")
                    Button {
                        Task { await vaga.fecharAvisoDaFila() }
                    } label: {
                        Text("Fechar", bundle: bundleApresentacao)
                            .font(FrilaLPETypography.button)
                            .padding(.horizontal, FrilaLPEGeometry.space20)
                            .frame(height: FrilaLPEGeometry.buttonHeightStandard)
                    }
                    .buttonStyle(FrilaLPEPillButtonStyle(variant: .outline, isDark: isDark))
                    .accessibilityIdentifier("fechar-aviso-publicacao-recusada")
                }
            }
            if let erro = vaga.mensagemErro {
                AvisoEstudioFrilaLPE(icone: "exclamationmark.triangle", texto: erro, isDark: isDark)
                    .accessibilityIdentifier("aviso-erro-publicacao")
            }
            if vaga.mostraAvisoPublicacaoContinua {
                AvisoEstudioFrilaLPE(icone: "wifi.slash", texto: TextosPublicarVaga.publicacaoContinua, isDark: isDark)
                    .accessibilityIdentifier("aviso-publicacao-continua")
            }
        }
    }

    /// Há algo a mostrar: sem aviso o estúdio não reserva espaço acima da primeira etapa.
    var temConteudo: Bool {
        vaga.restaurandoPublicacao || vaga.camposBloqueados || vaga.erros[.estabelecimento] != nil
            || vaga.recusaDaFila != nil || vaga.mensagemErro != nil || vaga.mostraAvisoPublicacaoContinua
    }
}

/// Cartão de aviso no desenho dos cartões do formulário da origem (superfície, borda e elevação).
struct AvisoEstudioFrilaLPE: View {
    let icone: String
    let texto: String
    let isDark: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaLPEGeometry.space10) {
            Image(systemName: icone)
                .font(FrilaLPEFonteDoSistema.fonte(size: 15, weight: .semibold))
                .foregroundStyle(FrilaLPEColor.dynamicBrandAccent(isDark: isDark))
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .frilaLPEType(FrilaLPEFormType.support, dynamic: true)
                .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaLPEGeometry.space16)
        .background(FrilaLPEColor.dynamicFormCardSurface(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaLPEColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
        }
        .frilaLPEFormLift(isDark: isDark)
        // O cartão é um elemento com rótulo (o texto), e o texto segue consultável por dentro.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(texto)
    }
}
