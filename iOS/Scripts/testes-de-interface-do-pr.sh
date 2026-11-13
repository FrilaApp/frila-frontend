#!/bin/bash

# Escolhe os testes de interface que um PR roda (.github/workflows/ios.yml, job B): a fumaça
# (Tests/fumaca-ui.txt) mais as classes que o diff pede (Tests/mapa-ui-por-pasta.txt). A suíte inteira
# roda na noturna e antes do TestFlight (ios-suite-completa.yml).
#
# Uso (a partir de iOS/ ou de qualquer pasta):
#   Scripts/testes-de-interface-do-pr.sh escolher <base>
#       <base> é o commit ou ramo base do PR; os arquivos vêm de `git diff --name-only <base>...HEAD`.
#       Imprime os argumentos do xcodebuild, um por linha (-only-testing:FrilaUITests/Classe[/metodo]).
#       Quando o diff exige a suíte inteira de interface, imprime só `-only-testing:FrilaUITests`.
#       O motivo de cada arquivo vai para a saída de erro. Entre as linhas do mapa que casam com um arquivo,
#       vale a mais específica (mais caracteres fixos no prefixo: arquivo ou glob ganha da pasta).
#   Scripts/testes-de-interface-do-pr.sh escolher --arquivos <lista.txt>
#       Igual, com os caminhos (relativos à raiz do repositório, um por linha) de um arquivo, ou `-` para stdin.
#   Scripts/testes-de-interface-do-pr.sh conferir
#       Valida o mapa e a fumaça contra o código, sem compilar: reprova classe ou método que não existe,
#       prefixo que não existe no disco, marcador desconhecido e classe de interface que não está no mapa,
#       no marcador @visual, na fumaça nem em @so-noturna.
#
# ESCOLHER_RAIZ troca a pasta iOS e ESCOLHER_MAPA / ESCOLHER_FUMACA trocam as listas (usados pelo autoteste).
# ESCOLHER_REPO troca a raiz do repositório (onde roda o git diff).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="${ESCOLHER_RAIZ:-$SCRIPT_DIR/..}"
MAPA="${ESCOLHER_MAPA:-$RAIZ/Tests/mapa-ui-por-pasta.txt}"
FUMACA="${ESCOLHER_FUMACA:-$RAIZ/Tests/fumaca-ui.txt}"
REPO="${ESCOLHER_REPO:-$RAIZ/..}"

falhar() {
  echo "ERRO: $*" >&2
  exit 1
}

uso() {
  falhar "uso: $0 escolher <base> | escolher --arquivos <lista.txt|-> | conferir"
}

