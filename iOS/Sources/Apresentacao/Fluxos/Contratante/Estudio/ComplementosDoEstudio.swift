import FrilaDominio
import SwiftUI

// O que o app acrescenta ao estúdio da origem, no desenho dela (tokens Frila*): o modo da vaga
// (urgência ou seleção, MS-RF01/D2), que o contrato tem e o protótipo não, e os avisos de fila,
// pendência e erro do `PublicarVagaViewModel`. Mesmos textos e identificadores do formulário antigo.

/// Modo da vaga no fim da etapa Turno: a seleção depende do início escolhido ali em cima.
struct ModoDaVagaDoEstudio: View {
    @Bindable var vaga: PublicarVagaViewModel
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space12) {
            Text(verbatim: TextosPublicarVaga.modo)
                .frilaType(FrilaFormType.fieldLabel, dynamic: true)
                .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))

            FrilaSegmentedControl(
                items: itens,
                selection: $vaga.modo,
                isDark: isDark,
                height: FrilaGeometry.buttonHeightStandard
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(TextosPublicarVaga.modo)
            .accessibilityIdentifier("modo-vaga-picker")
            .disabled(vaga.camposBloqueados)

            Text(verbatim: vaga.modo == .selecao ? TextosPublicarVaga.modoSelecaoExplicacao : TextosPublicarVaga.modoUrgenciaExplicacao)
                .frilaType(FrilaFormType.detail, dynamic: true)
                .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("modo-vaga-explicacao")

            if !vaga.selecaoDisponivel {
                Text(verbatim: TextosPublicarVaga.modoSelecaoSoComAntecedencia)
                    .frilaType(FrilaFormType.detail, dynamic: true)
                    .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("modo-selecao-indisponivel")
            }

            if let prazo = vaga.prazoDeEscolha {
                Text(verbatim: String(format: TextosPublicarVaga.modoSelecaoPrazo, FormatadorFrila().dataEHora(prazo)))
                    .frilaType(FrilaFormType.support, dynamic: true)
                    .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("prazo-de-escolha-publicacao")

                if vaga.janelaDeEscolhaCurta {
                    AvisoDoEstudio(icone: "exclamationmark.triangle", texto: TextosPublicarVaga.modoSelecaoPrazoCurto, isDark: isDark)
                        .accessibilityIdentifier("prazo-de-escolha-curto")
                }
            }

            if let erro = vaga.erros[.modo] {
                Label(erro, systemImage: "exclamationmark.circle.fill")
                    .frilaType(FrilaFormType.detail, dynamic: true)
                    .foregroundStyle(FrilaColor.dynamicError(isDark: isDark))
                    .accessibilityIdentifier("erro-publicacao-modo")
            }
        }
    }

    /// Seleção só é oferecida com o início a mais de 24 horas (MS-RF01), como no formulário antigo.
    private var itens: [FrilaSegmentedItem<ModoPreenchimento>] {
        var itens = [FrilaSegmentedItem(tag: ModoPreenchimento.urgencia, title: TextosPublicarVaga.modoUrgencia)]
        if vaga.selecaoDisponivel {
            itens.append(FrilaSegmentedItem(tag: ModoPreenchimento.selecao, title: TextosPublicarVaga.modoSelecao))
        }
        return itens
    }
}

/// Avisos do app no topo do formulário: publicação pendente, recusa da fila, erro e continuação sem rede.
struct AvisosDoEstudio: View {
    let vaga: PublicarVagaViewModel
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space12) {
            if vaga.restaurandoPublicacao {
                AvisoDoEstudio(icone: "arrow.triangle.2.circlepath", texto: TextosPublicarVaga.verificandoPendente, isDark: isDark)
            } else if vaga.camposBloqueados {
                AvisoDoEstudio(icone: "info.circle", texto: TextosPublicarVaga.pendenteDescricao, isDark: isDark)
            }
            if let erro = vaga.erros[.estabelecimento] {
                AvisoDoEstudio(icone: "exclamationmark.triangle", texto: erro, isDark: isDark)
            }
            if let recusa = vaga.recusaDaFila {
                VStack(alignment: .leading, spacing: FrilaGeometry.space8) {
                    AvisoDoEstudio(icone: "exclamationmark.triangle", texto: TextosDaFila.texto(recusa.tipo), isDark: isDark)
                        .accessibilityIdentifier("aviso-publicacao-recusada")
                    Button {
                        Task { await vaga.fecharAvisoDaFila() }
                    } label: {
                        Text("Fechar", bundle: bundleApresentacao)
                            .font(FrilaTypography.button)
                            .padding(.horizontal, FrilaGeometry.space20)
                            .frame(height: FrilaGeometry.buttonHeightStandard)
                    }
                    .buttonStyle(FrilaPillButtonStyle(variant: .outline, isDark: isDark))
                    .accessibilityIdentifier("fechar-aviso-publicacao-recusada")
                }
            }
            if let erro = vaga.mensagemErro {
                AvisoDoEstudio(icone: "exclamationmark.triangle", texto: erro, isDark: isDark)
                    .accessibilityIdentifier("aviso-erro-publicacao")
            }
            if vaga.mostraAvisoPublicacaoContinua {
                AvisoDoEstudio(icone: "wifi.slash", texto: TextosPublicarVaga.publicacaoContinua, isDark: isDark)
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
struct AvisoDoEstudio: View {
    let icone: String
    let texto: String
    let isDark: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaGeometry.space10) {
            Image(systemName: icone)
                .font(FrilaFonteDoSistema.fonte(size: 15, weight: .semibold))
                .foregroundStyle(FrilaColor.dynamicBrandAccent(isDark: isDark))
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .frilaType(FrilaFormType.support, dynamic: true)
                .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaGeometry.space16)
        .background(FrilaColor.dynamicFormCardSurface(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
        }
        .frilaFormLift(isDark: isDark)
        // O cartão é um elemento com rótulo (o texto), e o texto segue consultável por dentro.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(texto)
    }
}
