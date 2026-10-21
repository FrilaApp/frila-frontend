#!/usr/bin/env python3
"""Importa a identidade em keychain descartável; credenciais só vêm do ambiente da CI."""
import base64
import hashlib
import json
import os
import pathlib
import re
import secrets
import shlex
import shutil
import ssl
import subprocess
import sys
import tempfile


def executar(etapa, *args):
    resultado = subprocess.run(args, capture_output=True)
    if resultado.returncode:
        raise RuntimeError(f"{etapa} falhou; confira certificado, senha, validade e permissões")
    return resultado.stdout.decode()


def mascarar(valor):
    valor = valor.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::add-mask::{valor}", flush=True)


def apagar(pasta):
    if pasta.parent != pathlib.Path(os.environ["RUNNER_TEMP"]).resolve() or not pasta.name.startswith("frila-assinatura-"):
        raise RuntimeError("pasta de assinatura fora do temporário permitido")
    if not pasta.exists():
        return
    estado = pasta / "keychains-anteriores.json"
    falhas = []
    if estado.exists():
        try:
            executar("restaurar keychains", "security", "list-keychains", "-d", "user", "-s",
                     *json.loads(estado.read_text()))
        except RuntimeError as erro:
            falhas.append(str(erro))
    keychain = pasta / "distribuicao.keychain-db"
    if keychain.exists():
        try:
            executar("apagar keychain", "security", "delete-keychain", str(keychain))
        except RuntimeError as erro:
            falhas.append(str(erro))
    # Se security falhar, mantém o estado para uma nova tentativa de limpeza.
    if falhas:
        raise RuntimeError("; ".join(falhas))
    shutil.rmtree(pasta)


def importar():
    nomes = ("APPLE_DISTRIBUTION_CERT_P12_BASE64", "APPLE_DISTRIBUTION_CERT_P12_PASSWORD")
    if any(not os.environ.get(nome) for nome in nomes):
        raise RuntimeError("faltam APPLE_DISTRIBUTION_CERT_P12_BASE64 ou APPLE_DISTRIBUTION_CERT_P12_PASSWORD")
    for nome in nomes:
        mascarar(os.environ[nome])
    try:
        p12 = base64.b64decode("".join(os.environ[nomes[0]].split()), validate=True)
    except ValueError:
        raise RuntimeError("APPLE_DISTRIBUTION_CERT_P12_BASE64 não é base64 válido") from None
    equipe = os.environ["FRILA_EQUIPE"]
    if not re.fullmatch(r"[A-Z0-9]{10}", equipe):
        raise RuntimeError("FRILA_EQUIPE inválida")
    os.umask(0o077)
    pasta = pathlib.Path(tempfile.mkdtemp(prefix="frila-assinatura-", dir=os.environ["RUNNER_TEMP"])).resolve()
    keychain = pasta / "distribuicao.keychain-db"
    try:
        # Registra a limpeza antes de alterar os keychains, inclusive em falha/cancelamento.
        with open(os.environ["GITHUB_ENV"], "a") as ambiente:
            ambiente.write(f"FRILA_KEYCHAIN_PATH={keychain}\n")
        anteriores = shlex.split(executar("listar keychains", "security", "list-keychains", "-d", "user"))
        (pasta / "keychains-anteriores.json").write_text(json.dumps(anteriores))
        senha_keychain = secrets.token_hex(32)
        mascarar(senha_keychain)
        executar("criar keychain", "security", "create-keychain", "-p", senha_keychain, str(keychain))
        executar("configurar keychain", "security", "set-keychain-settings", "-lut", "21600", str(keychain))
        executar("desbloquear keychain", "security", "unlock-keychain", "-p", senha_keychain, str(keychain))
        arquivo = pasta / "certificado.p12"
        arquivo.write_bytes(p12)
        try:
            executar("importar p12", "security", "import", str(arquivo), "-P", os.environ[nomes[1]],
                     "-t", "cert", "-f", "pkcs12", "-k", str(keychain), "-T", "/usr/bin/codesign")
        finally:
            arquivo.unlink(missing_ok=True)
        executar("autorizar codesign", "security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
                 "-s", "-k", senha_keychain, str(keychain))
        executar("incluir keychain", "security", "list-keychains", "-d", "user", "-s", str(keychain), *anteriores)
        identidades = executar("conferir identidade", "security", "find-identity", "-v", "-p", "codesigning", str(keychain))
        pares = re.findall(r'\d+\) ([A-Fa-f0-9]{40}) "([^"]+)"', identidades)
        if len(pares) != 1 or not pares[0][1].startswith("Apple Distribution:") or not pares[0][1].endswith(f"({equipe})"):
            raise RuntimeError("o p12 deve conter uma única identidade Apple Distribution válida da equipe do projeto")
        identidade = pares[0][0].upper()
        certificados = executar("ler certificado público", "security", "find-certificate", "-a", "-p", str(keychain))
        ders = [ssl.PEM_cert_to_DER_cert(c) for c in re.findall(
            r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", certificados, re.S)]
        der = next((c for c in ders if hashlib.sha1(c).hexdigest().upper() == identidade), None)
        if der is None:
            raise RuntimeError("certificado público da identidade não encontrado")
        # Confere acesso à chave privada e requisito Unicode antes de compilar o app.
        fonte = pasta / "prova.c"
        binario = pasta / "prova"
        fonte.write_text("int main(void) { return 0; }\n")
        executar("compilar prova local", "xcrun", "clang", str(fonte), "-o", str(binario))
        executar("assinar prova local", "codesign", "--force", "--sign", identidade,
                 "--keychain", str(keychain), str(binario))
        requisito = f'=anchor apple generic and certificate leaf[subject.OU] = "{equipe}" and certificate leaf[field.1.2.840.113635.100.6.1.4]'
        executar("verificar prova local", "codesign", "--verify", "--strict", "-R", requisito, str(binario))
        # -R verifica o requisito passado; a verificação abaixo confere também o requisito designado.
        executar("verificar requisito designado", "codesign", "--verify", "--strict", str(binario))
        sha256 = hashlib.sha256(der).hexdigest()
        with open(os.environ["GITHUB_ENV"], "a") as ambiente:
            ambiente.write(f"FRILA_CERTIFICADO_DISTRIBUICAO_SHA256={sha256}\n")
        print(f"Identidade Apple Distribution da equipe {equipe} pronta; prova de assinatura estrita aprovada. SHA256={sha256}")
    except Exception:
        apagar(pasta)
        raise


def main():
    # Este processo nunca imprime argv nem saída de subprocessos que recebem credenciais.
    try:
        if sys.argv[1:] == ["importar"]:
            importar()
        elif sys.argv[1:] == ["apagar"]:
            caminho = os.environ.get("FRILA_KEYCHAIN_PATH")
            if caminho:
                apagar(pathlib.Path(caminho).resolve().parent)
        else:
            raise RuntimeError("uso: assinatura-local-ci.py importar|apagar")
    except (RuntimeError, OSError, ValueError, KeyError) as erro:
        # Só RuntimeError tem mensagem controlada; nenhuma exceção imprime segredos/argv.
        print(f"error: {erro if isinstance(erro, RuntimeError) else 'não foi possível configurar ou limpar a assinatura local'}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
