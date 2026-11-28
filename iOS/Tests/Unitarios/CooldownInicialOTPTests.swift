import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

@Suite("Cooldown inicial OTP e ConfiguracaoDoApp (0.2.120)")
@MainActor
struct CooldownInicialOTPTests {
    @Test("ConfiguracaoApp.normalizarCooldownOTP aceita positivos e aplica fallback 60 para nil/0/negativo")
    func normalizarCooldownOTP() {
        #expect(ConfiguracaoApp.normalizarCooldownOTP(30) == 30)
        #expect(ConfiguracaoApp.normalizarCooldownOTP(60) == 60)
        #expect(ConfiguracaoApp.normalizarCooldownOTP(nil) == 60)
        #expect(ConfiguracaoApp.normalizarCooldownOTP(0) == 60)
        #expect(ConfiguracaoApp.normalizarCooldownOTP(-15) == 60)
    }

    @Test("ConfiguracaoDoAppDTO decodifica reenviar_otp_em_segundos (30, 60, ausente e negativo -> fallback 60)")
    func decoderConfiguracaoDoAppDTO() throws {
        let casos: [(String, Int)] = [
            ("{\"versao_minima\":\"1.0.0\",\"versao_recomendada\":\"1.1.0\",\"url_da_loja\":\"https://apps.apple.com/br/app/frila\",\"reenviar_otp_em_segundos\":30}", 30),
            ("{\"versao_minima\":\"1.0.0\",\"versao_recomendada\":\"1.1.0\",\"url_da_loja\":\"https://apps.apple.com/br/app/frila\",\"reenviar_otp_em_segundos\":60}", 60),
            ("{\"versao_minima\":\"1.0.0\",\"versao_recomendada\":\"1.1.0\",\"url_da_loja\":\"https://apps.apple.com/br/app/frila\"}", 60),
            ("{\"versao_minima\":\"1.0.0\",\"versao_recomendada\":\"1.1.0\",\"url_da_loja\":\"https://apps.apple.com/br/app/frila\",\"reenviar_otp_em_segundos\":0}", 60),
            ("{\"versao_minima\":\"1.0.0\",\"versao_recomendada\":\"1.1.0\",\"url_da_loja\":\"https://apps.apple.com/br/app/frila\",\"reenviar_otp_em_segundos\":-5}", 60),
        ]
        for (json, esperado) in casos {
            let dto = try JSONDecoder().decode(ContratoAPI.ConfiguracaoDoAppDTO.self, from: Data(json.utf8))
            #expect(dto.dominio().reenviarOTPEmSegundos == esperado)
        }
    }

    @Test("AutenticarSenhaRespostaDTO decodifica reenviar_em_segundos opcional (30, 60, ausente e negativo)")
    func decoderAutenticarSenhaRespostaDTO() throws {
        let casos: [(String, Int)] = [
            ("{\"status\":\"desafio_otp\",\"desafio_id\":\"11111111-1111-4111-8111-111111111111\",\"descartar_device_token\":false,\"reenviar_em_segundos\":30}", 30),
            ("{\"status\":\"desafio_otp\",\"desafio_id\":\"11111111-1111-4111-8111-111111111111\",\"descartar_device_token\":false,\"reenviar_em_segundos\":60}", 60),
            ("{\"status\":\"desafio_otp\",\"desafio_id\":\"11111111-1111-4111-8111-111111111111\",\"descartar_device_token\":false}", 60),
            ("{\"status\":\"desafio_otp\",\"desafio_id\":\"11111111-1111-4111-8111-111111111111\",\"descartar_device_token\":false,\"reenviar_em_segundos\":-3}", 60),
        ]
        for (json, esperado) in casos {
            let dto = try JSONDecoder().decode(ContratoAPI.AutenticarSenhaRespostaDTO.self, from: Data(json.utf8))
            #expect(ConfiguracaoApp.normalizarCooldownOTP(dto.reenviarEmSegundos) == esperado)
        }
    }

    @Test("EntradaComSenhaViewModel propaga reenviarEmSegundos efetivo (30s) no DestinoCodigo.desafioOTP")
    func entradaComSenhaPropagaCooldownInicial() async {
        let api = ApiStubDesafio30s(base: ApiClienteEmMemoria(cenario: .primeiroAcesso))
        let vm = EntradaComSenhaViewModel(api: api, emailInicial: "ana@frila.app")
        vm.senha = "SenhaForte123!"

        let destino = await vm.entrar()
        #expect(destino == .desafioOTP(email: "ana@frila.app", desafioID: "des-30s", reenviarEmSegundos: 30))
    }

    @Test("CodigoViewModel respeita esperaInicialSegundos (30s), aplica fallback 60 para <=0 e mantém 429 sem retry")
    func codigoViewModelEsperaInicialEReenvioPolitica() async {
        let api = ApiStubReenvio429(base: ApiClienteEmMemoria(cenario: .primeiroAcesso))
        let vm30 = CodigoViewModel(api: api, email: "ana@frila.app", modo: .entrada, esperaInicialSegundos: 30)
        #expect(vm30.segundosRestantes == 30)

        let vmInvalido = CodigoViewModel(api: api, email: "ana@frila.app", modo: .entrada, esperaInicialSegundos: -10)
        #expect(vmInvalido.segundosRestantes == 60)

        // Simula fim da espera e reenvio bem-sucedido em .entrada -> volta para política 30s
        vm30.segundosRestantes = 0
        await vm30.reenviarCodigo()
        #expect(vm30.segundosRestantes == 30)
        #expect(api.chamadasSolicitar == 1)

        // Simula 429 no reenvio -> erro exibido sem retry automático
        api.falharCom429 = true
        vm30.segundosRestantes = 0
        await vm30.reenviarCodigo()
        #expect(api.chamadasSolicitar == 2)
        #expect(vm30.erro != nil)
    }
}

private final class ApiStubDesafio30s: ApiClienteEncaminhador, @unchecked Sendable {
    override func entrarComSenha(email: String, senha: String) async throws -> ResultadoEntradaComSenha {
        .desafioOTP(desafioID: "des-30s", expiraEm: nil, reenviarEmSegundos: 30)
    }
}

private final class ApiStubReenvio429: ApiClienteEncaminhador, @unchecked Sendable {
    var chamadasSolicitar = 0
    var falharCom429 = false

    override func solicitarCodigo(email: String) async throws {
        chamadasSolicitar += 1
        if falharCom429 {
            throw ErroDaApi(codigo: .limiteExcedido)
        }
    }
}
