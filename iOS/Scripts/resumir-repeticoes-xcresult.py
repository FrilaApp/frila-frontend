#!/usr/bin/env python3
"""
Analisa o xcresult após a execução dos testes e gera um resumo em Markdown
para o GITHUB_STEP_SUMMARY, destacando testes que precisaram de retry (-retry-tests-on-failure)
e seu resultado final.
"""

import json
import os
import subprocess
import sys


def extrair_testes_do_json(obj):
    """Percorre recursivamente a árvore do test-results do xcresulttool."""
    testes = []
    if isinstance(obj, dict):
        if "testCaseName" in obj or "name" in obj:
            # Pode ser nó de teste
            nome = obj.get("testCaseName") or obj.get("name", "")
            status = obj.get("testStatus") or obj.get("status", "")
            runs = obj.get("testRuns") or obj.get("subtests") or []
            duracao = obj.get("duration", "")
            if status or runs:
                testes.append({
                    "nome": nome,
                    "status": status,
                    "runs": runs,
                    "raw": obj
                })
        for k, v in obj.items():
            if k not in ("testRuns", "subtests"):
                testes.extend(extrair_testes_do_json(v))
    elif isinstance(obj, list):
        for item in obj:
            testes.extend(extrair_testes_do_json(item))
    return testes


def extrair_repeticoes_do_log(xcresult_path):
    """Lê o log de texto do xcodebuild dentro do bundle para identificar retries."""
    retries = {}
    try:
        cmd = ["xcrun", "xcresulttool", "get", "log", "--type", "test", "--path", xcresult_path]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if res.returncode == 0:
            linhas = res.stdout.splitlines()
            for linha in linhas:
                # Padrão xcodebuild: "Test case '...' failed on iteration 1, retrying"
                if "failed on iteration" in linha or "retrying" in linha.lower():
                    partes = linha.split("'")
                    if len(partes) >= 2:
                        nome_teste = partes[1]
                        retries[nome_teste] = retries.get(nome_teste, 1) + 1
    except Exception:
        pass
    return retries


def extrair_insights(xcresult_path):
    """Tenta ler insights ou summary do xcresulttool."""
    insights = []
    try:
        cmd = ["xcrun", "xcresulttool", "get", "test-results", "insights", "--path", xcresult_path]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if res.returncode == 0 and res.stdout.strip():
            dados = json.loads(res.stdout)
            if isinstance(dados, list):
                insights.extend(dados)
            elif isinstance(dados, dict):
                insights.append(dados)
    except Exception:
        pass
    return insights


def main():
    if len(sys.argv) < 2:
        print("Uso: resumir-repeticoes-xcresult.py <caminho.xcresult> [titulo-parte]")
        sys.exit(0)

    xcresult_path = sys.argv[1]
    titulo_parte = sys.argv[2] if len(sys.argv) > 2 else "Testes"

    if not os.path.exists(xcresult_path):
        print(f"### 🔄 {titulo_parte}: Nenhum resultado `.xcresult` encontrado em `{xcresult_path}`.")
        sys.exit(0)

    # 1. Tenta extrair do log do console
    retries_log = extrair_repeticoes_do_log(xcresult_path)

    # 2. Tenta extrair da API JSON do test-results tests
    testes_com_repeticao = []
    try:
        cmd = ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", xcresult_path]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
        if res.returncode == 0 and res.stdout.strip():
            dados = json.loads(res.stdout)
            todos = extrair_testes_do_json(dados)
            for t in todos:
                runs = t.get("runs", [])
                if len(runs) > 1:
                    testes_com_repeticao.append({
                        "nome": t["nome"],
                        "iteracoes": len(runs),
                        "status": t["status"]
                    })
    except Exception:
        pass

    # Combina achados de log e json
    todos_retries = {}
    for t in testes_com_repeticao:
        todos_retries[t["nome"]] = {
            "iteracoes": t["iteracoes"],
            "status": "✅ Passou (flake recuperado)" if t["status"] in ("Passed", "passed") else f"❌ {t['status']}"
        }

    for nome, count in retries_log.items():
        if nome not in todos_retries:
            todos_retries[nome] = {
                "iteracoes": count,
                "status": "⚠️ Repetido (ver log do xcodebuild)"
            }

    print(f"### 🔄 {titulo_parte} — Auditoria de Repetições e Flakes (`xcodebuild -retry-tests-on-failure`)")
    print()
    if todos_retries:
        print(f"**Atenção:** {len(todos_retries)} teste(s) apresentaram instabilidade e necessitaram de repetição:")
        print()
        print("| Teste | Iterações Realizadas | Status Final |")
        print("| :--- | :---: | :--- |")
        for nome, info in sorted(todos_retries.items()):
            print(f"| `{nome}` | {info['iteracoes']} | {info['status']} |")
        print()
        print("> ℹ️ *Os testes acima foram recuperados automaticamente pelo mecanismo de retry do xcodebuild sem mascarar o log.*")
    else:
        print("✅ *Nenhum teste precisou de repetição nesta execução (todos passaram de primeira ou falhas foram definitivas).*")
    print()


if __name__ == "__main__":
    main()
