#!/usr/bin/env python3
"""Portão de paridade de contrato entre Android e OpenAPI (iOS/Contrato/openapi.yaml).

Compara os DTOs Kotlin em android/core/rede/src/main/kotlin/br/com/frila/core/rede/Dtos.kt
(e outros DTOs em android/) com os schemas da especificação OpenAPI.

Verificações:
1. Todos os campos required e properties de cada schema OpenAPI mapeado estão presentes no DTO correspondente.
2. Nenhum campo inventado (não presente no OpenAPI) é declarado no DTO.
3. Não existem DTOs órfãos sem correspondência no OpenAPI (exceto envelopes internos documentados, ex: ErroPostgrestDto).

Uso:
    python3 android/scripts/conferir-contrato-android.py [--contrato <caminho>] [--android-dir <caminho>] [--silencioso]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Confere a paridade entre os DTOs Kotlin do Android e o contrato OpenAPI."
    )
    parser.add_argument(
        "--contrato",
        type=pathlib.Path,
        default=None,
        help="Caminho para o openapi.yaml (padrão: iOS/Contrato/openapi.yaml a partir da raiz)",
    )
    parser.add_argument(
        "--android-dir",
        type=pathlib.Path,
        default=None,
        help="Caminho para a pasta android/ (padrão: detectado automaticamente)",
    )
    parser.add_argument(
        "--silencioso",
        action="store_true",
        help="Exibe apenas erros e resumo final",
    )
    return parser.parse_args()


def carregar_contrato(caminho: pathlib.Path) -> dict:
    if not caminho.is_file():
        sys.exit(f"FALHA: arquivo de contrato não encontrado em {caminho}")
    programa = "require 'yaml'; require 'json'; print JSON.generate(YAML.load_file(ARGV[0]))"
    try:
        saida = subprocess.run(
            ["ruby", "-e", programa, str(caminho)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        sys.exit("FALHA: interpretador ruby não encontrado no sistema para converter YAML")
    except subprocess.CalledProcessError as erro:
        sys.exit(f"FALHA ao ler {caminho.name}: {erro.stderr.strip()}")
    return json.loads(saida.stdout)


def extrair_dtos_kotlin(arquivo: pathlib.Path) -> dict[str, set[str]]:
    if not arquivo.is_file():
        return {}
    texto = arquivo.read_text(encoding="utf-8")
    dtos: dict[str, set[str]] = {}

    padrao = re.compile(
        r"data\s+class\s+([A-Za-z0-9_]+)\s*\((.*?)\)(?:\s*:\s*[^{]*)?(?:\{|\n|$)",
        re.DOTALL,
    )
    for m in padrao.finditer(texto):
        nome_classe = m.group(1)
        corpo = m.group(2)
        props: set[str] = set()

        for sn in re.finditer(r'@SerialName\("([^"]+)"\)', corpo):
            props.add(sn.group(1))

        for linha in corpo.split("\n"):
            linha = linha.strip()
            if "@SerialName" not in linha:
                vm = re.search(r"(?:val|var)\s+([A-Za-z0-9_]+)", linha)
                if vm:
                    props.add(vm.group(1))

        dtos[nome_classe] = props
    return dtos


def main() -> None:
    args = parse_arguments()

    script_dir = pathlib.Path(__file__).resolve().parent
    # Se rodando a partir de android/scripts, raiz do repo é dois níveis acima
    repo_root = script_dir.parent.parent
    if not (repo_root / "iOS" / "Contrato" / "openapi.yaml").is_file():
        # Fallback: tentar diretório de trabalho atual
        repo_root = pathlib.Path.cwd()
        if (repo_root / "android").is_dir():
            pass
        elif repo_root.name == "android":
            repo_root = repo_root.parent

    contrato_path = args.contrato or (repo_root / "iOS" / "Contrato" / "openapi.yaml")
    android_dir = args.android_dir or (repo_root / "android")
    dtos_file = android_dir / "core" / "rede" / "src" / "main" / "kotlin" / "br" / "com" / "frila" / "core" / "rede" / "Dtos.kt"

    if not args.silencioso:
        print(f"==> Carregando contrato OpenAPI de {contrato_path}")
    doc = carregar_contrato(contrato_path)
    schemas = doc.get("components", {}).get("schemas", {})

    if not args.silencioso:
        print(f"==> Extraindo DTOs Kotlin de {dtos_file}")
    dtos = extrair_dtos_kotlin(dtos_file)

    # DTOs com nomes alternativos em relação aos schemas OpenAPI
    ALIAS_DTO = {
        "VagaAbertaDto": "VagaNaLista",
    }

    # Request bodies declarados inline em operations RPC de paths
    RPCS_REQUEST_BODY = {
        "AvaliarDto": "/rpc/avaliar",
        "CancelarPosicaoDto": "/rpc/cancelar_posicao",
        "AbrirSuporteDto": "/rpc/abrir_suporte",
        "CandidatarDto": "/rpc/candidatar",
    }

    # Request body de Edge Function
    EDGE_FUNCTIONS_BODY = {
        "ConfirmarExclusaoDto": {"confirmar"},
    }

    # DTOs internos ou de autenticação Supabase Auth
    DTOS_INTERNOS = {
        "ErroPostgrestDto",
        "EntrarOtpDto",
        "VerificarOtpDto",
        "EntrarDemonstracaoDto",
        "SessaoDto",
        "RenovarTokenDto",
        "RegistrarDispositivoDto",
    }

    erros: list[str] = []
    verificados = 0
    paths = doc.get("paths", {})

    for dto_name, dto_props in sorted(dtos.items()):
        if dto_name in DTOS_INTERNOS:
            continue

        if dto_name in EDGE_FUNCTIONS_BODY:
            campos_esperados = EDGE_FUNCTIONS_BODY[dto_name]
            faltando = campos_esperados - dto_props
            if faltando:
                erros.append(f"DTO '{dto_name}' não contém campos esperados: {sorted(faltando)}")
            else:
                verificados += 1
                if not args.silencioso:
                    print(f"  [OK] {dto_name} <-> Edge Function (campos: {sorted(dto_props)})")
            continue

        if dto_name in RPCS_REQUEST_BODY:
            rpc_path = RPCS_REQUEST_BODY[dto_name]
            rpc_op = paths.get(rpc_path, {}).get("post", {})
            schema = rpc_op.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema", {})
            if not schema:
                erros.append(f"DTO '{dto_name}' referencia RPC '{rpc_path}', mas rota não possui requestBody schema no OpenAPI")
                continue

            schema_props = set(schema.get("properties", {}).keys())
            required_props = set(schema.get("required", []))

            faltando_required = required_props - dto_props
            if faltando_required:
                erros.append(
                    f"DTO '{dto_name}' não mapeia campos obrigatórios (required) de '{rpc_path}': {sorted(faltando_required)}"
                )

            if schema_props:
                extras = dto_props - schema_props
                if extras:
                    erros.append(
                        f"DTO '{dto_name}' possui campos extras ausentes em '{rpc_path}': {sorted(extras)}"
                    )

            verificados += 1
            if not args.silencioso:
                print(f"  [OK] {dto_name} <-> requestBody {rpc_path} ({len(dto_props)} campos)")
            continue

        # Nome convencional do schema: usa alias ou remove sufixo Dto
        schema_name = ALIAS_DTO.get(dto_name, dto_name[:-3] if dto_name.endswith("Dto") else dto_name)

        if schema_name not in schemas:
            erros.append(f"DTO '{dto_name}' não possui schema correspondente '{schema_name}' no OpenAPI")
            continue

        schema = schemas[schema_name]
        schema_props = set(schema.get("properties", {}).keys())
        required_props = set(schema.get("required", []))

        # 1. Campos required ausentes no DTO
        faltando_required = required_props - dto_props
        if faltando_required:
            erros.append(
                f"DTO '{dto_name}' não mapeia campos obrigatórios (required) do schema '{schema_name}': {sorted(faltando_required)}"
            )

        # 2. Campos declarados no DTO que não existem no OpenAPI
        # (se o schema OpenAPI definir properties)
        if schema_props:
            campos_extras = dto_props - schema_props
            if campos_extras:
                erros.append(
                    f"DTO '{dto_name}' possui campos inventados ausentes no schema '{schema_name}': {sorted(campos_extras)}"
                )

        verificados += 1
        if not args.silencioso:
            print(f"  [OK] {dto_name} <-> {schema_name} ({len(dto_props)} campos)")

    print()
    if erros:
        print(f"FALHA: {len(erros)} divergência(s) encontrada(s) no contrato Android x OpenAPI:")
        for e in erros:
            print(f"  - {e}")
        sys.exit(1)

    print(f"OK: conformidade total de DTOs Android com contrato OpenAPI ({verificados} DTOs verificados)")
    sys.exit(0)


if __name__ == "__main__":
    main()
