package br.com.frila.app

import android.content.Intent
import android.net.Uri
import br.com.frila.feature.turnos.PedidoDeEmailDeSuporte
import br.com.frila.feature.turnos.TextosOcorrencia
import br.com.frila.feature.turnos.corpoDoEmailDeSuporte

/**
 * E-mail do relato de ocorrência já escrito. Assunto e corpo vão como extras (não na URL do `mailto:`): o relato pode
 * ser longo e o limite de uma URL varia de cliente para cliente. Sem anexo: a tela não promete foto.
 */
internal fun intentDoEmailDeSuporte(emailDeSuporte: String, turnoId: String, pedido: PedidoDeEmailDeSuporte): Intent =
    Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:")).apply {
        putExtra(Intent.EXTRA_EMAIL, arrayOf(emailDeSuporte))
        putExtra(Intent.EXTRA_SUBJECT, TextosOcorrencia.assuntoDoEmail(pedido.protocoloCurto))
        putExtra(Intent.EXTRA_TEXT, corpoDoEmailDeSuporte(turnoId, pedido))
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
