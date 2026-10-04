import Foundation

public enum TextosDoSuporte {
    public static let titulo = String(localized: "Ajuda no turno", bundle: bundleApresentacao)
    public static let botaoAjudaTurno = String(localized: "Ajuda no turno", bundle: bundleApresentacao)
    public static let dicaAjudaTurno = String(localized: "Abre suporte por e-mail com os dados do turno pré-preenchidos", bundle: bundleApresentacao)
    public static let avisoPrazo = String(localized: "Respondemos em até 5 dias úteis. Não há atendimento ao vivo.", bundle: bundleApresentacao)

    public static let secaoMotivo = String(localized: "Motivo do suporte", bundle: bundleApresentacao)
    public static let motivoRiscoSeguranca = String(localized: "Risco à segurança ou emergência", bundle: bundleApresentacao)
    public static let motivoAtrasoOuImprevisto = String(localized: "Atraso ou imprevisto no comparecimento", bundle: bundleApresentacao)
    public static let motivoProblemaNoLocal = String(localized: "Problema no local ou atividade", bundle: bundleApresentacao)
    public static let motivoDificuldadePresenca = String(localized: "Dificuldade com check-in ou confirmação", bundle: bundleApresentacao)
    public static let motivoOutro = String(localized: "Outro imprevisto ou dúvida", bundle: bundleApresentacao)

    public static let secaoSeguranca = String(localized: "Risco imediato", bundle: bundleApresentacao)
    public static let avisoSeguranca = String(localized: "Em risco imediato, ligue 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher)", bundle: bundleApresentacao)
    public static let policia = String(localized: "Ligar 190 — Polícia Militar", bundle: bundleApresentacao)
    public static let mulher = String(localized: "Ligar 180 — Central de Atendimento à Mulher", bundle: bundleApresentacao)

    public static let secaoDados = String(localized: "Identificação do turno", bundle: bundleApresentacao)
    public static let rotuloID = String(localized: "ID do turno", bundle: bundleApresentacao)
    public static let rotuloFuncao = String(localized: "Função", bundle: bundleApresentacao)
    public static let rotuloContratante = String(localized: "Contratante", bundle: bundleApresentacao)
    public static let rotuloProfissional = String(localized: "Profissional", bundle: bundleApresentacao)
    public static let rotuloHorario = String(localized: "Horário", bundle: bundleApresentacao)
    public static let rotuloLocal = String(localized: "Local", bundle: bundleApresentacao)

    public static let secaoRelato = String(localized: "Descrição do ocorrido", bundle: bundleApresentacao)
    public static let promptRelato = String(localized: "Descreva detalhes do que está acontecendo…", bundle: bundleApresentacao)
    public static let dicaRelato = String(localized: "Opcional. Os dados de identificação do turno acima serão incluídos no e-mail automaticamente.", bundle: bundleApresentacao)

    public static let secaoAcoes = String(localized: "Envio do e-mail", bundle: bundleApresentacao)
    public static let botaoEnviarEmail = String(localized: "Abrir e-mail de suporte", bundle: bundleApresentacao)
    public static let dicaEnviarEmail = String(localized: "Abre o compositor de e-mail com os dados pré-preenchidos para suportefrila@gmail.com", bundle: bundleApresentacao)
    public static let botaoCopiarDados = String(localized: "Copiar dados do e-mail", bundle: bundleApresentacao)
    public static let dicaCopiarDados = String(localized: "Copia o assunto e o corpo formatados para colar no seu aplicativo de e-mail", bundle: bundleApresentacao)
    public static let dadosCopiados = String(localized: "Dados copiados para a área de transferência.", bundle: bundleApresentacao)
    public static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    public static let emailSuporteRotulo = String(localized: "Destinatário oficial: %@", bundle: bundleApresentacao)
}
