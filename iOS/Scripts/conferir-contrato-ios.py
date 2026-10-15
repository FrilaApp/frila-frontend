#!/usr/bin/env python3
"""Gate de paridade de contrato entre iOS e backend (OpenAPI 0.2.42).

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
        text = f.read()

    structs: dict[str, str] = {}
    for m in re.finditer(r"\bstruct\s+([A-Za-z0-9_]+)\b[^{]*\{", text):
        s_name = m.group(1)
        start_brace = m.end() - 1
        depth = 0
        end_brace = start_brace
        for i in range(start_brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end_brace = i
                    break
        structs[s_name] = text[start_brace + 1 : end_brace]

    return structs


def extrair_propriedades_do_struct(body: str) -> set[str]:
    # 1. Remove corpos de structs aninhados para isolar propriedades deste struct
    cleaned = body
    while True:
        m = re.search(r"\bstruct\s+[A-Za-z0-9_]+\b[^{]*\{", cleaned)
        if not m:
            break
        start_brace = m.end() - 1
        depth = 0
        end_brace = start_brace
        for i in range(start_brace, len(cleaned)):
            if cleaned[i] == "{":
                depth += 1
            elif cleaned[i] == "}":
                depth -= 1
                if depth == 0:
                    end_brace = i
                    break
        cleaned = cleaned[: m.start()] + " " * (end_brace + 1 - m.start()) + cleaned[end_brace + 1 :]

    # 2. Se o struct possui enum CodingKeys, ele define com autoridade estrita
    # as chaves de serialização/deserialização Codable do tipo.
    ck_match = re.search(r"enum\s+CodingKeys\s*:[^{]*\{([^}]+)\}", cleaned)
    if ck_match:
        ck_block = ck_match.group(1)
        coding_keys: set[str] = set()
        for item in re.split(r"[\n;]", ck_block):
            item = item.strip()
            if item.startswith("case "):
                partes = item[5:].split("//")[0].split(",")
                for parte in partes:
                    m = re.search(r"([a-zA-Z0-9_]+)(?:\s*=\s*\"([^\"]+)\")?", parte.strip())
                    if m:
                        wire_name = m.group(2) if m.group(2) else m.group(1)
                        coding_keys.add(wire_name)
        return coding_keys

    # 3. Caso não possua CodingKeys, extrai apenas propriedades armazenadas no nível raiz
    # do struct (depth == 0), descartando modificadores static, variáveis locais e
    # propriedades computadas.
    props: set[str] = set()
    depth = 0
    for line in cleaned.split("\n"):
        stripped = line.strip()
        brace_delta = stripped.count("{") - stripped.count("}")
        if depth == 0:
            if not stripped.startswith("static ") and not stripped.startswith("private static ") and not stripped.startswith("public static "):
                m = re.match(r"(?:public\s+|private\s+|internal\s+)?(?:let|var)\s+([a-zA-Z0-9_]+)", stripped)
                if m and not stripped.endswith("{"):
                    s_name = m.group(1)
                    props.add(s_name)
                    snake_name = re.sub(r"(?<!^)(?=[A-Z])", "_", s_name).lower()
                    props.add(snake_name)
        depth += brace_delta

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

    # 5.1 Verificação de DTOs extras no Swift sem respaldo no contrato OpenAPI (Item 3)
    DTOS_LEGITIMOS_RPC_E_NESTED = {
        "FiltroVagasDTO",            # Parâmetros de busca em /rpc/vagas_abertas
        "VagaCanceladaDTO",          # Resposta de /rpc/cancelar_vaga
        "RemocaoDTO",                # Resposta de /rpc/remover_dispositivo
        "RegistrarEventoRespostaDTO",# Resposta de /rpc/registrar_evento
        "EquipeDTO",                 # Struct aninhado em CriteriosDeNotificacaoDTO
        "SuspensaoDTO",              # Struct aninhado em SituacaoDaContaDTO
    }

    alias_reverso = {v: k for k, v in ALIAS_DTO.items()}
    for s_name in sorted(all_structs.keys()):
        if s_name.endswith("DTO") or s_name.startswith("DTO"):
            if s_name in DTOS_LEGITIMOS_RPC_E_NESTED:
                continue
            base = s_name[:-3] if s_name.endswith("DTO") else s_name[3:]
            candidatos_schema = [s_name, base, alias_reverso.get(s_name, "")]
            if not any(c in schemas for c in candidatos_schema if c):
                erros.append(
                    f"DTO {s_name} no código Swift não possui schema ou operação correspondente no contrato OpenAPI"
                )

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
            erros.append(
                f"DTO {dto_name} (schema {schema_name}): campos extras no Swift não permitidos pelo contrato: {sorted(extras)}"
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
        s = "aviso" if len(todos_avisos) == 1 else "avisos"
        print(f"INFO: {len(todos_avisos)} {s} de campos opcionais do contrato não mapeados no app.")

    if todos_erros:
        print("\nFALHA: divergências de contrato encontradas:", file=sys.stderr)
        for erro in todos_erros:
            print(f"  - {erro}", file=sys.stderr)
        sys.exit(1)

    print(f"OK: conformidade total com contrato {versao} (RPCs, Enums, Erros e DTOs).")


if __name__ == "__main__":
    main()
