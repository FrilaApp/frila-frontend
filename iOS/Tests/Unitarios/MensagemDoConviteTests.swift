@testable import FrilaApresentacao
import Foundation
import FrilaDominio
import Testing

/// A mensagem que o administrador compartilha ou copia depois de gerar o convite (B-123, ROPA linha 31, regra 2):
/// quem convida, para quê, o e-mail que confere o convite, a validade, o que o Frila faz com o e-mail e onde está a Política,
/// com o link na última linha. O texto é o mesmo nos três apps (Web, Android e iOS).
@Suite("Mensagem do convite de membro")
struct MensagemDoConviteTests {
    /// Montado na hora: nenhum código de convite no repositório.
    private static let token = String(repeating: "ef", count: 32)
    private static let link = "https://frilabr.com/app/convite#\(token)"
    /// 15/01/2027 às 05:00 em São Paulo, o mesmo texto de prazo que a tela mostra (`FormatadorFrila.dataEHora`).
    private static let validade = Date(timeIntervalSince1970: 1_800_000_000)

    private func convite(papel: PapelMembro = .operador, email: String = "paulo.lima@exemplo.com", casa: String = "Padaria do Bairro",
                         validade: Date? = MensagemDoConviteTests.validade) -> ConviteGerado {
        ConviteGerado(link: Self.link, email: email, papel: papel, nomeDaCasa: casa, expiraEm: validade)
    }

    @Test("Com prazo: a mensagem é exatamente o texto aprovado, preenchido, com o link na última linha")
    func comPrazo() {
        let esperado = "Padaria do Bairro convidou você para a equipe da casa no Frila, como operador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail paulo.lima@exemplo.com. O convite vale uma vez, até 15/01/2027 às 05:00. O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. Política de Privacidade: https://frilabr.com/privacidade\n\(Self.link)"
        #expect(convite().mensagem == esperado)
    }

    @Test("Sem prazo: igual, trocando a validade por \"O convite vale uma vez.\", sem marcador vazio")
    func semPrazo() {
        let esperado = "Padaria do Bairro convidou você para a equipe da casa no Frila, como operador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail paulo.lima@exemplo.com. O convite vale uma vez. O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. Política de Privacidade: https://frilabr.com/privacidade\n\(Self.link)"
        let mensagem = convite(validade: nil).mensagem
        #expect(mensagem == esperado)
        #expect(!mensagem.contains("até :") && !mensagem.contains("até ."))
    }

    @Test("O papel sai em minúsculo e certo para os dois papéis")
    func papelEmMinusculo() {
        #expect(convite(papel: .administrador).mensagem.contains("no Frila, como administrador. Para aceitar"))
        #expect(convite(papel: .operador).mensagem.contains("no Frila, como operador. Para aceitar"))
    }

    @Test("O e-mail da mensagem é o que o administrador digitou, sem espaços nas pontas, e a casa é a da tela")
    func emailAparadoECasa() {
        let m = convite(email: "  ana@exemplo.com \n", casa: "Bistrô da Esquina").mensagem
        #expect(m.hasPrefix("Bistrô da Esquina convidou você"))
        #expect(m.contains("entre no Frila com o e-mail ana@exemplo.com. O convite"))
    }

    @Test("A mensagem tem a frase da Política e termina no link, numa linha só dele")
    func terminaNoLinkEDizAPolitica() {
        for validade in [Self.validade, nil] {
            let m = convite(validade: validade).mensagem
            #expect(m.contains("Política de Privacidade: https://frilabr.com/privacidade"))
            #expect(m.contains("o apaga em até 30 dias depois de ele vencer ou ser aceito"))
            #expect(m.hasSuffix("\n" + Self.link))
            #expect(m.split(separator: "\n").last.map(String.init) == Self.link)
            #expect(m.split(separator: "\n").count == 2)
        }
    }

    @Test("O texto de prazo da mensagem é o mesmo da frase de \"convite pronto\" da tela")
    func prazoIgualAoDaTela() {
        let prazo = FormatadorFrila().dataEHora(Self.validade)
        #expect(convite().mensagem.contains("O convite vale uma vez, até \(prazo)."))
        #expect(String(format: TextosDaEquipeDaCasa.convitePronto, prazo).contains(prazo))
    }
}