# O mesmo programa serve aos dois comandos; o comando chega em $1 do Python.
programa() {
  # shellcheck disable=SC2016  # o programa Python é de propósito um texto literal entre aspas simples
  MAPA="$MAPA" FUMACA="$FUMACA" RAIZ="$RAIZ" python3 -I -c '
import fnmatch, os, re, sys

comando = sys.argv[1]
raiz = os.environ["RAIZ"]
alvo_ui = "FrilaUITests"
pasta_ui = os.path.join(raiz, "Tests", "UI")

def falhar(mensagem):
    print("ERRO: " + mensagem, file=sys.stderr)
    sys.exit(1)

declaracao = re.compile(
    r"^\s*(?:@\w+\s+)*(?:(?:public|internal|open|final)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b", re.M)
metodo = re.compile(r"^\s*(?:@\w+\s+)*(?:private\s+)?func\s+(test\w*)\s*\(", re.M)

# classe -> arquivo e métodos; arquivo -> classes (só do alvo de interface)
classes = {}
arquivos = {}
if not os.path.isdir(pasta_ui):
    falhar(f"pasta dos testes de interface não encontrada: {pasta_ui}")
for diretorio, _, nomes in sorted(os.walk(pasta_ui)):
    for nome in sorted(nomes):
        if not nome.endswith(".swift"):
            continue
        caminho = os.path.join(diretorio, nome)
        relativo = os.path.relpath(caminho, raiz).replace(os.sep, "/")
        with open(caminho, encoding="utf-8") as arquivo:
            texto = arquivo.read()
        marcas = [(m.start(), m.group(1)) for m in declaracao.finditer(texto)]
        for i, (inicio, classe) in enumerate(marcas):
            fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(texto)
            classes[classe] = {"arquivo": relativo, "metodos": set(metodo.findall(texto[inicio:fim]))}
            arquivos.setdefault(relativo, []).append(classe)

marcadores_reservados = {"@fumaca", "@completa", "@visual"}

def ler_mapa():
    caminho = os.environ["MAPA"]
    if not os.path.isfile(caminho):
        falhar(f"mapa não encontrado: {caminho}")
    linhas = []   # (prefixo, [destinos])
    definidos = {}  # @visual, @so-noturna
    vistos = set()
    with open(caminho, encoding="utf-8") as arquivo:
        for numero, linha in enumerate(arquivo, 1):
            linha = re.sub(r"#.*", "", linha).strip()
            if not linha:
                continue
            if "=" not in linha:
                falhar(f"{caminho}:{numero}: linha sem `=`: {linha}")
            esquerda, direita = (parte.strip() for parte in linha.split("=", 1))
            destinos = [d.strip() for d in direita.split(",") if d.strip()]
            if not esquerda or not destinos:
                falhar(f"{caminho}:{numero}: linha incompleta: {linha}")
            if esquerda in ("@visual", "@so-noturna"):
                if esquerda in definidos:
                    falhar(f"{caminho}:{numero}: marcador {esquerda} definido duas vezes")
                definidos[esquerda] = destinos
                continue
            if esquerda.startswith("@"):
                falhar(f"{caminho}:{numero}: marcador desconhecido: {esquerda}")
            if esquerda in vistos:
                falhar(f"{caminho}:{numero}: prefixo repetido: {esquerda}")
            vistos.add(esquerda)
            linhas.append((esquerda, destinos))
    for obrigatorio in ("@visual", "@so-noturna"):
        if obrigatorio not in definidos:
            falhar(f"{caminho}: falta a definição de {obrigatorio}")
    return linhas, definidos

def ler_fumaca():
    caminho = os.environ["FUMACA"]
    if not os.path.isfile(caminho):
        falhar(f"fumaça não encontrada: {caminho}")
    itens = []
    vistos = set()
    with open(caminho, encoding="utf-8") as arquivo:
        for numero, linha in enumerate(arquivo, 1):
            linha = re.sub(r"#.*", "", linha).strip()
            if not linha:
                continue
            partes = linha.split("/")
            if len(partes) not in (2, 3) or partes[0] != alvo_ui or not all(re.fullmatch(r"\w+", p) for p in partes):
                falhar(f"{caminho}:{numero}: entrada fora do formato FrilaUITests/Classe[/metodo]: {linha}")
            if linha in vistos:
                falhar(f"{caminho}:{numero}: entrada repetida: {linha}")
            vistos.add(linha)
            itens.append((partes[1], partes[2] if len(partes) == 3 else None))
    if not itens:
        falhar(f"fumaça vazia: {caminho}")
    return itens

def casa(prefixo, caminho):
    if "*" in prefixo:
        return fnmatch.fnmatchcase(caminho, prefixo)
    return caminho.startswith(prefixo) if prefixo.endswith("/") else caminho == prefixo

def especificidade(prefixo):
    # Quanto mais caracteres fixos, mais específico: o arquivo ganha da pasta e o glob ganha da pasta dele.
    return len(prefixo.replace("*", ""))

def existe_no_disco(prefixo):
    if "*" in prefixo:
        for diretorio, _, nomes in os.walk(raiz):
            for nome in nomes:
                relativo = os.path.relpath(os.path.join(diretorio, nome), raiz).replace(os.sep, "/")
                if fnmatch.fnmatchcase(relativo, prefixo):
                    return True
        return False
    caminho = os.path.join(raiz, prefixo)
    return os.path.isdir(caminho) if prefixo.endswith("/") else os.path.isfile(caminho)

if comando == "conferir":
    linhas, definidos = ler_mapa()
    fumaca = ler_fumaca()
    cobertas = set()
    for prefixo, destinos in linhas:
        if not existe_no_disco(prefixo):
            falhar(f"prefixo do mapa que não existe no disco: iOS/{prefixo}")
        for destino in destinos:
            if destino.startswith("@"):
                if destino not in marcadores_reservados:
                    falhar(f"destino desconhecido na linha de iOS/{prefixo}: {destino}")
            elif destino not in classes:
                falhar(f"classe {destino} (linha de iOS/{prefixo}) não existe em {alvo_ui}")
            else:
                cobertas.add(destino)
    for marcador, destinos in definidos.items():
        for destino in destinos:
            if destino not in classes:
                falhar(f"classe {destino} (marcador {marcador}) não existe em {alvo_ui}")
            cobertas.add(destino)
    for classe, nome in fumaca:
        if classe not in classes:
            falhar(f"classe {classe} da fumaça não existe em {alvo_ui}")
        if nome is not None and nome not in classes[classe]["metodos"]:
            falhar(f"método {classe}/{nome} da fumaça não existe no código (renomeado ou apagado?)")
        cobertas.add(classe)
    fora = sorted(set(classes) - cobertas)
    if fora:
        falhar("classe(s) de interface fora do mapa, da fumaça e de @so-noturna (acrescente a classe a uma linha do mapa, "
               "a @visual, a @so-noturna ou à fumaça): " + ", ".join(fora))
    print(f"OK: {len(linhas)} prefixos, {len(fumaca)} entradas de fumaça e as {len(classes)} classes de {alvo_ui} cobertas.")
    sys.exit(0)

# comando == "escolher": os caminhos vêm do stdin, um por linha, relativos à raiz do repositório.
linhas, definidos = ler_mapa()
fumaca = ler_fumaca()
arquivos_alterados = [l.strip() for l in sys.stdin.read().splitlines() if l.strip()]

escolhidas = set()
completa = False
for caminho in arquivos_alterados:
    if not caminho.startswith("iOS/"):
        print(f"  {caminho}: fora de iOS/, só a fumaça", file=sys.stderr)
        continue
    relativo = caminho[len("iOS/"):]
    motivos = []
    if relativo in arquivos:
        escolhidas.update(arquivos[relativo])
        motivos.append("as classes do próprio arquivo: " + ", ".join(arquivos[relativo]) if arquivos[relativo] else "arquivo de apoio dos testes")
    casadas = [(prefixo, destinos) for prefixo, destinos in linhas if casa(prefixo, relativo)]
    if casadas:
        maior = max(especificidade(prefixo) for prefixo, _ in casadas)
        casadas = [(prefixo, destinos) for prefixo, destinos in casadas if especificidade(prefixo) == maior]
    for prefixo, destinos in casadas:
        for destino in destinos:
            if destino == "@completa":
                completa = True
            elif destino == "@visual":
                escolhidas.update(definidos["@visual"])
            elif destino != "@fumaca":
                escolhidas.add(destino)
        rotulo = ", ".join(destinos)
        motivos.append(f"{prefixo}: {rotulo}" if len(rotulo) < 90 else f"{prefixo}: {len(destinos)} destinos")
    if not motivos:
        completa = True
        motivos.append("nenhum prefixo do mapa cobre este caminho: suíte inteira (na dúvida, tudo)")
    for motivo in motivos:
        print(f"  {caminho}: {motivo}", file=sys.stderr)

if completa:
    print(f"-only-testing:{alvo_ui}")
    sys.exit(0)

saida = set()
for classe in escolhidas:
    saida.add(f"-only-testing:{alvo_ui}/{classe}")
for classe, nome in fumaca:
    if classe in escolhidas:
        continue
    saida.add(f"-only-testing:{alvo_ui}/{classe}" + (f"/{nome}" if nome else ""))
# Fumaça que pede a classe inteira vence a que pede só um método dela.
inteiras = {s for s in saida if s.count("/") == 1}
saida = {s for s in saida if s.count("/") == 1 or "/".join(s.split("/")[:2]) not in inteiras}
print("\n".join(sorted(saida)))
' "$@"
}

escolher() {
  local entrada
  if [[ "${1:-}" == "--arquivos" ]]; then
    [[ $# -eq 2 ]] || uso
    if [[ "$2" == "-" ]]; then
      entrada="$(cat)"
    else
      [[ -f "$2" ]] || falhar "lista de arquivos não encontrada: $2"
      entrada="$(cat "$2")"
    fi
  else
    [[ $# -eq 1 ]] || uso
    entrada="$(git -C "$REPO" diff --name-only "$1...HEAD")" || falhar "git diff contra $1 falhou (base ausente? use fetch-depth: 0)"
  fi
  printf '%s\n' "$entrada" | programa escolher
}

case "${1:-}" in
  escolher) shift; escolher "$@" ;;
  conferir) shift; [[ $# -eq 0 ]] || uso; programa conferir </dev/null ;;
  *) uso ;;
esac
