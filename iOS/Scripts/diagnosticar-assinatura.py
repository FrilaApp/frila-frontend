#!/usr/bin/env python3
"""Mostra somente metadados de assinatura; nunca publica o app nem o perfil inteiro."""
import argparse
import datetime
import hashlib
import pathlib
import plistlib
import re
import subprocess
import sys
import tempfile
import unicodedata


def executar(*args):
    resultado = subprocess.run(args, capture_output=True)
    return resultado.returncode, resultado.stdout, resultado.stderr


def conferir_perfil(dados, certificado, equipe, identificador):
    """Confere o vínculo certificado/perfil; não imprime o conteúdo do perfil."""
    erros = []
    certificados = [hashlib.sha256(c).hexdigest() for c in dados.get("DeveloperCertificates", [])]
    ent = dados.get("Entitlements", {})
    if certificado not in certificados:
        erros.append("perfil não contém o certificado local importado")
    if equipe not in dados.get("TeamIdentifier", []):
        erros.append("perfil pertence a outra equipe")
    if ent.get("application-identifier") != f"{equipe}.{identificador}":
        erros.append("perfil não corresponde ao identificador do bundle")
    if ent.get("get-task-allow") is not False:
        erros.append("perfil permite depuração ou não declara get-task-allow=false")
    if ent.get("aps-environment") not in (None, "production"):
        erros.append("perfil usa ambiente de push diferente de production")
    validade = dados.get("ExpirationDate")
    if not isinstance(validade, datetime.datetime) or validade.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        erros.append("perfil ausente de validade ou expirado")
    return erros


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--certificado-esperado")
    parser.add_argument("--equipe")
    parser.add_argument("apps", nargs="+")
    opcoes = parser.parse_args()
    if opcoes.certificado_esperado:
        if not re.fullmatch(r"[a-f0-9]{64}", opcoes.certificado_esperado) or not re.fullmatch(r"[A-Z0-9]{10}", opcoes.equipe or ""):
            parser.error("certificado SHA256 e equipe são obrigatórios e devem ser válidos")
    falhas = 0
    for raiz in map(pathlib.Path, opcoes.apps):
        if not raiz.exists():
            sys.exit(f"error: código assinado não encontrado: {raiz}")
        bundles = [raiz, *sorted(raiz.glob("Frameworks/*.framework")),
                   *sorted(raiz.glob("PlugIns/*.appex"))]
        for bundle in bundles:
            print(f"\nASSINATURA: {bundle}", flush=True)
            for verificacao in [("-dvv", "-r-"), ("--verify", "--deep", "--strict", "--verbose=4")]:
                codigo, saida, erro = executar("codesign", *verificacao, str(bundle))
                print(f"codesign {' '.join(verificacao)}: status={codigo}")
                if codigo != 0:
                    falhas += 1
                print((saida + erro).decode(errors="replace").strip())
            sha256 = None
            with tempfile.TemporaryDirectory(prefix="frila-certificado-") as pasta:
                prefixo = str(pathlib.Path(pasta) / "certificado-")
                codigo, _, _ = executar("codesign", "-d", f"--extract-certificates={prefixo}", str(bundle))
                folha = pathlib.Path(prefixo + "0")
                if codigo == 0 and folha.exists():
                    sha256 = hashlib.sha256(folha.read_bytes()).hexdigest()
                    print(f"SHA256 certificado folha: {sha256}")
                    if opcoes.certificado_esperado and sha256 != opcoes.certificado_esperado:
                        print("error: certificado folha diferente da identidade local importada")
                        falhas += 1
                    _, saida, _ = executar("openssl", "x509", "-inform", "DER", "-in", str(folha),
                                           "-noout", "-subject", "-issuer", "-dates", "-nameopt",
                                           "sep_multiline,utf8,-esc_msb")
                    texto = saida.decode(errors="replace")
                    print(texto.strip())
                    # Prova a comparação de CN sem alterar ou reassinar nenhum binário.
                    sujeito = texto.split("issuer=", 1)[0]
                    cn = next((linha.strip()[3:] for linha in sujeito.splitlines()
                               if linha.strip().startswith("CN=")), None)
                    if cn and not cn.isascii():
                        for forma in ("NFC", "NFD"):
                            valor = unicodedata.normalize(forma, cn).encode().hex()
                            requisito = f"=certificate leaf[subject.CN] = 0x{valor}"
                            codigo, _, erro = executar("codesign", "--verify", "--strict", "-R",
                                                        requisito, str(bundle))
                            print(f"Comparação do CN em {forma}: status={codigo} {erro.decode(errors='replace').strip()}")
                if opcoes.certificado_esperado and sha256 is None:
                    print("error: certificado folha ausente")
                    falhas += 1
                perfil = bundle / "embedded.mobileprovision"
                if perfil.exists():
                    codigo, saida, _ = executar("security", "cms", "-D", "-i", str(perfil))
                    if codigo == 0:
                        dados = plistlib.loads(saida)
                        ent = dados.get("Entitlements", {})
                        print(f"Perfil equipe={dados.get('TeamIdentifier')} expira={dados.get('ExpirationDate')} "
                              f"app={ent.get('application-identifier')} get-task-allow={ent.get('get-task-allow')} "
                              f"aps={ent.get('aps-environment')}")
                        certificados = [hashlib.sha256(c).hexdigest() for c in dados.get("DeveloperCertificates", [])]
                        print(f"SHA256 certificados do perfil: {certificados}")
                        if opcoes.certificado_esperado:
                            identificador = plistlib.loads((bundle / "Info.plist").read_bytes())["CFBundleIdentifier"]
                            erros = conferir_perfil(dados, opcoes.certificado_esperado, opcoes.equipe, identificador)
                            for erro in erros:
                                print(f"error: {erro}")
                            falhas += len(erros)
                    else:
                        print("error: não foi possível decodificar o perfil")
                        falhas += 1
                elif opcoes.certificado_esperado and bundle.suffix in (".app", ".appex"):
                    print("error: perfil de distribuição ausente")
                    falhas += 1

    if falhas:
        sys.exit("error: assinatura inválida; envio ao TestFlight interrompido")


if __name__ == "__main__":
    main()
