#!/usr/bin/env python3
"""
Gera resumo de testes que precisaram de repetição (-retry-tests-on-failure) a partir de um bundle .xcresult.
Extrai os testes que falharam na primeira tentativa e passaram na segunda, calculando o tempo adicional.
Se GITHUB_STEP_SUMMARY estiver definido, anexa o resumo ao job do GitHub Actions.
"""

import json
import os
import subprocess
import sys


def obter_testes(caminho_xcresult):
    if not os.path.exists(caminho_xcresult):
        return []

    cmd = ["xcrun", "xcresulttool", "get", "test-results", "tests", "--compact", "--path", caminho_xcresult]
    resultado = subprocess.run(cmd, capture_output=True, text=True)
    if resultado.returncode != 0 or not resultado.stdout.strip():
        return []

    try:
        dados = json.loads(resultado.stdout)
    except json.JSONDecodeError:
        return []

    test_cases = []

    def buscar_test_cases(nodo, suite_nome=""):
        tipo = nodo.get("nodeType")
        nome = nodo.get("name", "")
        if tipo == "Test Suite":
            suite_nome = nome
        elif tipo == "Test Case":
            identificador = nodo.get("nodeIdentifier", f"{suite_nome}/{nome}")
            test_cases.append({
                "nome": nome,
                "suite": suite_nome,
                "identificador": identificador,
                "resultado": nodo.get("result"),
                "duracao": nodo.get("durationInSeconds", 0.0),
                "filhos": nodo.get("children", []),
            })
        for filho in nodo.get("children", []):
            buscar_test_cases(filho, suite_nome)

    for raiz in dados.get("testNodes", []):
        buscar_test_cases(raiz)

    return test_cases


def analisar_repeticoes(caminho_xcresult, testes):
    repetidos = []

    for teste in testes:
        # Se tem filhos diretos (repetições) ou precisamos verificar detalhes
        tem_filhos_repeticao = any(
            f.get("nodeType") in ("Repetition", "Test Case Run") for f in teste["filhos"]
        ) or len(teste["filhos"]) > 1

        # Consultar test-details se houver indicativo ou para testes que passaram
        precisa_consultar = tem_filhos_repeticao

        if precisa_consultar or teste["resultado"] == "Passed":
            cmd = [
                "xcrun", "xcresulttool", "get", "test-results", "test-details",
                "--compact", "--path", caminho_xcresult,
                "--test-id", teste["identificador"]
            ]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                try:
                    detalhes = json.loads(res.stdout)
                    runs = detalhes.get("testRuns", [])
                    if len(runs) > 1 and detalhes.get("testResult") == "Passed":
                        duracoes = []
                        for run in runs:
                            d = run.get("durationInSeconds", 0.0)
                            duracoes.append(d)
                        repetidos.append({
                            "suite": teste["suite"],
                            "nome": teste["nome"],
                            "identificador": teste["identificador"],
                            "tentativas": len(runs),
                            "duracoes": duracoes,
                            "tempo_total": sum(duracoes),
                            "tempo_adicional": sum(duracoes[:-1]) if len(duracoes) > 1 else 0.0,
                        })
                except json.JSONDecodeError:
                    pass

    return repetidos


def formatar_relatorio(caminho_xcresult, repetidos):
    linhas = []
    linhas.append("### 🔄 Resumo de Testes com Repetição (-retry-tests-on-failure)")
    linhas.append(f"**Bundle:** `{os.path.basename(caminho_xcresult)}`\n")

    if not repetidos:
        linhas.append("✅ **Nenhum teste precisou de segunda tentativa.** Todos os testes passaram na primeira execução.")
        return "\n".join(linhas)

    tempo_extra_total = sum(r["tempo_adicional"] for r in repetidos)
    linhas.append(f"⚠️ **{len(repetidos)} teste(s)** falharam na primeira tentativa e só passaram na segunda.")
    linhas.append(f"⏱️ **Tempo adicional consumido em repetições:** {tempo_extra_total:.2f} s (~{tempo_extra_total / 60:.1f} min)\n")
    linhas.append("| Suíte / Teste | Tentativas | Duração 1ª tentativa | Duração 2ª tentativa | Tempo adicional |")
    linhas.append("|---|---|---|---|---|")

    for r in repetidos:
        d1 = f"{r['duracoes'][0]:.2f} s" if len(r['duracoes']) > 0 else "-"
        d2 = f"{r['duracoes'][1]:.2f} s" if len(r['duracoes']) > 1 else "-"
        extra = f"+{r['tempo_adicional']:.2f} s"
        nome_completo = f"`{r['suite']}.{r['nome']}`"
        linhas.append(f"| {nome_completo} | {r['tentativas']} | {d1} | {d2} | {extra} |")

    return "\n".join(linhas)


def main():
    if len(sys.argv) < 2:
        print("Uso: relatorio-testes-repetidos.py <caminho.xcresult> [arquivo_saida.md]", file=sys.stderr)
        sys.exit(1)

    caminho_xcresult = sys.argv[1]
    saida_md = sys.argv[2] if len(sys.argv) > 2 else None

    testes = obter_testes(caminho_xcresult)
    repetidos = analisar_repeticoes(caminho_xcresult, testes)
    relatorio = formatar_relatorio(caminho_xcresult, repetidos)

    print(relatorio)

    if saida_md:
        with open(saida_md, "w", encoding="utf-8") as f:
            f.write(relatorio + "\n")

    summary_env = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_env and os.path.exists(summary_env):
        with open(summary_env, "a", encoding="utf-8") as f:
            f.write("\n" + relatorio + "\n")


if __name__ == "__main__":
    main()
