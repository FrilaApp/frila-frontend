#!/bin/bash

# Exercita o contrato público de conferir-textos.sh com arquivos e pastas sintéticos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/conferir-textos.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-textos.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: script conferir-textos.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

esperar_aprovacao() {
  local alvo="$1"
  local saida
  if ! saida="$("$SCRIPT" "$alvo" 2>&1)"; then
    echo "FALHA: o caso bom foi reprovado: $saida" >&2
    exit 1
  fi
  [[ "$saida" == *"OK: textos no bundle da Apresentação e tokens em conformidade."* ]] || {
    echo "FALHA: aprovação sem mensagem esperada: $saida" >&2
    exit 1
  }
}

esperar_reprovacao() {
  local descricao="$1"
  local motivo="$2"
  local alvo="$3"
  local saida

  if saida="$("$SCRIPT" "$alvo" 2>&1)"; then
    echo "FALHA: $descricao deveria reprovar" >&2
    exit 1
  fi
  [[ "$saida" == *"$motivo"* ]] || {
    echo "FALHA: $descricao reprovou pelo motivo errado: $saida" >&2
    exit 1
  }
}

# Caso 1: código 100% conforme
DIR_BOM="$TMPDIR_TESTE/bom"
mkdir -p "$DIR_BOM"
cat <<'SWIFT' > "$DIR_BOM/TelaBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaBoa: View {
    let titulo = String(localized: "Título", bundle: bundleLocal)
    let contagem = 1
    var body: some View {
        VStack {
            Text("Constante", bundle: bundleLocal).font(.largeTitle.bold())
            Text(verbatim: titulo).foregroundStyle(FrilaCor.primaria)
            Text(verbatim: "\(contagem)")
            Text(verbatim: "\(titulo) · \(titulo)")
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM"

# Caso 2: String(localized:) sem bundle
DIR_RUIM_STRING="$TMPDIR_TESTE/ruim_string"
mkdir -p "$DIR_RUIM_STRING"
cat <<'SWIFT' > "$DIR_RUIM_STRING/TelaSemBundle.swift"
import SwiftUI

struct TelaSemBundle: View {
    let texto = String(localized: "Texto sem bundle")
    var body: some View {
        Text(verbatim: texto)
    }
}
SWIFT
esperar_reprovacao "String(localized:) sem bundle" "String(localized:) sem bundle" "$DIR_RUIM_STRING"

# Caso 3: LocalizedStringKey embrulhada
DIR_RUIM_KEY="$TMPDIR_TESTE/ruim_key"
mkdir -p "$DIR_RUIM_KEY"
cat <<'SWIFT' > "$DIR_RUIM_KEY/TelaKey.swift"
import SwiftUI

struct TelaKey: View {
    let chave = LocalizedStringKey("chave")
    var body: some View {
        EmptyView()
    }
}
SWIFT
esperar_reprovacao "LocalizedStringKey embrulhada" "LocalizedStringKey embrulhada" "$DIR_RUIM_KEY"

# Caso 4: Text() sem bundle e sem verbatim
DIR_RUIM_TEXT="$TMPDIR_TESTE/ruim_text"
mkdir -p "$DIR_RUIM_TEXT"
cat <<'SWIFT' > "$DIR_RUIM_TEXT/TelaText.swift"
import SwiftUI

struct TelaText: View {
    let texto: String
    var body: some View {
        Text(texto)
    }
}
SWIFT
esperar_reprovacao "Text() sem bundle e sem verbatim" "Text() sem bundle e sem verbatim" "$DIR_RUIM_TEXT"

# Caso 5: Fonte de tamanho fixo
DIR_RUIM_FONTE="$TMPDIR_TESTE/ruim_fonte"
mkdir -p "$DIR_RUIM_FONTE"
cat <<'SWIFT' > "$DIR_RUIM_FONTE/TelaFonte.swift"
import SwiftUI

struct TelaFonte: View {
    let exemplo = "Exemplo"
    var body: some View {
        Text(verbatim: exemplo).font(.system(size: 42))
    }
}
SWIFT
esperar_reprovacao "fonte de tamanho fixo" "Fonte de tamanho fixo" "$DIR_RUIM_FONTE"

# Caso 6: Cor fora dos tokens
DIR_RUIM_COR="$TMPDIR_TESTE/ruim_cor"
mkdir -p "$DIR_RUIM_COR"
cat <<'SWIFT' > "$DIR_RUIM_COR/TelaCor.swift"
import SwiftUI

struct TelaCor: View {
    let exemplo = "Exemplo"
    var body: some View {
        Text(verbatim: exemplo).foregroundStyle(.red)
    }
}
SWIFT
esperar_reprovacao "cor fora dos tokens" "Cor fora dos tokens" "$DIR_RUIM_COR"

# Caso 7: verbatim com palavra fora de interpolação
DIR_RUIM_VERBATIM="$TMPDIR_TESTE/ruim_verbatim"
mkdir -p "$DIR_RUIM_VERBATIM"
cat <<'SWIFT' > "$DIR_RUIM_VERBATIM/TelaVerbatim.swift"
import SwiftUI

struct TelaVerbatim: View {
    let opcao = "Sim"
    var body: some View {
        Text(verbatim: "Refeição: \(opcao)")
    }
}
SWIFT
esperar_reprovacao "verbatim com palavra fora de interpolação" "verbatim com palavra fora de interpolação" "$DIR_RUIM_VERBATIM"

DIR_BOM_VERBATIM="$TMPDIR_TESTE/bom_verbatim"
mkdir -p "$DIR_BOM_VERBATIM"
cat <<'SWIFT' > "$DIR_BOM_VERBATIM/TelaVerbatimBoa.swift"
import SwiftUI

struct TelaVerbatimBoa: View {
    let a = "1"
    let b = "2"
    let variavel = "dado"
    var body: some View {
        VStack {
            Text(verbatim: "\(a) · \(b)")
            Text(verbatim: variavel)
            Text(verbatim: "")
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_VERBATIM"

# Caso 8: Ignora comentários
DIR_BOM_COMENTARIOS="$TMPDIR_TESTE/bom_comentarios"
mkdir -p "$DIR_BOM_COMENTARIOS"
cat <<'SWIFT' > "$DIR_BOM_COMENTARIOS/TelaComentarios.swift"
import SwiftUI

// Button("Salvar") { }
// .accessibilityLabel("Voltar")
// .system(size: 42)
/*
Text(verbatim: "Refeição: sim")
.foregroundStyle(.red)
*/
struct TelaComentarios: View {
    var body: some View {
        EmptyView()
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_COMENTARIOS"

# Caso 9: .accessibilityLabel() sem bundle
DIR_RUIM_ACCLABEL="$TMPDIR_TESTE/ruim_acclabel"
mkdir -p "$DIR_RUIM_ACCLABEL"
cat <<'SWIFT' > "$DIR_RUIM_ACCLABEL/TelaAccLabel.swift"
import SwiftUI

struct TelaAccLabel: View {
    var body: some View {
        Image(systemName: "chevron.left")
            .accessibilityLabel("Voltar")
    }
}
SWIFT
esperar_reprovacao ".accessibilityLabel() sem bundle" ".accessibilityLabel() sem bundle" "$DIR_RUIM_ACCLABEL"

DIR_BOM_ACCLABEL="$TMPDIR_TESTE/bom_acclabel"
mkdir -p "$DIR_BOM_ACCLABEL"
cat <<'SWIFT' > "$DIR_BOM_ACCLABEL/TelaAccLabelBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaAccLabelBoa: View {
    let rotulo = "Voltar"
    var body: some View {
        VStack {
            Image(systemName: "chevron.left")
                .accessibilityLabel(Text("Voltar", bundle: bundleLocal))
            Image(systemName: "chevron.left")
                .accessibilityLabel(rotulo)
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_ACCLABEL"

# Caso 10: .accessibilityHint() sem bundle
DIR_RUIM_ACCHINT="$TMPDIR_TESTE/ruim_acchint"
mkdir -p "$DIR_RUIM_ACCHINT"
cat <<'SWIFT' > "$DIR_RUIM_ACCHINT/TelaAccHint.swift"
import SwiftUI

struct TelaAccHint: View {
    let detalhe = "Detalhe"
    var body: some View {
        Button(action: {}) { Text(verbatim: detalhe) }
            .accessibilityHint("Abre o detalhe da vaga")
    }
}
SWIFT
esperar_reprovacao ".accessibilityHint() sem bundle" ".accessibilityHint() sem bundle" "$DIR_RUIM_ACCHINT"

DIR_BOM_ACCHINT="$TMPDIR_TESTE/bom_acchint"
mkdir -p "$DIR_BOM_ACCHINT"
cat <<'SWIFT' > "$DIR_BOM_ACCHINT/TelaAccHintBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaAccHintBoa: View {
    let detalhe = "Detalhe"
    var body: some View {
        Button(action: {}) { Text(verbatim: detalhe) }
            .accessibilityHint(Text("Abre o detalhe da vaga", bundle: bundleLocal))
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_ACCHINT"

# Caso 11: .accessibilityValue() sem bundle
DIR_RUIM_ACCVAL="$TMPDIR_TESTE/ruim_accval"
mkdir -p "$DIR_RUIM_ACCVAL"
cat <<'SWIFT' > "$DIR_RUIM_ACCVAL/TelaAccVal.swift"
import SwiftUI

struct TelaAccVal: View {
    let marcado = true
    var body: some View {
        Rectangle()
            .accessibilityValue(marcado ? "Selecionado" : "Não selecionado")
    }
}
SWIFT
esperar_reprovacao ".accessibilityValue() sem bundle" ".accessibilityValue() sem bundle" "$DIR_RUIM_ACCVAL"

DIR_BOM_ACCVAL="$TMPDIR_TESTE/bom_accval"
mkdir -p "$DIR_BOM_ACCVAL"
cat <<'SWIFT' > "$DIR_BOM_ACCVAL/TelaAccValBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaAccValBoa: View {
    let marcado = true
    var body: some View {
        Rectangle()
            .accessibilityValue(Text(marcado ? "Selecionado" : "Não selecionado", bundle: bundleLocal))
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_ACCVAL"

# Caso 12: .navigationTitle() sem bundle
DIR_RUIM_NAVTITLE="$TMPDIR_TESTE/ruim_navtitle"
mkdir -p "$DIR_RUIM_NAVTITLE"
cat <<'SWIFT' > "$DIR_RUIM_NAVTITLE/TelaNavTitle.swift"
import SwiftUI

struct TelaNavTitle: View {
    let conteudo = "Conteúdo"
    var body: some View {
        Text(verbatim: conteudo)
            .navigationTitle("Título solto")
    }
}
SWIFT
esperar_reprovacao ".navigationTitle() sem bundle" ".navigationTitle() sem bundle" "$DIR_RUIM_NAVTITLE"

DIR_BOM_NAVTITLE="$TMPDIR_TESTE/bom_navtitle"
mkdir -p "$DIR_BOM_NAVTITLE"
cat <<'SWIFT' > "$DIR_BOM_NAVTITLE/TelaNavTitleBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaNavTitleBoa: View {
    let conteudo = "Conteúdo"
    var body: some View {
        Text(verbatim: conteudo)
            .navigationTitle(Text("Título", bundle: bundleLocal))
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_NAVTITLE"

# Caso 13: Label() com texto sem bundle
DIR_RUIM_LABEL="$TMPDIR_TESTE/ruim_label"
mkdir -p "$DIR_RUIM_LABEL"
cat <<'SWIFT' > "$DIR_RUIM_LABEL/TelaLabel.swift"
import SwiftUI

struct TelaLabel: View {
    var body: some View {
        Label("Rótulo", systemImage: "star")
    }
}
SWIFT
esperar_reprovacao "Label() com texto sem bundle" "Label() com texto sem bundle" "$DIR_RUIM_LABEL"

DIR_BOM_LABEL="$TMPDIR_TESTE/bom_label"
mkdir -p "$DIR_BOM_LABEL"
cat <<'SWIFT' > "$DIR_BOM_LABEL/TelaLabelBoa.swift"
import SwiftUI

struct TelaLabelBoa: View {
    let distancia = "2 km"
    let local = "Asa Sul"
    var body: some View {
        Label {
            Text(verbatim: "\(distancia) · \(local)")
        } icon: {
            Image(systemName: "mappin.and.ellipse")
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_LABEL"

# Caso 14: Button() com texto sem bundle
DIR_RUIM_BUTTON="$TMPDIR_TESTE/ruim_button"
mkdir -p "$DIR_RUIM_BUTTON"
cat <<'SWIFT' > "$DIR_RUIM_BUTTON/TelaButton.swift"
import SwiftUI

struct TelaButton: View {
    var body: some View {
        Button("Salvar") { }
    }
}
SWIFT
esperar_reprovacao "Button() com texto sem bundle" "Button() com texto sem bundle" "$DIR_RUIM_BUTTON"

DIR_BOM_BUTTON="$TMPDIR_TESTE/bom_button"
mkdir -p "$DIR_BOM_BUTTON"
cat <<'SWIFT' > "$DIR_BOM_BUTTON/TelaButtonBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaButtonBoa: View {
    var body: some View {
        Button(action: {}) {
            Text("Salvar", bundle: bundleLocal)
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_BUTTON"

# Caso 15: TextField() com texto sem bundle
DIR_RUIM_TEXTFIELD="$TMPDIR_TESTE/ruim_textfield"
mkdir -p "$DIR_RUIM_TEXTFIELD"
cat <<'SWIFT' > "$DIR_RUIM_TEXTFIELD/TelaTextField.swift"
import SwiftUI

struct TelaTextField: View {
    @State private var texto = ""
    var body: some View {
        TextField("Digite seu nome", text: $texto)
    }
}
SWIFT
esperar_reprovacao "TextField() com texto sem bundle" "TextField() com texto sem bundle" "$DIR_RUIM_TEXTFIELD"

DIR_BOM_TEXTFIELD="$TMPDIR_TESTE/bom_textfield"
mkdir -p "$DIR_BOM_TEXTFIELD"
cat <<'SWIFT' > "$DIR_BOM_TEXTFIELD/TelaTextFieldBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaTextFieldBoa: View {
    @State private var texto = ""
    var body: some View {
        TextField(text: $texto, prompt: Text("Digite seu nome", bundle: bundleLocal)) {
            Text("Nome", bundle: bundleLocal)
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_TEXTFIELD"

# Caso 16: Toggle() com texto sem bundle
DIR_RUIM_TOGGLE="$TMPDIR_TESTE/ruim_toggle"
mkdir -p "$DIR_RUIM_TOGGLE"
cat <<'SWIFT' > "$DIR_RUIM_TOGGLE/TelaToggle.swift"
import SwiftUI

struct TelaToggle: View {
    @State private var ativo = false
    var body: some View {
        Toggle("Receber alertas", isOn: $ativo)
    }
}
SWIFT
esperar_reprovacao "Toggle() com texto sem bundle" "Toggle() com texto sem bundle" "$DIR_RUIM_TOGGLE"

DIR_BOM_TOGGLE="$TMPDIR_TESTE/bom_toggle"
mkdir -p "$DIR_BOM_TOGGLE"
cat <<'SWIFT' > "$DIR_BOM_TOGGLE/TelaToggleBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaToggleBoa: View {
    @State private var ativo = false
    var body: some View {
        Toggle(isOn: $ativo) {
            Text("Receber alertas", bundle: bundleLocal)
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_TOGGLE"

# Caso 17: Picker() com texto sem bundle
DIR_RUIM_PICKER="$TMPDIR_TESTE/ruim_picker"
mkdir -p "$DIR_RUIM_PICKER"
cat <<'SWIFT' > "$DIR_RUIM_PICKER/TelaPicker.swift"
import SwiftUI

struct TelaPicker: View {
    @State private var item = 0
    var body: some View {
        Picker("Opção", selection: $item) {
            Text(verbatim: "1").tag(0)
        }
    }
}
SWIFT
esperar_reprovacao "Picker() com texto sem bundle" "Picker() com texto sem bundle" "$DIR_RUIM_PICKER"

DIR_BOM_PICKER="$TMPDIR_TESTE/bom_picker"
mkdir -p "$DIR_BOM_PICKER"
cat <<'SWIFT' > "$DIR_BOM_PICKER/TelaPickerBoa.swift"
import SwiftUI

struct TelaPickerBoa: View {
    @State private var item = 0
    var body: some View {
        Picker(selection: $item) {
            Text(verbatim: "1").tag(0)
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_PICKER"

# Caso 18: Section() com texto sem bundle
DIR_RUIM_SECTION="$TMPDIR_TESTE/ruim_section"
mkdir -p "$DIR_RUIM_SECTION"
cat <<'SWIFT' > "$DIR_RUIM_SECTION/TelaSection.swift"
import SwiftUI

struct TelaSection: View {
    var body: some View {
        Section("Dados Pessoais") {
            EmptyView()
        }
    }
}
SWIFT
esperar_reprovacao "Section() com texto sem bundle" "Section() com texto sem bundle" "$DIR_RUIM_SECTION"

DIR_BOM_SECTION="$TMPDIR_TESTE/bom_section"
mkdir -p "$DIR_BOM_SECTION"
cat <<'SWIFT' > "$DIR_BOM_SECTION/TelaSectionBoa.swift"
import SwiftUI

private final class Marcador: NSObject {}
private let bundleLocal = Bundle(for: Marcador.self)

struct TelaSectionBoa: View {
    var body: some View {
        Section(header: Text("Dados Pessoais", bundle: bundleLocal)) {
            EmptyView()
        }
    }
}
SWIFT
esperar_aprovacao "$DIR_BOM_SECTION"

# Promessas e cartões são recusados em literais, chaves e traduções, mas não em comentários.
for texto in 'Disponível no cartão #219' 'Em breve' 'Na próxima versão' 'Em desenvolvimento'; do
  cat > "$TMPDIR_TESTE/promessa.swift" <<SWIFT
let texto = String(localized: "$texto", bundle: bundleLocal)
SWIFT
  esperar_reprovacao "texto de app incompleto" "Texto de app com promessa ou cartão interno" "$TMPDIR_TESTE/promessa.swift"
done
cat > "$TMPDIR_TESTE/comentarios.swift" <<'SWIFT'
// Disponível no cartão #219, em breve.
/* próxima versão, em desenvolvimento */
let texto = String(localized: "Disponível", bundle: bundleLocal)
SWIFT
esperar_aprovacao "$TMPDIR_TESTE/comentarios.swift"
mkdir -p "$TMPDIR_TESTE/catalogo"
cp "$TMPDIR_TESTE/comentarios.swift" "$TMPDIR_TESTE/catalogo/Tela.swift"
cat > "$TMPDIR_TESTE/catalogo/Localizable.xcstrings" <<'JSON'
{"strings":{"Título":{"comment":"Implementado no cartão #50","localizations":{"pt-BR":{"stringUnit":{"value":"Disponível"}}}}}}
JSON
esperar_aprovacao "$TMPDIR_TESTE/catalogo"
cat > "$TMPDIR_TESTE/catalogo/Localizable.xcstrings" <<'JSON'
{"strings":{"Título":{"localizations":{"pt-BR":{"stringUnit":{"value":"Em desenvolvimento"}}}}}}
JSON
esperar_reprovacao "tradução incompleta" "Texto de app com promessa ou cartão interno" "$TMPDIR_TESTE/catalogo"
cat > "$TMPDIR_TESTE/catalogo/Localizable.xcstrings" <<'JSON'
{"strings":{"Disponível no cartão #50":{}}}
JSON
esperar_reprovacao "chave interna" "Texto de app com promessa ou cartão interno" "$TMPDIR_TESTE/catalogo"

echo "OK: autoteste de conferir-textos.sh passou"
