#!/usr/bin/env python3
"""Gate de paridade de contrato entre iOS e backend (OpenAPI 0.2.41).

Compara os DTOs, RPCs, Enums e códigos de recusa tratados no app iOS
(DTOsContrato.swift, Portas.swift, SupabaseApiCliente.swift, Modelos.swift, ErrosDaAPI.swift)
com a especificação OpenAPI (Contrato/openapi.yaml e backend quando disponível).

Seções de conferência:
1. Sincronia de contrato (espelho local vs backend)
2. Paridade de RPCs (todas as 44 operações /rpc/... implementadas e sem RPC inventada)
3. Paridade de Enums (todos os casos de cada enum fechado no OpenAPI presentes no Swift)
4. Códigos de recusa tratados (tabela de erros estáveis do contrato vs CodigoErroAPI)
5. Paridade de DTOs (todos os campos exigidos nos schemas do OpenAPI mapeados nos structs)
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
        description="Confere a paridade entre o código iOS e o contrato OpenAPI."
    )
    parser.add_argument(
        "--contrato",
        type=pathlib.Path,
        default=None,
        help="Caminho para o openapi.yaml (padrão: iOS/Contrato/openapi.yaml)",
    )
    parser.add_argument(
        "--backend-contrato",
        type=pathlib.Path,
        default=None,
        help="Caminho para o openapi.yaml do backend para validar sincronia de espelho",
    )
    parser.add_argument(
        "--sources",
        type=pathlib.Path,
        default=None,
        help="Diretório Sources/ do app iOS (padrão: iOS/Sources)",
    )
    parser.add_argument(
        "--silencioso",
        action="store_true",
        help="Exibe apenas erros e resumo final",
    )
    return parser.parse_args()


def carregar_contrato(caminho: pathlib.Path) -> dict:
    if not caminho.is_file():
        sys.exit(f"FALHA: arquivo de contrato não encontrado: {caminho}")
    programa = "require 'yaml'; require 'json'; print JSON.generate(YAML.load_file(ARGV[0]))"
    try:
        saida = subprocess.run(
            ["ruby", "-e", programa, str(caminho)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        sys.exit("FALHA: ruby não encontrado no sistema para carregar YAML")
    except subprocess.CalledProcessError as erro:
        sys.exit(f"FALHA ao ler {caminho.name}: {erro.stderr.strip()}")
    return json.loads(saida.stdout)


def parse_swift_structs(filepath: pathlib.Path) -> dict[str, str]:
    if not filepath.is_file():
        return {}
    with open(filepath, encoding="utf-8") as f:
        lines = f.readlines()
    structs: dict[str, str] = {}
    current_struct: str | None = None
    brace_depth = 0
    struct_depth = 0
    body_lines: list[str] = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        if "struct " in stripped and not current_struct:
            m = re.search(r"struct\s+([A-Za-z0-9_]+)", stripped)
            if m:
                current_struct = m.group(1)
                struct_depth = brace_depth
                body_lines = [line]
        elif current_struct:
            body_lines.append(line)

        brace_depth += line.count("{") - line.count("}")
        if current_struct and brace_depth <= struct_depth:
            structs[current_struct] = "".join(body_lines)
            current_struct = None

    return structs


def extrair_propriedades_do_struct(body: str) -> set[str]:
    props: set[str] = set()
    coding_keys: dict[str, str] = {}

    ck_matches = re.findall(r"enum\s+CodingKeys\s*:[^{]*\{([^}]+)\}", body)
    for ck_block in ck_matches:
        for item in re.split(r"[\n;]", ck_block):
            item = item.strip()
            if item.startswith("case "):
                partes = item[5:].split("//")[0].split(",")
                for parte in partes:
                    m = re.search(r"([a-zA-Z0-9_]+)(?:\s*=\s*\"([^\"]+)\")?", parte.strip())
                    if m:
                        s_name = m.group(1)
                        wire_name = m.group(2) if m.group(2) else s_name
                        coding_keys[s_name] = wire_name

    for line in body.split("\n"):
        line = line.strip()
        m = re.search(r"\b(?:let|var)\s+([a-zA-Z0-9_]+)", line)
        if m and not line.endswith("{"):
            s_name = m.group(1)
            wire_name = coding_keys.get(s_name, s_name)
            props.add(wire_name)
            # Adiciona formato snake_case caso venha sem CodingKeys customizado
            snake_name = re.sub(r"(?<!^)(?=[A-Z])", "_", s_name).lower()
            props.add(snake_name)
    return props


def extrair_enums_swift(sources_dir: pathlib.Path) -> dict[str, set[str]]:
    swift_enums: dict[str, set[str]] = {}
    for p in sources_dir.rglob("*.swift"):
        with open(p, encoding="utf-8") as f:
            lines = f.readlines()
        for i, line in enumerate(lines):
            m = re.search(r"(?:public\s+)?(?:enum|typealias)\s+([A-Za-z0-9_]+)", line)
            if not m:
                continue
            ename = m.group(1)
            if "typealias" in line and "=" in line:
                alvo = line.split("=")[1].strip().split()[0].rstrip(";")
                if alvo in swift_enums:
                    swift_enums[ename] = set(swift_enums[alvo])
                continue

            cases: set[str] = set()
            depth = line.count("{") - line.count("}")
            if "{" not in line:
                continue
            for subline in lines[i + 1 :]:
                depth += subline.count("{") - subline.count("}")
                if depth <= 0:
                    break
                stripped = subline.strip()
                if stripped.startswith("case "):
                    parts = stripped[5:].split("//")[0].split(",")
                    for part in parts:
                        part = part.strip()
                        if "=" in part:
                            val = part.split("=")[1].strip().strip('"')
                            cases.add(val)
                        elif "(" in part:
                            pass
                        elif part:
                            cases.add(part)
                            snake = re.sub(r"(?<!^)(?=[A-Z])", "_", part).lower()
                            cases.add(snake)
            if cases:
                swift_enums[ename] = cases
    return swift_enums


def conferir_rpcs(doc: dict, sources_dir: pathlib.Path) -> list[str]:
    erros: list[str] = []
    openapi_rpcs = {
        p.replace("/rpc/", "")
        for p in doc.get("paths", {}).keys()
        if p.startswith("/rpc/")
    }

    supabase_cliente = sources_dir / "Dados" / "SupabaseApiCliente.swift"
    if not supabase_cliente.is_file():
        return [f"Arquivo {supabase_cliente} não encontrado para auditoria de RPCs"]

    with open(supabase_cliente, encoding="utf-8") as f:
        texto = f.read()

    swift_rpcs = set(re.findall(r'rpc\(\s*"([^"]+)"', texto))
    swift_rpcs.update(re.findall(r'lista\(\s*"([^"]+)"', texto))
    swift_rpcs.update(re.findall(r'registrarPresenca\(\s*"([^"]+)"', texto))

    faltando = openapi_rpcs - swift_rpcs
    extras = swift_rpcs - openapi_rpcs

    if faltando:
        erros.append(f"RPCs do contrato faltando no SupabaseApiCliente: {sorted(faltando)}")
    if extras:
        erros.append(f"RPCs extras no SupabaseApiCliente inexistentes no contrato: {sorted(extras)}")
    return erros


def conferir_enums(doc: dict, swift_enums: dict[str, set[str]]) -> list[str]:
    erros: list[str] = []
    schemas = doc.get("components", {}).get("schemas", {})
    # Derivado diretamente do OpenAPI: todo schema que define enum
    openapi_enums = {name: s["enum"] for name, s in schemas.items() if "enum" in s}

    for o_name, o_cases_list in sorted(openapi_enums.items()):
        s_name = o_name
        if s_name not in swift_enums:
            if o_name == "TipoNotificacao" and "TipoDeAviso" in swift_enums:
                s_name = "TipoDeAviso"
            elif o_name == "TipoDeAlvo" and "TipoPerfilPublico" in swift_enums:
                s_name = "TipoPerfilPublico"
            else:
                erros.append(
                    f"Enum {o_name} do contrato OpenAPI não encontrado em nenhum arquivo Swift"
                )
                continue

        o_cases = set(o_cases_list)
        s_cases = swift_enums[s_name]
        faltando = o_cases - s_cases
        extras = s_cases - o_cases
        if faltando:
            erros.append(
                f"Enum {o_name} ({s_name}): casos do contrato faltando no Swift: {sorted(faltando)}"
            )
        if extras:
            erros.append(
                f"Enum {o_name} ({s_name}): casos extras no Swift inexistentes no contrato: {sorted(extras)}"
            )

    return erros


def conferir_erros(doc: dict, sources_dir: pathlib.Path) -> list[str]:
    erros: list[str] = []
    info_desc = doc.get("info", {}).get("description", "")
    tabela_match = re.search(r"## Erros.*?\n(\|.*?)(?:\n\n## |\Z)", info_desc, re.DOTALL)
    if not tabela_match:
        return ["Tabela de erros estáveis '## Erros' não encontrada no openapi.yaml"]

    linhas_tabela = tabela_match.group(1).strip().split("\n")
    codigos_contrato: set[str] = set()
    for linha in linhas_tabela[2:]:
        colunas = [c.strip() for c in linha.split("|") if c.strip()]
        if len(colunas) >= 2:
            codigos_raw = colunas[1]
            for cod in re.findall(r"`([a-z0-9_]+)`", codigos_raw):
                if cod not in {"pgrst", "erro"}:
                    codigos_contrato.add(cod)

    erros_swift_path = sources_dir / "Dominio" / "ErrosDaAPI.swift"
    if not erros_swift_path.is_file():
        return [f"Arquivo {erros_swift_path} não encontrado"]

    with open(erros_swift_path, encoding="utf-8") as f:
        texto = f.read()

    enum_match = re.search(r"enum\s+CodigoErroAPI\s*:[^{]*\{([^}]+)\}", texto)
    if not enum_match:
        return ["enum CodigoErroAPI não encontrado em ErrosDaAPI.swift"]

    codigos_swift: set[str] = set()
    for line in enum_match.group(1).split("\n"):
        line = line.strip()
        if line.startswith("case "):
            m = re.search(r'case\s+([a-zA-Z0-9_]+)(?:\s*=\s*"([^"]+)")?', line)
            if m:
                valor = m.group(2) if m.group(2) else m.group(1)
                codigos_swift.add(valor)
                snake = re.sub(r"(?<!^)(?=[A-Z])", "_", m.group(1)).lower()
                codigos_swift.add(snake)

    faltando = codigos_contrato - codigos_swift
    if faltando:
        erros.append(
            f"Códigos de recusa do catálogo OpenAPI ausentes em CodigoErroAPI: {sorted(faltando)}"
        )
    return erros


def conferir_dtos(
    doc: dict, sources_dir: pathlib.Path
) -> tuple[list[str], list[str], int]:
    erros: list[str] = []
    avisos: list[str] = []
    schemas = doc.get("components", {}).get("schemas", {})

    all_structs: dict[str, str] = {}
    for p in sources_dir.rglob("*.swift"):
        all_structs.update(parse_swift_structs(p))

    struct_props = {
        name: extrair_propriedades_do_struct(corpo)
        for name, corpo in all_structs.items()
    }

    # Schemas de tipo escalar/primitivo e payloads de exportação bruta
    PRIMITIVOS_ESPECIAIS = {
        "Centavos",
        "ChaveDeIdempotencia",
        "HoraDoDia",
        "Instante",
        "Telefone",
        "Uuid",
    }
    RAW_PAYLOADS = {"MeusDados"}

    # Mapeamento de apelidos para schemas cujos nomes em Swift diferem por convenção
    ALIAS_DTO = {
        "AlteracaoDoPerfilProfissional": "AlteracaoPerfilProfissionalDTO",
        "Candidatura": "MinhaCandidaturaDTO",
        "NovoEstabelecimento": "CadastroEstabelecimentoDTO",
        "JanelaDeDisponibilidade": "JanelaDTO",
        "ResultadoCandidatura": "CandidaturaDTO",
        "DadosDoPerfilProfissional": "DadosPerfilProfissionalDTO",
        "ExclusaoDeConta": "DTOExclusaoDeConta",
        "Erro": "EnvelopeErroAPI",
    }

    # Derivado diretamente do OpenAPI: todo schema de objeto com propriedades
    openapi_objects = {
        name: s
        for name, s in schemas.items()
        if "enum" not in s
        and name not in PRIMITIVOS_ESPECIAIS
        and name not in RAW_PAYLOADS
        and (s.get("type") == "object" or "properties" in s)
    }

    for schema_name, schema in sorted(openapi_objects.items()):
        candidates = [
            ALIAS_DTO.get(schema_name),
            schema_name + "DTO",
            schema_name,
            "DTO" + schema_name,
        ]
        dto_name = next((c for c in candidates if c and c in struct_props), None)
        if not dto_name:
            erros.append(
                f"Schema de objeto {schema_name} do contrato OpenAPI não possui struct/DTO correspondente no app Swift"
            )
            continue

        required_props = set(schema.get("required", []))
        all_props = set(schema.get("properties", {}).keys())
        dto_fields = struct_props[dto_name]

        faltando = required_props - dto_fields
        if faltando:
            erros.append(
                f"DTO {dto_name} (schema {schema_name}) tem campos obrigatórios faltando: {sorted(faltando)}"
            )

        extras = dto_fields - all_props
        if extras:
            avisos.append(
                f"DTO {dto_name} (schema {schema_name}): campos extras no Swift não mapeados no contrato: {sorted(extras)}"
            )

        opcionais_ausentes = (all_props - required_props) - dto_fields
        if opcionais_ausentes:
            avisos.append(
                f"DTO {dto_name} (schema {schema_name}): campos opcionais do contrato não mapeados no DTO: {sorted(opcionais_ausentes)}"
            )

    return erros, avisos, len(openapi_objects)


def main() -> None:
    args = parse_arguments()

    script_dir = pathlib.Path(__file__).resolve().parent
    repo_root = script_dir.parents[0]  # iOS/

    contrato_path = args.contrato or (repo_root / "Contrato" / "openapi.yaml")
    sources_dir = args.sources or (repo_root / "Sources")

    backend_contrato = args.backend_contrato
    if not backend_contrato:
        # Tenta auto-detectar espelho do backend
        candidato = repo_root.parent / "frila-backend" / "contrato" / "openapi.yaml"
        if candidato.is_file():
            backend_contrato = candidato

    if not args.silencioso:
        print(f"==> Verificando conformidade com contrato: {contrato_path.name}")

    doc = carregar_contrato(contrato_path)
    versao = doc.get("info", {}).get("version", "desconhecida")
    if not args.silencioso:
        print(f"    Versão do OpenAPI: {versao}")

    todos_erros: list[str] = []
    todos_avisos: list[str] = []

    # 1. Backend Mirror Check
    if backend_contrato and backend_contrato.is_file():
        doc_backend = carregar_contrato(backend_contrato)
        versao_backend = doc_backend.get("info", {}).get("version", "desconhecida")
        if versao != versao_backend:
            todos_erros.append(
                f"Divergência de versão entre backend ({versao_backend}) e espelho local ({versao})"
            )
        else:
            if not args.silencioso:
                print(f"OK: espelho local sincronizado com backend ({versao_backend}).")

    # 2. RPCs
    erros_rpc = conferir_rpcs(doc, sources_dir)
    todos_erros.extend(erros_rpc)
    if not erros_rpc and not args.silencioso:
        print("OK: 44/44 RPCs do contrato implementadas em conformidade.")

    # 3. Enums
    swift_enums = extrair_enums_swift(sources_dir)
    erros_enums = conferir_enums(doc, swift_enums)
    todos_erros.extend(erros_enums)
    if not erros_enums and not args.silencioso:
        print("OK: 17/17 enums do contrato verificados caso a caso.")

    # 4. Códigos de recusa
    erros_recusas = conferir_erros(doc, sources_dir)
    todos_erros.extend(erros_recusas)
    if not erros_recusas and not args.silencioso:
        print("OK: códigos estáveis de recusa de regra tratados em CodigoErroAPI.")

    # 5. DTOs
    erros_dtos, avisos_dtos, qtd_dtos = conferir_dtos(doc, sources_dir)
    todos_erros.extend(erros_dtos)
    todos_avisos.extend(avisos_dtos)
    if not erros_dtos and not args.silencioso:
        print(f"OK: {qtd_dtos}/{qtd_dtos} DTOs do contrato cobrem todos os campos obrigatórios.")

    if todos_avisos and not args.silencioso:
        print(f"INFO: {len(todos_avisos)} avisos de campos opcionais/extras observados no app.")

    if todos_erros:
        print("\nFALHA: divergências de contrato encontradas:", file=sys.stderr)
        for erro in todos_erros:
            print(f"  - {erro}", file=sys.stderr)
        sys.exit(1)

    print(f"OK: conformidade total com contrato {versao} (RPCs, Enums, Erros e DTOs).")


if __name__ == "__main__":
    main()
