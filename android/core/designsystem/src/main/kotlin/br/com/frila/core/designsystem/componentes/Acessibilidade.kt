package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.sizeIn
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import br.com.frila.core.designsystem.tema.FrilaMetricas

/** Contrato semântico e de toque dos chips que selecionam uma única opção de filtro. */
fun Modifier.semanticaDeFiltro(selecionado: Boolean): Modifier =
    sizeIn(
        minWidth = FrilaMetricas.alvoMinimo,
        minHeight = FrilaMetricas.alvoMinimo,
    ).semantics {
        role = Role.RadioButton
        stateDescription = if (selecionado) "selecionado" else "não selecionado"
    }
