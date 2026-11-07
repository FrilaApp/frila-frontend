import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Apresentação, experiência e regiões atendidas (I2b)")
struct ApresentacaoERegioesTests {

    @Test("Carrega apresentação existente e mapeia todos os campos no ViewModel")
    func carregarPerfilComSucesso() async throws {
        let api = ApiClienteEmMemoria()
        let apresentacaoInicial = ApresentacaoDoProfissional(
            apresentacao: "Garçom experiente com foco em eventos corporativos e casamentos.",
            ondeTrabalhei: "Restaurantes no Plano Piloto e buffets no Lago Sul.",
            experienciaFaixa: .de1A3Anos,
            cursos: ["Boas Práticas de Manipulação", "Atendimento de Excelência"],
            idiomas: [.ingles, .espanhol]
        )
        await api.definirApresentacaoDetalhada(
            apresentacao: apresentacaoInicial,
            regioes: [1, 2], // Plano Piloto, Gama
            atendeTodoDF: false
        )

        let vm = ApresentacaoERegioesViewModel(api: api)
        await vm.carregar()

        #expect(vm.sobreMim == "Garçom experiente com foco em eventos corporativos e casamentos.")
        #expect(vm.ondeTrabalhei == "Restaurantes no Plano Piloto e buffets no Lago Sul.")
        #expect(vm.experienciaFaixa == .de1A3Anos)
        #expect(vm.cursos == ["Boas Práticas de Manipulação", "Atendimento de Excelência"])
        #expect(vm.idiomasSelecionados.contains(.ingles))
        #expect(vm.idiomasSelecionados.contains(.espanhol))
        #expect(vm.regioesSelecionadas == Set([1, 2]))
        #expect(vm.atendeTodoDF == false)
        #expect(!vm.regioesDisponiveis.isEmpty)
        #expect(vm.erroGeral == nil)
        #expect(vm.erroSobreMim == nil)
    }

    @Test("Salvar com todos os campos opcionais vazios salva com sucesso (RN26)")
    func salvarComCamposOpcionaisVazios() async throws {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)
        await vm.carregar()

        vm.sobreMim = ""
        vm.ondeTrabalhei = ""
        vm.experienciaFaixa = nil
        vm.cursos = []
        vm.idiomasSelecionados = []
        vm.regioesSelecionadas = []
        vm.atendeTodoDF = false

        let sucesso = await vm.salvar()
        #expect(sucesso)
        #expect(vm.sucesso)
        #expect(vm.erroGeral == nil)
        #expect(vm.erroSobreMim == nil)

