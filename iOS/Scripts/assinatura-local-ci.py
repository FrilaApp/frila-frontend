#!/usr/bin/env python3
"""Importa a identidade e perfis em ambiente descartável; credenciais só vêm do ambiente da CI."""
import base64
import datetime
import hashlib
import json
import os
import pathlib
import plistlib
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


def decodificar_perfil(b64_texto):
    try:
        dados_brutos = base64.b64decode("".join(b64_texto.split()), validate=True)
    except ValueError:
        raise RuntimeError("perfil não é base64 válido") from None
    inicio = dados_brutos.find(b"<?xml")
    fim = dados_brutos.find(b"</plist>")
    if inicio == -1 or fim == -1:
        raise RuntimeError("perfil não contém plist xml válida")
    try:
        plist = plistlib.loads(dados_brutos[inicio:fim + len(b"</plist>")])
    except Exception as e:
        raise RuntimeError(f"falha ao analisar plist do perfil: {e}") from None
    return dados_brutos, plist


def conferir_perfil(dados, cert_sha256, equipe, identificador):
    """Confere o vínculo certificado/perfil; não imprime o conteúdo do perfil."""
    erros = []
    uuid = dados.get("UUID")
    if not uuid or not isinstance(uuid, str):
        erros.append("UUID ausente ou inválido no perfil")
    nome = dados.get("Name")
    if not nome or not isinstance(nome, str):
        erros.append("Name ausente ou inválido no perfil")
    certificados = [hashlib.sha256(c).hexdigest().lower() for c in dados.get("DeveloperCertificates", [])]
    ent = dados.get("Entitlements", {})
    if cert_sha256.lower() not in certificados:
        erros.append("perfil não contém o certificado local importado")
    if equipe not in dados.get("TeamIdentifier", []):
        erros.append("perfil pertence a outra equipe")
    if ent.get("application-identifier") != f"{equipe}.{identificador}":
        erros.append("perfil não corresponde ao identificador do bundle")
    if ent.get("get-task-allow") is not False:
        erros.append("perfil permite depuração ou não declara get-task-allow=false")
    if dados.get("ProvisionedDevices") is not None:
        erros.append("perfil contém ProvisionedDevices (perfil Ad Hoc ou Development; esperado perfil App Store)")
    if dados.get("ProvisionsAllDevices") is True:
        erros.append("perfil corporativo/Enterprise (ProvisionsAllDevices=true; esperado perfil App Store)")
    if ent.get("aps-environment") not in (None, "production"):
        erros.append("perfil usa ambiente de push diferente de production")
    validade = dados.get("ExpirationDate")
    if isinstance(validade, datetime.datetime):
        if validade.tzinfo is None:
            validade = validade.replace(tzinfo=datetime.timezone.utc)
        else:
            validade = validade.astimezone(datetime.timezone.utc)
        if validade <= datetime.datetime.now(datetime.timezone.utc):
            erros.append("perfil ausente de validade ou expirado")
    else:
        erros.append("perfil ausente de validade")
    return erros


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
    perfis_json = pasta / "perfis-instalados.json"
    if perfis_json.exists():
        try:
            caminhos = json.loads(perfis_json.read_text())
        except (json.JSONDecodeError, OSError):
            caminhos = []
        restantes = []
        for caminho in caminhos:
            p = pathlib.Path(caminho)
            if p.exists():
                try:
                    p.unlink()
                except OSError as erro:
                    restantes.append(caminho)
                    falhas.append(f"falha ao remover perfil {caminho}: {erro}")
        try:
            perfis_json.write_text(json.dumps(restantes))
        except OSError:
            pass
    # Se security ou remoção de perfil falhar, mantém o estado para nova tentativa.
    if falhas:
        raise RuntimeError("; ".join(falhas))
    shutil.rmtree(pasta)


