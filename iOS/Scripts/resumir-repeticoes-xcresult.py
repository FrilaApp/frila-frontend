#!/usr/bin/env python3
"""
Analisa o .xcresult após a execução dos testes e gera um resumo em Markdown
para o GITHUB_STEP_SUMMARY, destacando testes que precisaram de retry (-retry-tests-on-failure)
e seu resultado final.
"""

import json
import os
import subprocess
import sys


def percorrer_test_cases(nodes):
    """
    Percorre a árvore de testNodes do xcresulttool e localiza nós do tipo 'Test Case'.
    Em cada Test Case, analisa os filhos do tipo 'Repetition' para identificar flakes e retries.
    """
    test_cases = []
    if isinstance(nodes, list):
        for n in nodes:
            test_cases.extend(percorrer_test_cases(n))
    elif isinstance(nodes, dict):
        node_type = nodes.get("nodeType")
        if node_type == "Test Case":
            nome = nodes.get("name", "Teste desconhecido")
            resultado = nodes.get("result", "Desconhecido")
            filhos = nodes.get("children", [])
            
            # Repetições são filhos com nodeType == "Repetition"
            repeticoes = [f for f in filhos if isinstance(f, dict) and f.get("nodeType") == "Repetition"]
            
            test_cases.append({
                "nome": nome,
                "resultado": resultado,
                "repeticoes": len(repeticoes),
                "detalhes_repeticoes": repeticoes
            })
        
        # Continua descendo recursivamente em filhos
        if "children" in nodes:
            test_cases.extend(percorrer_test_cases(nodes["children"]))
    
    return test_cases


def main():
    if len(sys.argv) < 2:
        print("Uso: resumir-repeticoes-xcresult.py <caminho.xcresult> [titulo-parte]")
        sys.exit(0)

    xcresult_path = sys.argv[1]
    titulo_parte = sys.argv[2] if len(sys.argv) > 2 else "Testes"

    print(f"### 🔄 {titulo_parte} — Auditoria de Repetições e Flakes (`xcodebuild -retry-tests-on-failure`)")
    print()

    if not os.path.exists(xcresult_path):
        print(f"⚠️ *Não foi possível ler o arquivo de resultado: `{xcresult_path}` não foi encontrado.*")
        print()
        sys.exit(0)

    # Invoca o xcresulttool para extrair o grafo de testes
    cmd = ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", xcresult_path]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except Exception as e:
        print(f"⚠️ *Não foi possível ler os nós de teste do .xcresult (erro de execução: {e}).*")
        print()
        sys.exit(0)

    if res.returncode != 0 or not res.stdout.strip():
        print("⚠️ *Não foi possível ler os nós de teste do .xcresult (saída vazia ou erro do xcresulttool).*")
        print()
        sys.exit(0)

    try:
        dados = json.loads(res.stdout)
    except Exception:
        print("⚠️ *Não foi possível ler os nós de teste do .xcresult (JSON corrompido ou formato incompatível).*")
        print()
        sys.exit(0)

    test_nodes = dados.get("testNodes")
    if not test_nodes:
        print("⚠️ *Não foi possível ler os nós de teste: `testNodes` ausente ou vazio no .xcresult.*")
        print()
        sys.exit(0)

    test_cases = percorrer_test_cases(test_nodes)
    if not test_cases:
        print("⚠️ *Não foi possível ler os nós de teste: nenhum 'Test Case' identificado na árvore.*")
        print()
        sys.exit(0)

    # Filtra testes que precisaram de repetição
    testes_com_repeticao = [t for t in test_cases if t["repeticoes"] > 0]

    if testes_com_repeticao:
        print(f"**Atenção:** {len(testes_com_repeticao)} teste(s) apresentaram instabilidade e necessitaram de repetição:")
        print()
        print("| Teste | Repetições (Filhos Repetition) | Status Final |")
        print("| :--- | :---: | :--- |")
        for t in sorted(testes_com_repeticao, key=lambda x: x["nome"]):
            status_formatado = f"✅ {t['resultado']}" if t["resultado"] in ("Passed", "passed") else f"❌ {t['resultado']}"
            print(f"| `{t['nome']}` | {t['repeticoes']} | {status_formatado} |")
        print()
        print("> ℹ️ *Os testes acima foram recuperados ou repetidos pelo mecanismo de retry do xcodebuild sem mascarar a falha original.*")
    else:
        print(f"✅ *Nenhum teste precisou de repetição nesta execução ({len(test_cases)} testes executados; todos passaram de primeira ou falhas foram definitivas).*")
    print()


if __name__ == "__main__":
    main()
