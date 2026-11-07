import Foundation
import FrilaDominio

/// Textos da foto de perfil (contrato 0.2.54, RN37 e RN46). Tom de quem ajuda: diz o que fazer, não acusa.
public enum TextosFotoDePerfil {
    public static let titulo = String(localized: "Foto de perfil", bundle: bundleApresentacao)
    public static let explicacao = String(localized: "Use uma foto sua, com o rosto visível, sem texto nem dados pessoais. Ela só aparece para quem tem vínculo com você, depois de aprovada.", bundle: bundleApresentacao)
    public static let semFoto = String(localized: "Você ainda não tem foto de perfil.", bundle: bundleApresentacao)

    // MARK: Ações
    public static let escolher = String(localized: "Escolher foto", bundle: bundleApresentacao)
    public static let trocar = String(localized: "Trocar foto", bundle: bundleApresentacao)
    public static let tentarOutra = String(localized: "Tentar outra foto", bundle: bundleApresentacao)
    public static let pedirNovaAnalise = String(localized: "Pedir nova análise", bundle: bundleApresentacao)
    public static let remover = String(localized: "Remover foto", bundle: bundleApresentacao)
    public static let confirmarRemocaoTitulo = String(localized: "Remover sua foto?", bundle: bundleApresentacao)
    public static let confirmarRemocaoMensagem = String(localized: "Ela deixa de aparecer na hora. Você pode enviar outra quando quiser.", bundle: bundleApresentacao)
    public static let tentarDeNovo = String(localized: "Tentar de novo", bundle: bundleApresentacao)
    public static let avisoPrevioTitulo = String(localized: "Dicas para a foto", bundle: bundleApresentacao)
    public static let avisoPrevioMensagem = String(localized: "Escolha uma foto com seu rosto de frente, nítido e com boa luz. Apenas você deve aparecer, sem óculos escuros nem boné.", bundle: bundleApresentacao)
    public static let tirarFoto = String(localized: "Tirar foto", bundle: bundleApresentacao)
    public static let escolherDaGaleria = String(localized: "Escolher da galeria", bundle: bundleApresentacao)
    public static let cameraIndisponivel = String(localized: "Câmera indisponível neste aparelho.", bundle: bundleApresentacao)

    // MARK: Os sete estados
    public static let tituloEnviando = String(localized: "Enviando sua foto", bundle: bundleApresentacao)
    public static let textoEnviando = String(localized: "Aguarde um instante.", bundle: bundleApresentacao)
    public static let tituloEmAnalise = String(localized: "Foto em análise", bundle: bundleApresentacao)
    public static let textoEmAnalise = String(localized: "Estamos conferindo sua foto. Ela só aparece para outras pessoas depois de aprovada.", bundle: bundleApresentacao)
    public static let tituloAprovada = String(localized: "Foto publicada", bundle: bundleApresentacao)
    public static let textoAprovada = String(localized: "Quem tem vínculo com você vê esta foto no seu perfil.", bundle: bundleApresentacao)
    public static let tituloRecusada = String(localized: "Foto não publicada", bundle: bundleApresentacao)
    public static let tituloNaoPublicada = String(localized: "Foto não publicada", bundle: bundleApresentacao)
    public static let textoNaoPublicada = String(localized: "Não conseguimos analisar sua foto agora. Peça uma nova análise ou tente outra foto.", bundle: bundleApresentacao)
    public static let tituloOcultada = String(localized: "Foto oculta", bundle: bundleApresentacao)
    public static let textoOcultada = String(localized: "Sua foto foi ocultada depois de denúncias. Envie outra foto para voltar a ter uma.", bundle: bundleApresentacao)
    public static let textoNovaAnaliseJaPedida = String(localized: "A nova análise já foi pedida. Se a foto continuar sem aparecer, tente outra foto.", bundle: bundleApresentacao)

    // MARK: Motivo da recusa (genérico, vindo do servidor)
    public static func motivo(_ motivo: MotivoRecusaMidia?) -> String {
        switch motivo {
        case .fotoInadequada: String(localized: "Use uma foto sua, com o rosto visível.", bundle: bundleApresentacao)
        case .textoOuDadoPessoal: String(localized: "Use uma foto sem texto, telefone, Pix, QR code ou documento.", bundle: bundleApresentacao)
        case .naoEPessoaOuServico: String(localized: "A foto precisa mostrar você. Logos, desenhos e paisagens não servem como foto de perfil.", bundle: bundleApresentacao)
        case .naoAnalisada: String(localized: "Não conseguimos analisar agora. Tente de novo.", bundle: bundleApresentacao)
        case nil: String(localized: "Tente outra foto, com seu rosto visível e sem texto nem dados pessoais.", bundle: bundleApresentacao)
        }
    }

