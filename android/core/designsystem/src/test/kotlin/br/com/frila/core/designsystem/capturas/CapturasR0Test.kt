package br.com.frila.core.designsystem.capturas

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CaixasDeCodigo
import br.com.frila.core.designsystem.componentes.CampoDeBusca
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeNavegacao
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.LinhaDeEtapas
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.designsystem.tema.FrilaTipo
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints da fundação do redesign (R0): os componentes base num Pixel de 411 × 914 dp, no claro e no
 * escuro. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR0Test {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `botoes, selos e formulario - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { BotoesSelosEFormulario() } }
        compose.capturar("r0-01-botoes-selos-formulario-claro")
    }

    @Test
    fun `botoes, selos e formulario - escuro`() {
        compose.setContent { FrilaTheme(temaEscuro = true) { BotoesSelosEFormulario() } }
        compose.capturar("r0-02-botoes-selos-formulario-escuro")
    }

    @Test
    fun `cartao, linhas e etapas - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { CartaoLinhasEEtapas() } }
        compose.capturar("r0-03-cartao-linhas-etapas-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `cartao, linhas e etapas - fonte do sistema em 200 por cento`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { CartaoLinhasEEtapas() } }
        compose.capturar("r0-06-cartao-linhas-etapas-fonte-200")
    }

    @Test
    fun `estados vazio, erro e carregando - claro`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { Estados() } }
        compose.capturar("r0-04-estados-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `botoes, selos e formulario - fonte do sistema em 200 por cento`() {
        compose.setContent { FrilaTheme(temaEscuro = false) { BotoesSelosEFormulario() } }
        compose.capturar("r0-05-botoes-selos-formulario-fonte-200")
    }
}

@Composable
private fun Tela(rodape: @Composable () -> Unit = {}, conteudo: @Composable () -> Unit) {
    Scaffold(
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = {}) },
        bottomBar = rodape,
    ) { margens ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(FrilaTema.cores.fundo)
                .padding(margens)
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            conteudo()
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BotoesSelosEFormulario() {
    Tela(
        rodape = {
            RodapeAncorado {
                MensagemJuntoAoBotao("Esse código não confere. Peça um novo e tente de novo.")
                BotaoPrimario(texto = "Receber código", aoClicar = {}, modifier = Modifier.fillMaxWidth())
                BotaoPrimario(texto = "Receber código", aoClicar = {}, habilitado = false, modifier = Modifier.fillMaxWidth())
            }
        },
    ) {
        TituloDaTela("Entre com seu e-mail")
        Text(
            text = "Você recebe um código de acesso. Sem senha.",
            style = FrilaTipo.apoio,
            color = FrilaTema.cores.tintaSuave,
        )
        CampoDeTexto(valor = "ju@exemplo.com", aoMudar = {}, rotulo = "E-mail")
        CampoDeTexto(valor = "", aoMudar = {}, rotulo = "CPF", dica = "000.000.000-00", erro = "Confira o CPF: faltam números.")
        CaixasDeCodigo(codigo = "4821", aoMudar = {})
        FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            SeloDeStatus("Urgência", EstiloDoSelo.URGENCIA)
            SeloDeStatus("Confirmado", EstiloDoSelo.CONFIRMADO)
            SeloDeStatus("A caminho", EstiloDoSelo.ANDAMENTO)
            SeloDeStatus("Por seleção", EstiloDoSelo.CONTORNO)
            SeloDeStatus("Vaga fechou", EstiloDoSelo.ENCERRADO)
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            ChipFrila("Bartender", selecionado = true, aoClicar = {})
            ChipFrila("Garçom", selecionado = false, aoClicar = {})
            ChipFrila("Cozinha", selecionado = false, aoClicar = {})
        }
        LinkFrila("Reenviar código", aoClicar = {})
    }
}

@Composable
private fun CartaoLinhasEEtapas() {
    Tela {
        TituloDaTela("Seu turno")
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            SeloDeStatus("A caminho", EstiloDoSelo.ANDAMENTO)
            Spacer(Modifier.height(FrilaEspacamento.item))
            Text("Bar do Zé", style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
            Spacer(Modifier.height(FrilaEspacamento.item))
            FrilaLinhaDeDado(Icons.Default.DateRange, "Sáb 21/11", qualificador = "das 18:00 às 00:00")
            Spacer(Modifier.height(FrilaEspacamento.item))
            FrilaLinhaDeDado(Icons.Default.Place, "1,8 km", qualificador = "de distância")
            Spacer(Modifier.height(FrilaEspacamento.bloco))
            FrilaDivisoria()
            Spacer(Modifier.height(FrilaEspacamento.bloco))
            Text("R$ 180", style = FrilaTipo.valorEmDestaque, color = FrilaTema.cores.tinta)
            Spacer(Modifier.height(FrilaEspacamento.bloco))
            LinhaDeEtapas(etapas = listOf("Confirmado", "A caminho", "Presença", "Concluído"), atual = 1)
        }
        AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = "O estabelecimento escolhe entre os interessados.")
        FrilaGrupoDeLinhas(titulo = "Salvar como") {
            linha { FrilaLinhaDeOpcao("Casa", marcada = true, aoClicar = {}, subtitulo = "SQS 308 Bloco C") }
            linha { FrilaLinhaDeOpcao("Trabalho", marcada = false, aoClicar = {}) }
        }
        FrilaGrupoDeLinhas(titulo = "Conta") {
            linha { FrilaLinhaDeNavegacao("Serviços", aoClicar = {}, valor = "3") }
            linha { FrilaLinhaDeNavegacao("Licenças de código aberto", aoClicar = {}) }
        }
        RotuloDeGrupo("Precisa de ajuda?")
        AcaoDiscreta("Cancelar turno", aoClicar = {})
    }
}

@Composable
private fun Estados() {
    Tela {
        CampoDeBusca(texto = "", aoMudar = {}, dica = "Buscar por estabelecimento ou função")
        BotaoSecundario(texto = "Abrir no mapa", aoClicar = {}, modifier = Modifier.fillMaxWidth())
        EstadoVazio(
            titulo = "Nenhuma vaga por perto agora",
            mensagem = "Avisamos quando abrir uma.",
            textoAcao = "Mudar a distância",
            aoClicarAcao = {},
        )
        FrilaDivisoria()
        EstadoErro(aoTentarNovamente = {})
        FrilaDivisoria()
        EstadoCarregando(mensagem = "Buscando vagas")
    }
}
