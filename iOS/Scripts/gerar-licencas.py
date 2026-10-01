#!/usr/bin/env python3
"""Gera Resources/Licencas.json com a licença de cada pacote do Package.resolved.

A tela de licenças (`TelaLicencas`) lê esse arquivo do bundle do FrilaApresentacao, e o
`LicencasTests` falha quando um pacote do Package.resolved fica sem entrada ou em outra revisão.
O arquivo é gerado: não se edita à mão.

O texto vem do arquivo de licença na raiz de cada checkout do SPM, copiado como está. Por isso o
script precisa dos checkouts já baixados, na revisão do Package.resolved:

    xcodebuild -resolvePackageDependencies -project Frila.xcodeproj -scheme Frila-Local \
        -derivedDataPath <pasta>
    Scripts/gerar-licencas.py --checkouts <pasta>/SourcePackages/checkouts

Sem `--checkouts`, usa o DerivedData padrão do Xcode mais recente (`Frila-*`). Pacote sem arquivo
de licença, em outra revisão ou com licença de tipo desconhecido é erro, e não entrada vazia: um
tipo novo precisa ser olhado por uma pessoa antes de entrar no app.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESOLVIDO = ROOT / "Frila.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"
DESTINO = ROOT / "Resources" / "Licencas.json"
DERIVED_DATA_PADRAO = pathlib.Path.home() / "Library" / "Developer" / "Xcode" / "DerivedData"

ARQUIVO_DE_LICENCA = re.compile(r"^(licen[cs]e|copying)(\.(txt|md))?$", re.IGNORECASE)
ARQUIVO_DE_AVISO = re.compile(r"^notice(\.(txt|md))?$", re.IGNORECASE)


def tipo_da_licenca(texto: str) -> str | None:
    """Identificador SPDX da licença, pelo texto. O primeiro trecho que casar decide: o LICENSE do
    GoogleUtilities, por exemplo, é Apache 2.0 seguido do aviso MIT de um código de terceiro."""
    plano = " ".join(texto.split())
    if "Apache License" in plano and "Version 2.0" in plano:
        return "Apache-2.0"
    if "Permission is hereby granted, free of charge" in plano and 'THE SOFTWARE IS PROVIDED "AS IS"' in plano:
        return "MIT"
    if "Redistribution and use in source and binary forms" in plano:
        return "BSD-3-Clause" if "Neither the name" in plano else "BSD-2-Clause"
    if "This software is provided 'as-is'" in plano and "Altered source versions must be plainly marked" in plano:
        return "Zlib"
    return None


def ler_texto(arquivo: pathlib.Path) -> str:
    texto = arquivo.read_text(encoding="utf-8").replace("\r\n", "\n")
    return texto.lstrip("\n").rstrip()


def arquivo_na_raiz(pasta: pathlib.Path, padrao: re.Pattern[str]) -> pathlib.Path | None:
    achados = sorted(item for item in pasta.iterdir() if item.is_file() and padrao.match(item.name))
    # LICENSE antes de COPYING quando o pacote traz os dois.
    achados.sort(key=lambda item: not item.name.lower().startswith("licen"))
    return achados[0] if achados else None


def revisao_do_checkout(pasta: pathlib.Path) -> str | None:
    try:
        saida = subprocess.run(["git", "-C", str(pasta), "rev-parse", "HEAD"], check=True, capture_output=True, text=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None
    return saida.stdout.strip()


def checkouts_padrao() -> pathlib.Path | None:
    candidatos = [pasta for pasta in DERIVED_DATA_PADRAO.glob("Frila-*/SourcePackages/checkouts") if pasta.is_dir()]
    return max(candidatos, key=lambda pasta: pasta.stat().st_mtime, default=None)


def gerar(checkouts: pathlib.Path) -> tuple[list[dict], list[str]]:
    pinos = json.loads(RESOLVIDO.read_text(encoding="utf-8"))["pins"]
    pastas = {pasta.name.lower(): pasta for pasta in checkouts.iterdir() if pasta.is_dir()}
    licencas: list[dict] = []
    falhas: list[str] = []

    for pino in pinos:
        identidade = pino["identity"]
        url = re.sub(r"\.git$", "", pino["location"])
        # O SPM nomeia o checkout pelo último trecho da URL, com as maiúsculas do repositório.
        nome = url.rstrip("/").rsplit("/", 1)[-1]
        estado = pino["state"]
        revisao = estado["revision"]
        pasta = pastas.get(nome.lower())
        if pasta is None:
            falhas.append(f"{identidade}: checkout não encontrado em {checkouts}")
            continue
        if revisao_do_checkout(pasta) != revisao:
            falhas.append(f"{identidade}: o checkout não está na revisão do Package.resolved; resolva os pacotes de novo")
            continue
        arquivo = arquivo_na_raiz(pasta, ARQUIVO_DE_LICENCA)
        if arquivo is None:
            falhas.append(f"{identidade}: nenhum arquivo de licença na raiz do pacote")
            continue
        texto = ler_texto(arquivo)
        tipo = tipo_da_licenca(texto)
        if tipo is None:
            falhas.append(f"{identidade}: tipo de licença não reconhecido em {arquivo.name}; confira e acrescente em tipo_da_licenca")
            continue

        entrada = {
            "id": identidade,
            "nome": nome,
            "versao": estado.get("version") or estado.get("branch") or revisao[:7],
            "revisao": revisao,
            "url": url,
            "tipo": tipo,
            "texto": texto,
        }
        aviso = arquivo_na_raiz(pasta, ARQUIVO_DE_AVISO)
        if aviso is not None:
            entrada["aviso"] = ler_texto(aviso)
        licencas.append(entrada)

    licencas.sort(key=lambda entrada: entrada["nome"].casefold())
    return licencas, falhas


def main() -> int:
    argumentos = argparse.ArgumentParser(description="Gera Resources/Licencas.json a partir dos checkouts do SPM.")
    argumentos.add_argument("--checkouts", type=pathlib.Path, help="pasta SourcePackages/checkouts de um DerivedData já resolvido")
    checkouts = argumentos.parse_args().checkouts or checkouts_padrao()
    if checkouts is None or not checkouts.is_dir():
        print("checkouts do SPM não encontrados: resolva os pacotes e passe --checkouts <DerivedData>/SourcePackages/checkouts",
              file=sys.stderr)
        return 1

    licencas, falhas = gerar(checkouts)
    if falhas:
        print("\n".join(falhas), file=sys.stderr)
        return 1

    DESTINO.write_text(json.dumps(licencas, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tipos = sorted({entrada["tipo"] for entrada in licencas})
    print(f"{len(licencas)} licenças em {DESTINO.relative_to(ROOT)} ({', '.join(tipos)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
