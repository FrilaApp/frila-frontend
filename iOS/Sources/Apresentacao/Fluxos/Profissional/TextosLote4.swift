import Foundation
import FrilaDominio

public enum TextosLote4 {
    // MARK: - T1c Ponto base
    public static let pontoBase = "Ponto base"
    public static let pontoBaseApoio = "As distâncias das vagas partem daqui."
    public static let buscarEndereco = "Buscar endereço"
    public static let limparBusca = "Limpar busca"
    public static func buscaSemResultado(_ termo: String) -> String {
        "Nenhum endereço encontrado para “\(termo)”."
    }
    public static let dicaBuscaSemResultado = "Confira a quadra e o bloco."
    public static let concluir = "Concluir"
    public static let salvo = "salvo"

    // MARK: - T2b Filtros
    public static let filtros = "Filtros"
    public static func vagasComFiltros(_ total: Int) -> String {
        total == 1 ? "1 vaga com estes filtros." : "\(total) vagas com estes filtros."
    }
    public static let funcoes = "Funções"
    public static let buscarFuncao = "Buscar função"
    public static let verTodasFuncoes = "Ver todas as funções"
    public static let datas = "Datas"
    public static let periodos = "Períodos"
    public static func ateKm(_ km: Int) -> String { "Até \(km) km" }
    public static let raio = "Raio"
    public static let voltarAosFiltros = "Voltar aos filtros"
    public static let catalogoApoio = "1 escolhida. Cada toque já atualiza as vagas."
    public static let maisProcuradasAgora = "Mais procuradas agora"
    public static let periodoManha = "Manhã"
    public static let periodoTarde = "Tarde"
    public static let periodoNoite = "Noite"
    public static let periodoMadrugada = "Madrugada"

    // MARK: - T6b Código
    public static let confiraSeuEmail = "Confira seu e-mail"
    public static func mandamosCodigoPara(_ email: String) -> String {
        "Mandamos um código de 6 números para \(email)."
    }
    public static let codigo = "Código"
    public static let entrar = "Entrar"
    public static let vejaSpam = "Não chegou? Veja a caixa de spam."
    public static let reenviarCodigo = "Reenviar código"
    public static let codigoReenviado = "Código reenviado."

    // MARK: - T6c Nome
    public static let qualSeuNome = "Qual é o seu nome?"
    public static let nomeCompleto = "Nome completo"
    public static let salvarNome = "Salvar nome"

    // MARK: - T3b Perfil da casa
    public static let casaVerificada = "Casa verificada"
    public static let percentualVoltaria = "94% trabalhariam aqui de novo"
    public static func percentualTrabalhariamDeNovo(_ perc: Int) -> String {
        "\(perc)% trabalhariam aqui de novo"
    }
    public static func distanciaPontoBase(_ distancia: String) -> String {
        "\(distancia) do seu ponto base"
    }
    public static func historicoTurnosCasa(quantidade: Int, ultimo: String) -> String {
        quantidade == 1
            ? "Você já fez 1 turno aqui, o último em \(ultimo)."
            : "Você já fez \(quantidade) turnos aqui, o último em \(ultimo)."
    }

    // MARK: - T3c Vaga com candidatura
    public static let aguardandoCasa = "Aguardando a casa"
    public static let voceSeCandidatou = "Você se candidatou."
    public static let apoioCandidatura = "A casa escolhe entre os interessados. Se escolher você, a candidatura vira um turno confirmado."
    public static func horarioEDuracao(inicio: String, fim: String, duracaoHoras: Int) -> String {
        "das \(inicio) às \(fim) (\(duracaoHoras) h de turno)"
    }
    public static func trajeFormatado(_ traje: String) -> String {
        "Traje: \(traje)"
    }
    public static let gorjetaDistribuida = "+ gorjeta distribuída no fim da noite"
    public static let inclusoJantarTransporte = "Incluso: jantar e transporte de volta"
    public static let desistirSemPenalidade = "Desistir sem penalidade"

    // MARK: - T4b Cancelar turno
    public static let fechar = "Fechar"
    public static let cancelarEsteTurno = "Cancelar este turno?"
    public static func casaHojeHorario(casa: String, inicio: String, fim: String) -> String {
        "\(casa), hoje, das \(inicio) às \(fim)."
    }
    public static let consequenciaCancelamento = "Se cancelar, o turno sai de Turnos e seu horário fica livre. A casa é avisada na hora. Sem penalidade."
    public static let motivoOpcional = "Motivo (opcional)"
    public static let limparMotivo = "Limpar motivo"
    public static let nenhumMotivoEscolhido = "Nenhum motivo escolhido."
    public static let cancelarTurno = "Cancelar turno"
    public static let turnoCancelado = "Turno cancelado."
    public static let seuTurnoJaComecou = "Seu turno já começou"
    public static let avisoHorarioComecou = "O turno não foi cancelado: cancelar vale só até o início do horário. Para sair do turno, fale com o suporte."
    public static let sairDoTurno = "Sair do turno"

    // Motivos
    public static let motivoImprevisto = "Imprevisto"
    public static let motivoSaude = "Saúde"
    public static let motivoTransporte = "Transporte"
    public static let motivoOutro = "Outro motivo"

    // MARK: - T4c Suporte
    public static let suporte = "Suporte"
    public static let suporteApoio = "Conte o que aconteceu. Sua mensagem chega à equipe do Frila por aqui."
    public static let sobreOTurno = "Sobre o turno"
    public static func assunto(_ nome: String) -> String { "Assunto: \(nome)" }
    public static let suaMensagem = "Sua mensagem"
    public static let enviarMensagem = "Enviar mensagem"
    public static let mensagemEnviada = "Mensagem enviada."
    public static let conversaComSuporte = "Conversa com o suporte"
    public static let assuntoDenuncia = "Denúncia"
    public static let assuntoSairTurno = "Sair do turno"
    public static let assuntoPresencaNaoConfirmada = "Presença não confirmada"

    // MARK: - T7b Resumo do turno
    public static func seuTurnoFoi(_ data: String) -> String { "Seu turno foi \(data)" }
    public static let concluido = "Concluído"
    public static let faturados = "faturados"
    public static let pedirSuporte = "Pedir suporte"
    public static let denunciarProblema = "Denunciar problema"
    public static let etapasDoTurno = "Etapas do turno"
    public static let etapaConfirmado = "Confirmado"
    public static let etapaACaminho = "A caminho"
    public static let etapaPresenca = "Presença"
    public static let etapaConcluido = "Concluído"
}
