#!/usr/bin/env python3
"""Mostra somente metadados de assinatura; nunca publica o app nem o perfil inteiro."""
import hashlib
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unicodedata


def executar(*args):
    resultado = subprocess.run(args, capture_output=True)
    return resultado.returncode, resultado.stdout, resultado.stderr


for raiz in map(pathlib.Path, sys.argv[1:]):
    bundles = [raiz, *sorted(raiz.glob("Frameworks/*.framework")),
               *sorted(raiz.glob("PlugIns/*.appex"))]
    for bundle in bundles:
        print(f"\nASSINATURA: {bundle}", flush=True)
        for opcoes in [("-dvv", "-r-"), ("--verify", "--deep", "--strict", "--verbose=4")]:
            codigo, saida, erro = executar("codesign", *opcoes, str(bundle))
            print(f"codesign {' '.join(opcoes)}: status={codigo}")
            print((saida + erro).decode(errors="replace").strip())
        with tempfile.TemporaryDirectory(prefix="frila-certificado-") as pasta:
            prefixo = str(pathlib.Path(pasta) / "certificado-")
            codigo, _, _ = executar("codesign", "-d", f"--extract-certificates={prefixo}", str(bundle))
            folha = pathlib.Path(prefixo + "0")
            if codigo == 0 and folha.exists():
                print(f"SHA256 certificado folha: {hashlib.sha256(folha.read_bytes()).hexdigest()}")
                _, saida, _ = executar("openssl", "x509", "-inform", "DER", "-in", str(folha),
                                       "-noout", "-subject", "-issuer", "-dates", "-nameopt",
                                       "sep_multiline,utf8,-esc_msb")
                texto = saida.decode(errors="replace")
                print(texto.strip())
                # Prova a comparação de CN sem alterar ou reassinar nenhum binário.
                sujeito = texto.split("issuer=", 1)[0]
                cn = next((linha.strip()[3:] for linha in sujeito.splitlines()
                           if linha.strip().startswith("CN=")), None)
                if cn:
                    for forma in ("NFC", "NFD"):
                        valor = unicodedata.normalize(forma, cn).encode().hex()
                        requisito = f"certificate leaf[subject.CN] = 0x{valor}"
                        codigo, _, erro = executar("codesign", "--verify", "--strict", "-R",
                                                    requisito, str(bundle))
                        print(f"CN {forma} hex={valor}: status={codigo} {erro.decode(errors='replace').strip()}")
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
