@testable import FrilaApresentacao
import FrilaDominio
import SwiftUI
import Testing

@Suite("Componentes Restantes - Lote 1 (SearchCapsule, ProposalBar, EditorialTag)")
@MainActor
struct ComponentesLote1Tests {

    // MARK: - EditorialTag

    @Test("EditorialTag e FrilaEditorialTag instanciam corretamente e preservam texto")
    func editorialTagInstanciacao() {
        let tag = FrilaEditorialTag("CONTRATO VERIFICADO")
        #expect(tag.text == "CONTRATO VERIFICADO")
        #expect(tag.isDark == false)
        #expect(tag.textColor == nil)

        let tagEscura: EditorialTag = EditorialTag(text: "STAFF", isDark: true)
        #expect(tagEscura.text == "STAFF")
        #expect(tagEscura.isDark == true)
    }

    @Test("FrilaTipografia é alias válido para FrilaTipo")
    func tipografiaAliasValido() {
        #expect(FrilaTipografia.microRotulo == FrilaTipo.microRotulo)
        #expect(FrilaTipografia.botao == FrilaTipo.botao)
        #expect(FrilaTipografia.corpo == FrilaTipo.corpo)
    }

    // MARK: - SearchCapsule

    @Test("SearchCapsule e FrilaSearchCapsule instanciam com valores padrão e personalizados")
    func searchCapsuleInstanciacao() {
        let padrao = FrilaSearchCapsule()
        #expect(padrao.craftQuery == "Design Tech")
        #expect(padrao.termsQuery == "Retainer")
        #expect(padrao.budgetQuery == "R$ 120–R$ 160/h")
        #expect(padrao.activeCount == 38)
        #expect(padrao.isGlass == true)

        let personalizada: SearchCapsule = SearchCapsule(
            isDark: true,
            isGlass: false,
            activeCount: 15,
            craftQuery: "iOS Swift",
            termsQuery: "Turno Único",
            budgetQuery: "R$ 150/h"
        )
        #expect(personalizada.isDark == true)
        #expect(personalizada.isGlass == false)
        #expect(personalizada.activeCount == 15)
        #expect(personalizada.craftQuery == "iOS Swift")
        #expect(personalizada.termsQuery == "Turno Único")
        #expect(personalizada.budgetQuery == "R$ 150/h")
    }

    @Test("SearchCapsule dispara o callback na seleção de zona")
    func searchCapsuleCallbackDisparado() {
        var zonaSelecionada: Int?
        let capsula = FrilaSearchCapsule { indice in
            zonaSelecionada = indice
        }

        capsula.onSelectZone(2)
        #expect(zonaSelecionada == 2)

        capsula.onSelectZone(0)
        #expect(zonaSelecionada == 0)
    }

    // MARK: - ProposalBar

    @Test("ProposalBar e FrilaProposalBar realizam cálculos com valor 100% integral e direto sem retenção de taxas (DP-01)")
    func proposalBarCalculosDeRetencao() {
        let barra = FrilaProposalBar(
            hourlyRate: 160,
            totalEstimate: 25600
        )

        #expect(barra.hourlyRate == 160)
        #expect(barra.totalEstimate == 25600)

        // Valida diretamente a struct CalculoDeRetencao e propriedades do componente (sem taxas de plataforma - DP-01)
        #expect(barra.calculoDeRetencao.taxaLiquidaHora == 160)
        #expect(barra.calculoDeRetencao.totalLiquido == 25600)
        #expect(barra.calculoDeRetencao.taxaPlataforma == 0)

        #expect(barra.netRate == 160)
        #expect(barra.netTotal == 25600)
        #expect(barra.platformFee == 0)

        let calculoOutro = FrilaProposalBar.CalculoDeRetencao(valorHora: 200, totalEstimado: 10000)
        #expect(calculoOutro.taxaLiquidaHora == 200)
        #expect(calculoOutro.totalLiquido == 10000)
        #expect(calculoOutro.taxaPlataforma == 0)
    }

    @Test("ProposalBar dispara ação de envio onSubmit")
    func proposalBarEnvioDisparado() {
        var enviado = false
        let barra: ProposalBar = ProposalBar(
            hourlyRate: 200,
            totalEstimate: 10000,
            isSubmitting: false
        ) {
            enviado = true
        }

        barra.onSubmit()
        #expect(enviado == true)
    }
}