def gravar_perfil_atomicamente(destino: pathlib.Path, dados: bytes) -> None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    temp = destino.with_name(f".{destino.name}.tmp")
    try:
        temp.write_bytes(dados)
        os.replace(temp, destino)
    except Exception:
        try:
            temp.unlink(missing_ok=True)
        except OSError:
            pass
        try:
            destino.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def importar_perfis(pasta, cert_sha256, equipe):
    bundle_app = os.environ.get("FRILA_BUNDLE_ID", "com.frila.org.app")
    bundle_notif = os.environ.get("FRILA_NOTIFICATION_SERVICE_BUNDLE_ID", f"{bundle_app}.notificationservice")
    nomes = ("APPLE_PROVISIONING_PROFILE_APP_BASE64", "APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64")

    # Se nenhum perfil base64 foi fornecido:
    if any(not os.environ.get(nome) for nome in nomes):
        if os.environ.get("CI"):
            raise RuntimeError("na CI faltam APPLE_PROVISIONING_PROFILE_APP_BASE64 e APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64 para assinatura manual")
        return None, None

    for nome in nomes:
        mascarar(os.environ[nome])

    dados_app, plist_app = decodificar_perfil(os.environ[nomes[0]])
    erros_app = conferir_perfil(plist_app, cert_sha256, equipe, bundle_app)
    if erros_app:
        raise RuntimeError(f"perfil do app ({bundle_app}) inválido: {'; '.join(erros_app)}")

    dados_notif, plist_notif = decodificar_perfil(os.environ[nomes[1]])
    erros_notif = conferir_perfil(plist_notif, cert_sha256, equipe, bundle_notif)
    if erros_notif:
        raise RuntimeError(f"perfil da extensão ({bundle_notif}) inválido: {'; '.join(erros_notif)}")

    pasta_perfis = pathlib.Path(os.environ.get("FRILA_PROFILES_DIR",
                                              pathlib.Path.home() / "Library" / "MobileDevice" / "Provisioning Profiles")).resolve()
    pasta_perfis.mkdir(parents=True, exist_ok=True)

    uuid_app = plist_app["UUID"]
    nome_app = plist_app["Name"]
    uuid_notif = plist_notif["UUID"]
    nome_notif = plist_notif["Name"]

    destino_app = pasta_perfis / f"{uuid_app}.mobileprovision"
    destino_notif = pasta_perfis / f"{uuid_notif}.mobileprovision"
    alvos = [destino_app, destino_notif]

    manifesto_perfis = pasta / "perfis-instalados.json"
    manifesto_perfis.write_text(json.dumps([str(p) for p in alvos]))

    try:
        gravar_perfil_atomicamente(destino_app, dados_app)
        gravar_perfil_atomicamente(destino_notif, dados_notif)
    except Exception as erro:
        restantes = []
        falhas_remocao = []
        for p in alvos:
            for f in (p, p.with_name(f".{p.name}.tmp"), p.with_name(f"{p.name}.tmp")):
                if f.exists():
                    try:
                        f.unlink()
                    except OSError as err_unlink:
                        caminho_str = str(f)
                        if caminho_str not in restantes:
                            restantes.append(caminho_str)
                        falhas_remocao.append(f"{f}: {err_unlink}")
        manifesto_perfis.write_text(json.dumps(restantes))
        if restantes:
            raise RuntimeError(f"falha na instalação de perfis e sobra no rollback ({'; '.join(falhas_remocao)})") from erro
        raise

    if "GITHUB_ENV" in os.environ:
        with open(os.environ["GITHUB_ENV"], "a") as ambiente:
            ambiente.write(f"FRILA_PROVISIONING_PROFILE_APP={uuid_app}\n")
            ambiente.write(f"FRILA_PROVISIONING_PROFILE_APP_NAME={nome_app}\n")
            ambiente.write(f"FRILA_PROVISIONING_PROFILE_NOTIFICATION_SERVICE={uuid_notif}\n")
            ambiente.write(f"FRILA_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_NAME={nome_notif}\n")

    return uuid_app, uuid_notif


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
        if "GITHUB_ENV" in os.environ:
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
        nome_identidade = pares[0][1]
        mascarar(nome_identidade)
        m_nome = re.search(r'Apple Distribution:\s*(.*?)\s*\([A-Z0-9]{10}\)', nome_identidade)
        if m_nome and m_nome.group(1):
            mascarar(m_nome.group(1).strip())
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
        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a") as ambiente:
                ambiente.write(f"FRILA_CERTIFICADO_DISTRIBUICAO_SHA256={sha256}\n")

        uuid_app, uuid_notif = importar_perfis(pasta, sha256, equipe)
        if uuid_app and uuid_notif:
            print(f"Perfis App Store instalados (App: {uuid_app}, Notificações: {uuid_notif}).")
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
