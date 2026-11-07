import Foundation

public enum TextosChamadaDireta {
    public static let titulo = String(localized: "Chamar de novo", bundle: bundleApresentacao)
    public static let enviar = String(localized: "Enviar chamada", bundle: bundleApresentacao)
    public static let responsavel = String(localized: "Responsável no local", bundle: bundleApresentacao)
    public static let valor = String(localized: "Valor total em centavos", bundle: bundleApresentacao)
    public static let total = String(localized: "Confirmo que este é o valor total fechado que o profissional recebe pelo trabalho.", bundle: bundleApresentacao)
    public static let recado = String(localized: "Recado opcional (até 300 caracteres)", bundle: bundleApresentacao)
    public static let recadoLongo = String(localized: "O recado deve ter até 300 caracteres.", bundle: bundleApresentacao)
    public static let sucesso = String(localized: "Chamada enviada. Aguarde a resposta do profissional.", bundle: bundleApresentacao)
    public static let j7Titulo = String(localized: "Confirme antes de chamar novamente", bundle: bundleApresentacao)
    public static let j7Mensagem = String(localized: "Esta é a terceira chamada à mesma pessoa em sete dias por uma casa de pessoa física. A contratação frequente pode caracterizar vínculo de emprego. O Frila não substitui as obrigações trabalhistas. Confirme que leu este aviso para continuar.", bundle: bundleApresentacao)
    public static let j7Confirmar = String(localized: "Li o aviso e confirmo a chamada", bundle: bundleApresentacao)
    public static let jaAberta = String(localized: "Você já tem uma chamada aberta para este profissional.", bundle: bundleApresentacao)
    public static let indisponivel = String(localized: "Este profissional não está disponível para esta chamada.", bundle: bundleApresentacao)
    public static let limite = String(localized: "Você atingiu o limite de chamadas. Aguarde antes de tentar novamente.", bundle: bundleApresentacao)
    public static let desligado = String(localized: "A chamada direta está indisponível no momento.", bundle: bundleApresentacao)
    public static let erro = String(localized: "Não foi possível concluir a chamada. Verifique sua conexão e tente novamente.", bundle: bundleApresentacao)
}