    // MARK: Recurso desligado
    public static let recursoDesligado = String(localized: "Fotos de perfil estão indisponíveis por enquanto. Quando voltarem, você poderá enviar a sua.", bundle: bundleApresentacao)
    public static let recursoDesligadoComFoto = String(localized: "Fotos de perfil estão indisponíveis por enquanto. Sua foto fica guardada, e você pode removê-la quando quiser.", bundle: bundleApresentacao)

    // MARK: Recorte
    public static let recorteTitulo = String(localized: "Ajustar a foto", bundle: bundleApresentacao)
    public static let recorteInstrucao = String(localized: "Arraste e aproxime para deixar seu rosto no quadrado.", bundle: bundleApresentacao)
    public static let recorteUsar = String(localized: "Usar esta foto", bundle: bundleApresentacao)
    public static let recorteAproximar = String(localized: "Aproximar", bundle: bundleApresentacao)
    public static let recorteAfastar = String(localized: "Afastar", bundle: bundleApresentacao)
    public static let recorteArea = String(localized: "Área da foto", bundle: bundleApresentacao)
    public static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)

    // MARK: Andamento do envio
    public static let preparando = String(localized: "Preparando a foto…", bundle: bundleApresentacao)
    public static let verificando = String(localized: "Conferindo a foto…", bundle: bundleApresentacao)
    public static let enviando = String(localized: "Enviando a foto…", bundle: bundleApresentacao)

    // MARK: Avisos (o que fazer)
    public static func aviso(_ aviso: FotoDePerfilViewModel.Aviso) -> String {
        switch aviso {
        case .bloqueadaNoAparelho(let motivo): bloqueio(motivo)
        case .imagemInvalida:
            String(localized: "Não conseguimos abrir essa foto. Tente outra.", bundle: bundleApresentacao)
        case .semRede:
            String(localized: "Sem conexão. Verifique sua internet e tente novamente.", bundle: bundleApresentacao)
        case .recusadaPeloServidor:
            String(localized: "Essa foto não pôde ser enviada. Tente outra foto.", bundle: bundleApresentacao)
        case .recursoDesligado:
            recursoDesligado
        case .expurgada:
            String(localized: "O arquivo dessa foto já foi apagado. Envie outra foto.", bundle: bundleApresentacao)
        case .contaSuspensa:
            String(localized: "Sua conta está suspensa. Enquanto a suspensão durar, não é possível mudar a foto.", bundle: bundleApresentacao)
        case .indisponivelAgora:
            String(localized: "Não foi possível concluir agora. Tente novamente em instantes.", bundle: bundleApresentacao)
        }
    }

    /// Falha fechada do aparelho (CD-M06): diz o que a foto tem e pede outra, sem culpar.
    public static func bloqueio(_ motivo: MotivoDeBloqueioLocal) -> String {
        switch motivo {
        case .telefone, .email, .linkOuArroba, .chavePix:
            String(localized: "Encontramos na foto algo que parece telefone, e-mail, link ou chave Pix. Tente outra foto, sem texto nem dados pessoais.", bundle: bundleApresentacao)
        case .qrCode:
            String(localized: "Encontramos um QR code ou código de barras na foto. Tente outra foto, sem eles.", bundle: bundleApresentacao)
        case .rostoNaoEncontrado:
            String(localized: "Não achei seu rosto. Tente com mais luz e de frente", bundle: bundleApresentacao)
        case .multiplosRostos:
            String(localized: "Escolha uma foto em que apareça apenas você.", bundle: bundleApresentacao)
        case .analiseIndisponivel:
            String(localized: "Não conseguimos conferir a foto neste aparelho agora. Por segurança, ela não foi enviada. Tente outra foto em instantes.", bundle: bundleApresentacao)
        }
    }

    // MARK: Acessibilidade
    public static let fotoAcessibilidade = String(localized: "Sua foto de perfil", bundle: bundleApresentacao)
    public static let semFotoAcessibilidade = String(localized: "Sem foto de perfil", bundle: bundleApresentacao)
}
