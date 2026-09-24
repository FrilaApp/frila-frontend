#!/usr/bin/env python3
"""Valida cada fixture contra o schema do contrato espelhado em Contrato/openapi.yaml.

O mapa Resources/Fixtures/fixture-schemas.json liga cada arquivo a um JSON Pointer do contrato
(`#/components/schemas/Vaga` ou o corpo de uma operação). A validação cobre o subconjunto do
JSON Schema 2020-12 que o contrato usa — tipos, formatos, enum, const, obrigatórios, limites,
padrões, $ref e oneOf — e recusa campo que o contrato não declara. Palavra-chave desconhecida é
erro, e não aprovação: um validador que ignora o que não entende aprova qualquer coisa.

O YAML é lido pelo Ruby do sistema, porque o Python do macOS não traz parser de YAML.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse
from datetime import date

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRATO = ROOT / "Contrato" / "openapi.yaml"
SOMA = ROOT / "Contrato" / "openapi.yaml.sha256"
FIXTURES = ROOT / "Resources" / "Fixtures"
METADADOS = {"fixture-schemas.json", "contract-version.json"}

ANOTACOES = {"description", "example", "examples", "title", "default", "deprecated", "readOnly",
             "writeOnly", "externalDocs", "$comment", "discriminator", "xml"}
VALIDACOES = {"$ref", "type", "enum", "const", "properties", "required", "additionalProperties",
              "items", "minItems", "maxItems", "uniqueItems", "minLength", "maxLength", "pattern",
              "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "format", "oneOf",
              "anyOf", "allOf", "nullable", "minProperties", "maxProperties"}

UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
INSTANTE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$")
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def carregar_contrato() -> dict:
    programa = "require 'yaml'; require 'json'; print JSON.generate(YAML.load_file(ARGV[0]))"
    try:
        saida = subprocess.run(["ruby", "-e", programa, str(CONTRATO)], check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("ruby não encontrado: é ele que lê o YAML do contrato")
    except subprocess.CalledProcessError as erro:
        sys.exit(f"não consegui ler {CONTRATO.name}: {erro.stderr.strip()}")
    return json.loads(saida.stdout)


def resolver(contrato: dict, ponteiro: str):
    if not ponteiro.startswith("#/"):
        raise ValueError(f"ponteiro fora do contrato: {ponteiro}")
    alvo = contrato
    for parte in ponteiro[2:].split("/"):
        parte = urllib.parse.unquote(parte).replace("~1", "/").replace("~0", "~")
        if not isinstance(alvo, dict) or parte not in alvo:
            raise ValueError(f"ponteiro não existe no contrato: {ponteiro}")
        alvo = alvo[parte]
    return alvo


def tipo_de(valor) -> str:
    if valor is None:
        return "null"
    if isinstance(valor, bool):
        return "boolean"
    if isinstance(valor, int):
        return "integer"
    if isinstance(valor, float):
        return "number"
    if isinstance(valor, str):
        return "string"
    if isinstance(valor, list):
        return "array"
    return "object"


def confere_tipo(valor, esperado: str) -> bool:
    real = tipo_de(valor)
    return real == esperado or (esperado == "number" and real == "integer")


def confere_formato(valor: str, formato: str) -> bool:
    if formato == "uuid":
        return bool(UUID.match(valor))
    if formato == "date-time":
        return bool(INSTANTE.match(valor))
    if formato == "date":
        try:
            return date.fromisoformat(valor).isoformat() == valor
        except ValueError:
            return False
    if formato == "email":
        return bool(EMAIL.match(valor))
    if formato == "uri":
        partes = urllib.parse.urlparse(valor)
        return bool(partes.scheme and partes.netloc)
    raise ValueError(f"formato sem suporte no validador: {formato}")


def validar(contrato: dict, schema: dict, valor, caminho: str) -> list[str]:
    desconhecidas = {chave for chave in schema if chave not in ANOTACOES | VALIDACOES and not chave.startswith("x-")}
    if desconhecidas:
        return [f"{caminho}: palavra-chave sem suporte no validador: {', '.join(sorted(desconhecidas))}"]
    if "$ref" in schema:
        return validar(contrato, resolver(contrato, schema["$ref"]), valor, caminho)
    if valor is None and schema.get("nullable"):
        return []

    erros: list[str] = []
    if "oneOf" in schema:
        aceitos = [opcao for opcao in schema["oneOf"] if not validar(contrato, opcao, valor, caminho)]
        if len(aceitos) != 1:
            erros.append(f"{caminho}: casa com {len(aceitos)} opções de oneOf, e precisa casar com exatamente uma")
    if "anyOf" in schema and not any(not validar(contrato, opcao, valor, caminho) for opcao in schema["anyOf"]):
        erros.append(f"{caminho}: não casa com nenhuma opção de anyOf")
    for parte in schema.get("allOf", []):
        erros += validar(contrato, parte, valor, caminho)

    tipos = schema.get("type")
    if tipos is not None:
        tipos = tipos if isinstance(tipos, list) else [tipos]
        if not any(confere_tipo(valor, tipo) for tipo in tipos):
            return erros + [f"{caminho}: esperava {'|'.join(tipos)}, veio {tipo_de(valor)}"]
    if "const" in schema and valor != schema["const"]:
        erros.append(f"{caminho}: esperava {schema['const']!r}")
    if "enum" in schema and valor not in schema["enum"]:
        erros.append(f"{caminho}: {valor!r} fora de {schema['enum']}")

    if isinstance(valor, str):
        if "format" in schema and not confere_formato(valor, schema["format"]):
            erros.append(f"{caminho}: {valor!r} não é {schema['format']}")
        if "pattern" in schema and not re.search(schema["pattern"], valor):
            erros.append(f"{caminho}: {valor!r} não casa com {schema['pattern']}")
        if len(valor) < schema.get("minLength", 0):
            erros.append(f"{caminho}: menor que {schema['minLength']} caracteres")
        if "maxLength" in schema and len(valor) > schema["maxLength"]:
            erros.append(f"{caminho}: maior que {schema['maxLength']} caracteres")

    if tipo_de(valor) in ("integer", "number"):
        if "minimum" in schema and valor < schema["minimum"]:
            erros.append(f"{caminho}: {valor} abaixo do mínimo {schema['minimum']}")
        if "maximum" in schema and valor > schema["maximum"]:
            erros.append(f"{caminho}: {valor} acima do máximo {schema['maximum']}")
        if "exclusiveMinimum" in schema and valor <= schema["exclusiveMinimum"]:
            erros.append(f"{caminho}: {valor} precisa passar de {schema['exclusiveMinimum']}")
        if "exclusiveMaximum" in schema and valor >= schema["exclusiveMaximum"]:
            erros.append(f"{caminho}: {valor} precisa ficar abaixo de {schema['exclusiveMaximum']}")

    if isinstance(valor, list):
        if len(valor) < schema.get("minItems", 0):
            erros.append(f"{caminho}: menos que {schema['minItems']} itens")
        if "maxItems" in schema and len(valor) > schema["maxItems"]:
            erros.append(f"{caminho}: mais que {schema['maxItems']} itens")
        if schema.get("uniqueItems") and len({json.dumps(item, sort_keys=True) for item in valor}) != len(valor):
            erros.append(f"{caminho}: itens repetidos")
        if "items" in schema:
            for indice, item in enumerate(valor):
                erros += validar(contrato, schema["items"], item, f"{caminho}[{indice}]")

    if isinstance(valor, dict):
        if len(valor) < schema.get("minProperties", 0):
            erros.append(f"{caminho}: precisa de ao menos {schema['minProperties']} campo(s)")
        if "maxProperties" in schema and len(valor) > schema["maxProperties"]:
            erros.append(f"{caminho}: aceita no máximo {schema['maxProperties']} campo(s)")
        propriedades = schema.get("properties", {})
        for chave in schema.get("required", []):
            if chave not in valor:
                erros.append(f"{caminho}: falta {chave}")
        extras = schema.get("additionalProperties", False if propriedades else True)
        for chave, item in valor.items():
            if chave in propriedades:
                erros += validar(contrato, propriedades[chave], item, f"{caminho}.{chave}")
            elif extras is False:
                erros.append(f"{caminho}: {chave} não existe no contrato")
            elif isinstance(extras, dict):
                erros += validar(contrato, extras, item, f"{caminho}.{chave}")
    return erros


def main() -> int:
    falhas: list[str] = []

    soma = hashlib.sha256(CONTRATO.read_bytes()).hexdigest()
    if soma != SOMA.read_text(encoding="utf-8").strip():
        falhas.append("Contrato/openapi.yaml mudou sem atualizar Contrato/openapi.yaml.sha256")

    contrato = carregar_contrato()
    versao = contrato["info"]["version"]
    declarada = json.loads((FIXTURES / "contract-version.json").read_text(encoding="utf-8"))["version"]
    if declarada != versao:
        falhas.append(f"contract-version.json declara {declarada}, e o espelho é {versao}")

    mapa = json.loads((FIXTURES / "fixture-schemas.json").read_text(encoding="utf-8"))
    presentes = {arquivo.name for arquivo in FIXTURES.glob("*.json")} - METADADOS
    for sem_schema in sorted(presentes - mapa.keys()):
        falhas.append(f"{sem_schema}: fixture sem schema em fixture-schemas.json")
    for ausente in sorted(mapa.keys() - presentes):
        falhas.append(f"{ausente}: mapeada em fixture-schemas.json, mas o arquivo não existe")

    for nome in sorted(mapa.keys() & presentes):
        entrada = mapa[nome]
        valor = json.loads((FIXTURES / nome).read_text(encoding="utf-8"))
        schema = resolver(contrato, entrada["schema"])
        if entrada.get("lista"):
            schema = {"type": "array", "items": schema}
        falhas += validar(contrato, schema, valor, nome)

    if falhas:
        print("\n".join(falhas), file=sys.stderr)
        return 1
    print(f"{len(mapa)} fixtures válidas contra o contrato {versao}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