        let detalhado = try await api.meuPerfilDetalhado()
        #expect(detalhado.apresentacao == nil)
        #expect(detalhado.ondeTrabalhei == nil)
        #expect(detalhado.experienciaFaixa == nil)
        #expect(detalhado.cursos.isEmpty)
        #expect(detalhado.idiomas.isEmpty)
        #expect(detalhado.regioes.isEmpty)
        #expect(detalhado.atendeTodoDF == false)
    }

    @Test("Tentativa de contato ou Pix em Sobre mim dispara 422 e preserva rascunho intacto")
    func antiContatoErro422PreservaRascunho() async throws {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)
        await vm.carregar()

        let sobreComContato = "Me contrate direto no zap (61) 98888-7777 ou mande pix@email.com"
        let locais = "Buffet Central"
        let curso = "Curso Barista"

        vm.sobreMim = sobreComContato
        vm.ondeTrabalhei = locais
        vm.experienciaFaixa = .maisDe10Anos
        vm.cursos = [curso]
        vm.idiomasSelecionados = [.ingles]
        vm.regioesSelecionadas = [1]

        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(!vm.sucesso)
        #expect(vm.erroSobreMim == TextosApresentacaoERegioes.erroAntiContato)

        // Verificação crucial: o rascunho continua intacto para correção
        #expect(vm.sobreMim == sobreComContato)
        #expect(vm.ondeTrabalhei == locais)
        #expect(vm.experienciaFaixa == .maisDe10Anos)
        #expect(vm.cursos == [curso])
        #expect(vm.idiomasSelecionados == [.ingles])
        #expect(vm.regioesSelecionadas == [1])
    }

    @Test("Anti-contato em Onde trabalhei mapeia erro para o campo e preserva rascunho")
    func antiContatoOndeTrabalheiPreservaRascunho() async throws {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)
        await vm.carregar()

        vm.sobreMim = "Profissional pontual e dedicado."
        vm.ondeTrabalhei = "Fale com o gerente pelo telefone 61999998888"

        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(vm.erroOndeTrabalhei == TextosApresentacaoERegioes.erroAntiContato)
        #expect(vm.sobreMim == "Profissional pontual e dedicado.")
        #expect(vm.ondeTrabalhei == "Fale com o gerente pelo telefone 61999998888")
    }

    @Test("Erro 422 de anti-contato sem detalhe ou genérico associa a erroSobreMim")
    func antiContatoGenericoAssociaAoSobreMim() async throws {
        let api = ApiClienteEmMemoria()
        await api.simularErroApresentacao(.campoInvalido, detalhes: nil)

        let vm = ApresentacaoERegioesViewModel(api: api)
        await vm.carregar()

        vm.sobreMim = "Texto limpo sem dados de contato"
        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(vm.erroSobreMim == TextosApresentacaoERegioes.erroAntiContato)
        #expect(vm.sobreMim == "Texto limpo sem dados de contato")
    }

    @Test("Validação local do limite de caracteres de Sobre mim (máximo 600)")
    func validacaoLimiteSobreMim() async {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)

        vm.sobreMim = String(repeating: "A", count: 601)
        let sucesso = await vm.salvar()

        #expect(!sucesso)
        #expect(vm.erroSobreMim == TextosApresentacaoERegioes.limiteSobreMimExcedido)
    }

    @Test("Validação local do limite de caracteres de Onde já trabalhei (máximo 400)")
    func validacaoLimiteOndeTrabalhei() async {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)

        vm.ondeTrabalhei = String(repeating: "B", count: 401)
        let sucesso = await vm.salvar()

        #expect(!sucesso)
        #expect(vm.erroOndeTrabalhei == TextosApresentacaoERegioes.limiteOndeTrabalheiExcedido)
    }

    @Test("Gerenciamento de cursos e limites de quantidade e tamanho")
    func gerenciamentoDeCursos() async {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)

        // Adicionar em branco não faz nada
        vm.novoCursoTexto = "   "
        vm.adicionarCurso()
        #expect(vm.cursos.isEmpty)

        // Adicionar curso válido
        vm.novoCursoTexto = "Curso de Garçom"
        vm.adicionarCurso()
        #expect(vm.cursos == ["Curso de Garçom"])
        #expect(vm.novoCursoTexto.isEmpty)

        // Curso com mais de 80 caracteres
        vm.novoCursoTexto = String(repeating: "C", count: 81)
        vm.adicionarCurso()
        #expect(vm.erroCursos == TextosApresentacaoERegioes.cursoMuitoLongo)
        #expect(vm.cursos.count == 1)

        // Limite de 5 cursos
        vm.cursos = ["C1", "C2", "C3", "C4", "C5"]
        vm.novoCursoTexto = "C6"
        vm.adicionarCurso()
        #expect(vm.erroCursos == TextosApresentacaoERegioes.limiteCursosAtingido)
        #expect(vm.cursos.count == 5)

        // Remover curso
        vm.removerCurso(em: 2)
        #expect(vm.cursos == ["C1", "C2", "C4", "C5"])
        #expect(vm.erroCursos == nil)

        // Curso pendente no campo de texto é salvo automaticamente ao chamar salvar()
        vm.novoCursoTexto = "Curso Auto Salvo"
        let sucesso = await vm.salvar()
        #expect(sucesso)
        #expect(vm.cursos.contains("Curso Auto Salvo"))
    }

    @Test("Seleção mútua entre Atender em todo o DF e Regiões Administrativas específicas")
    func selecaoDeRegioesETodoDF() async {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)

        // Seleciona RA 1 e 2
        vm.alternarRegiao(id: 1)
        vm.alternarRegiao(id: 2)
        #expect(vm.regioesSelecionadas == Set([1, 2]))
        #expect(vm.atendeTodoDF == false)

        // Marca Todo o DF: deve limpar a lista de RAs selecionadas
        vm.atendeTodoDF = true
        #expect(vm.regioesSelecionadas.isEmpty)
        #expect(vm.atendeTodoDF == true)

        // Clica em uma RA específica enquanto Todo o DF estava marcado: desmarca Todo o DF e seleciona a RA
        vm.alternarRegiao(id: 3)
        #expect(vm.atendeTodoDF == false)
        #expect(vm.regioesSelecionadas == Set([3]))

        // Alterna a mesma RA: remove da seleção
        vm.alternarRegiao(id: 3)
        #expect(vm.regioesSelecionadas.isEmpty)
    }

    @Test("Seleção e alternância de idiomas")
    func selecaoDeIdiomas() {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)

        vm.alternarIdioma(.ingles)
        #expect(vm.idiomasSelecionados.contains(.ingles))

        vm.alternarIdioma(.espanhol)
        #expect(vm.idiomasSelecionados.contains(.ingles))
        #expect(vm.idiomasSelecionados.contains(.espanhol))

        vm.alternarIdioma(.ingles)
        #expect(!vm.idiomasSelecionados.contains(.ingles))
        #expect(vm.idiomasSelecionados.contains(.espanhol))
    }

    @Test("Erro de falta de rede preserva o rascunho e exibe mensagem amigável")
    func erroSemRedeAoSalvar() async {
        let api = ApiClienteEmMemoria()
        await api.simularErroApresentacao(.semRede)

        let vm = ApresentacaoERegioesViewModel(api: api)
        vm.sobreMim = "Rascunho importante que não pode ser perdido"
        vm.ondeTrabalhei = "Local A"

        let sucesso = await vm.salvar()
        #expect(!sucesso)
        #expect(vm.erroGeral == TextosApresentacaoERegioes.erroSemRede)
        #expect(vm.sobreMim == "Rascunho importante que não pode ser perdido")
        #expect(vm.ondeTrabalhei == "Local A")
    }

    @Test("Limpeza de erros ao alterar valores dos campos")
    func limpezaDeErrosAoDigitar() {
        let api = ApiClienteEmMemoria()
        let vm = ApresentacaoERegioesViewModel(api: api)

        vm.erroSobreMim = "Erro"
        vm.sobreMim = "Novo texto"
        #expect(vm.erroSobreMim == nil)

        vm.erroOndeTrabalhei = "Erro"
        vm.ondeTrabalhei = "Novo local"
        #expect(vm.erroOndeTrabalhei == nil)

        vm.erroCursos = "Erro"
        vm.novoCursoTexto = "Novo"
        #expect(vm.erroCursos == nil)

        vm.erroRegioes = "Erro"
        vm.atendeTodoDF = true
        #expect(vm.erroRegioes == nil)
    }

    @Test("ApiClienteEmMemoria atualiza apresentação e regiões de forma persistente")
    func apiEmMemoriaPersistencia() async throws {
        let api = ApiClienteEmMemoria()

        let apresentacao = ApresentacaoDoProfissional(
            apresentacao: "Perfil salvo em teste",
            ondeTrabalhei: "Bares",
            experienciaFaixa: .de3A5Anos,
            cursos: ["Curso 1"],
            idiomas: [.libras]
        )
        let regioes = RegioesAtendidas(regioes: [1, 3], atendeTodoDF: false)

        let detalhado1 = try await api.atualizarApresentacaoProfissional(apresentacao)
        #expect(detalhado1.apresentacao == "Perfil salvo em teste")
        #expect(detalhado1.ondeTrabalhei == "Bares")
        #expect(detalhado1.experienciaFaixa == ExperienciaFaixa.de3A5Anos)
        #expect(detalhado1.cursos == ["Curso 1"])
        #expect(detalhado1.idiomas == [Idioma.libras])

        let detalhado2 = try await api.definirRegioesAtendidas(regioes)
        #expect(detalhado2.regioes.map(\.id).sorted() == [1, 3])
        #expect(detalhado2.atendeTodoDF == false)

        // Confirmar com nova chamada de meuPerfilDetalhado
        let detalhado3 = try await api.meuPerfilDetalhado()
        #expect(detalhado3.apresentacao == "Perfil salvo em teste")
        #expect(detalhado3.regioes.map(\.id).sorted() == [1, 3])
    }
}
