#!/usr/bin/env python3
"""Testa o ciclo do keychain e perfis com security/codesign simulados; não lê credenciais reais."""
import base64
import contextlib
import datetime
import hashlib
import importlib.util
import io
import json
import os
import pathlib
import plistlib
import ssl
import subprocess
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("assinatura", pathlib.Path(__file__).with_name("assinatura-local-ci.py"))
assinatura = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assinatura)


def criar_perfil_ficticio(uuid, nome, equipe, bundle_id, cert_der, expira_dias=30, get_task_allow=False, aps="production"):
    dados = {
        "UUID": uuid,
        "Name": nome,
        "TeamIdentifier": [equipe],
        "Entitlements": {
            "application-identifier": f"{equipe}.{bundle_id}",
            "get-task-allow": get_task_allow,
        },
        "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=expira_dias),
        "DeveloperCertificates": [cert_der],
    }
    if aps:
        dados["Entitlements"]["aps-environment"] = aps
    xml = plistlib.dumps(dados)
    envelope = b"CMS_SIMULADO_HEADER\x00\x01" + xml + b"\x00\x02CMS_SIMULADO_TRAILER"
    return base64.b64encode(envelope).decode()


class AssinaturaLocalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="frila-teste-keychain-")
        self.addCleanup(self.temp.cleanup)
        self.pasta = pathlib.Path(self.temp.name).resolve()
        self.ambiente = self.pasta / "ambiente"
        self.pasta_perfis = self.pasta / "perfis"
        self.der = b"certificado-publico-ficticio"
        self.identidade = hashlib.sha1(self.der).hexdigest().upper()
        self.nome = "Apple Distribution: Teste (TESTE12345)"
        self.etapas = []
        self.falha = None
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": os.environ.get("HOME", "/tmp"),
            "TMPDIR": os.environ.get("TMPDIR", "/tmp"),
            "RUNNER_TEMP": str(self.pasta), "GITHUB_ENV": str(self.ambiente), "FRILA_EQUIPE": "TESTE12345",
            "FRILA_PROFILES_DIR": str(self.pasta_perfis),
            "APPLE_DISTRIBUTION_CERT_P12_BASE64": base64.b64encode(b"p12-ficticio").decode(),
            "APPLE_DISTRIBUTION_CERT_P12_PASSWORD": "senha-ficticia-nao-publicar",
        }
        self.patch_env = mock.patch.dict(os.environ, env, clear=True)
        self.patch_env.start()
        self.addCleanup(self.patch_env.stop)
        self.umask = os.umask(0o077)
        self.addCleanup(os.umask, self.umask)
        self.saida = io.StringIO()
        self.patch_saida = contextlib.redirect_stdout(self.saida)
        self.patch_saida.__enter__()
        self.addCleanup(self.patch_saida.__exit__, None, None, None)
        self.patch_exec = mock.patch.object(assinatura, "executar", side_effect=self.executar)
        self.patch_exec.start()
        self.addCleanup(self.patch_exec.stop)

    def executar(self, etapa, *args):
        self.etapas.append((etapa, args))
        if etapa == self.falha:
            raise RuntimeError(f"{etapa} falhou")
        if etapa == "listar keychains":
            return '"/Users/runner/Library/Keychains/login.keychain-db"\n'
        if etapa == "criar keychain":
            pathlib.Path(args[-1]).touch()
        if etapa == "importar p12":
            arquivo = pathlib.Path(args[2])
            self.assertEqual(arquivo.read_bytes(), b"p12-ficticio")
            self.assertEqual(arquivo.stat().st_mode & 0o777, 0o600)
            self.assertIn("-T", args)
            self.assertNotIn("-A", args)
        if etapa == "conferir identidade":
            return f'1) {self.identidade} "{self.nome}"\n1 valid identities found\n'
        if etapa == "ler certificado público":
            return ssl.DER_cert_to_PEM_cert(self.der)
        return ""

    def keychain(self):
        linha = next(l for l in self.ambiente.read_text().splitlines() if l.startswith("FRILA_KEYCHAIN_PATH="))
        return pathlib.Path(linha.split("=", 1)[1])

    def test_importacao_prova_chave_e_preserva_keychains_anteriores(self):
        assinatura.importar()
        keychain = self.keychain()
        self.assertFalse((keychain.parent / "certificado.p12").exists())
        self.assertEqual(json.loads((keychain.parent / "keychains-anteriores.json").read_text()),
                         ["/Users/runner/Library/Keychains/login.keychain-db"])
        incluir = next(args for etapa, args in self.etapas if etapa == "incluir keychain")
        self.assertEqual(incluir[-2:], (str(keychain), "/Users/runner/Library/Keychains/login.keychain-db"))
        self.assertIn("FRILA_CERTIFICADO_DISTRIBUICAO_SHA256=" + hashlib.sha256(self.der).hexdigest(), self.ambiente.read_text())
        self.assertIn("verificar requisito designado", [e for e, _ in self.etapas])
        self.assertIn("::add-mask::senha-ficticia-nao-publicar", self.saida.getvalue())
        assinatura.apagar(keychain.parent)
        self.assertFalse(keychain.parent.exists())
        restaurar = next(args for etapa, args in self.etapas if etapa == "restaurar keychains")
        self.assertEqual(restaurar[-1], "/Users/runner/Library/Keychains/login.keychain-db")
        assinatura.apagar(keychain.parent)  # Limpeza após falha também é idempotente.

    def test_senha_incorreta_apaga_p12_e_keychain_sem_exportar_fingerprint(self):
        self.falha = "importar p12"
        with self.assertRaisesRegex(RuntimeError, "importar p12 falhou"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())
        self.assertNotIn("FRILA_CERTIFICADO_DISTRIBUICAO_SHA256", self.ambiente.read_text())
        self.assertIn("apagar keychain", [e for e, _ in self.etapas])

    def test_identidade_de_outra_equipe_interrompe_e_limpa(self):
        self.nome = "Apple Distribution: Teste (OUTRA12345)"
        with self.assertRaisesRegex(RuntimeError, "equipe do projeto"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_requisito_designado_invalido_interrompe_antes_do_archive(self):
        self.falha = "verificar requisito designado"
        with self.assertRaisesRegex(RuntimeError, "verificar requisito designado falhou"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())
        self.assertNotIn("FRILA_CERTIFICADO_DISTRIBUICAO_SHA256", self.ambiente.read_text())

    def test_segredo_ausente_nao_altera_keychains(self):
        del os.environ["APPLE_DISTRIBUTION_CERT_P12_PASSWORD"]
        with self.assertRaisesRegex(RuntimeError, "faltam APPLE"):
            assinatura.importar()
        self.assertEqual(self.etapas, [])

    def test_base64_invalido_nao_altera_keychains(self):
        os.environ["APPLE_DISTRIBUTION_CERT_P12_BASE64"] = "!base64-invalido!"
        with self.assertRaisesRegex(RuntimeError, "não é base64 válido"):
            assinatura.importar()
        self.assertEqual(self.etapas, [])

    def test_limpeza_recusa_pasta_fora_do_escopo(self):
        with self.assertRaisesRegex(RuntimeError, "fora do temporário permitido"):
            assinatura.apagar(self.pasta)
        self.assertEqual(self.etapas, [])

    def test_falha_na_restauracao_preserva_estado_para_tentar_limpeza_de_novo(self):
        assinatura.importar()
        keychain = self.keychain()
        self.falha = "restaurar keychains"
        with self.assertRaisesRegex(RuntimeError, "restaurar keychains falhou"):
            assinatura.apagar(keychain.parent)
        self.assertTrue((keychain.parent / "keychains-anteriores.json").exists())
        self.assertFalse((keychain.parent / "certificado.p12").exists())
        self.falha = None
        assinatura.apagar(keychain.parent)
        self.assertFalse(keychain.parent.exists())

    def test_importacao_com_perfis_instala_arquivos_e_exporta_variaveis(self):
        uuid_app = "11111111-aaaa-bbbb-cccc-111111111111"
        uuid_notif = "22222222-aaaa-bbbb-cccc-222222222222"
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            uuid_app, "Frila App Store", "TESTE12345", "com.frila.org.app", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            uuid_notif, "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        assinatura.importar()
        keychain = self.keychain()
        arquivo_app = self.pasta_perfis / f"{uuid_app}.mobileprovision"
        arquivo_notif = self.pasta_perfis / f"{uuid_notif}.mobileprovision"
        self.assertTrue(arquivo_app.exists())
        self.assertTrue(arquivo_notif.exists())
        texto_env = self.ambiente.read_text()
        self.assertIn(f"FRILA_PROVISIONING_PROFILE_APP={uuid_app}", texto_env)
        self.assertIn("FRILA_PROVISIONING_PROFILE_APP_NAME=Frila App Store", texto_env)
        self.assertIn(f"FRILA_PROVISIONING_PROFILE_NOTIFICATION_SERVICE={uuid_notif}", texto_env)
        self.assertIn("FRILA_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_NAME=Frila Notification Service", texto_env)

        # Limpeza deve remover os perfis instalados do diretório
        assinatura.apagar(keychain.parent)
        self.assertFalse(arquivo_app.exists())
        self.assertFalse(arquivo_notif.exists())
        self.assertFalse(keychain.parent.exists())

    def test_perfil_com_certificado_divergente_falha_e_limpa(self):
        cert_divergente = b"outro-certificado"
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-1", "Frila App Store", "TESTE12345", "com.frila.org.app", cert_divergente
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "não contém o certificado local importado"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())
        self.assertFalse((self.pasta_perfis / "uuid-1.mobileprovision").exists())

    def test_perfil_expirado_falha_e_limpa(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-1", "Frila App Store", "TESTE12345", "com.frila.org.app", self.der, expira_dias=-5
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "expirado"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_perfil_development_recusado_para_distribuicao(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-1", "Frila Dev Profile", "TESTE12345", "com.frila.org.app", self.der, get_task_allow=True
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "get-task-allow=false"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_perfil_de_outra_equipe_falha(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-1", "Frila App Store", "OUTRA12345", "com.frila.org.app", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "pertence a outra equipe"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_perfil_de_outro_bundle_falha(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-1", "Frila App Store", "TESTE12345", "com.outro.bundle", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "não corresponde ao identificador do bundle"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_perfil_base64_invalido_falha(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = "!base64-invalido!"
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "não é base64 válido"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_falta_de_perfil_na_ci_lanca_erro(self):
        os.environ["CI"] = "1"
        with self.assertRaisesRegex(RuntimeError, "na CI faltam APPLE_PROVISIONING_PROFILE_APP_BASE64"):
            assinatura.importar()
        self.assertFalse(self.keychain().parent.exists())

    def test_limpeza_de_perfis_idempotente(self):
        uuid_app = "11111111-aaaa-bbbb-cccc-111111111111"
        uuid_notif = "22222222-aaaa-bbbb-cccc-222222222222"
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            uuid_app, "Frila App Store", "TESTE12345", "com.frila.org.app", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            uuid_notif, "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        assinatura.importar()
        keychain = self.keychain()
        arquivo_app = self.pasta_perfis / f"{uuid_app}.mobileprovision"
        arquivo_app.unlink()  # Simular exclusão antecipada
        assinatura.apagar(keychain.parent)  # Não deve falhar
        self.assertFalse(keychain.parent.exists())

    def test_falha_na_escrita_do_segundo_perfil_faz_rollback_do_primeiro_e_limpa(self):
        uuid_app = "11111111-aaaa-bbbb-cccc-111111111111"
        uuid_notif = "22222222-aaaa-bbbb-cccc-222222222222"
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            uuid_app, "Frila App Store", "TESTE12345", "com.frila.org.app", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            uuid_notif, "Frila Notification Service", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        write_orig = pathlib.Path.write_bytes

        def falha_segundo(path_obj, data):
            if uuid_notif in path_obj.name:
                raise OSError("falha simulada no disco durante escrita do segundo perfil")
            return write_orig(path_obj, data)

        with mock.patch.object(pathlib.Path, "write_bytes", falha_segundo):
            with self.assertRaisesRegex(OSError, "falha simulada no disco"):
                assinatura.importar()

        # O primeiro perfil não pode restar no sistema
        self.assertFalse((self.pasta_perfis / f"{uuid_app}.mobileprovision").exists())
        self.assertFalse((self.pasta_perfis / f"{uuid_notif}.mobileprovision").exists())
        # A pasta temporária deve ter sido limpa
        self.assertEqual(len(list(self.pasta.glob("frila-assinatura-*"))), 0)

    def test_perfil_ad_hoc_com_provisioned_devices_recusado(self):
        dados = {
            "UUID": "uuid-adhoc", "Name": "Frila AdHoc", "TeamIdentifier": ["TESTE12345"],
            "Entitlements": {"application-identifier": "TESTE12345.com.frila.org.app", "get-task-allow": False, "aps-environment": "production"},
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30),
            "DeveloperCertificates": [self.der],
            "ProvisionedDevices": ["device-udid-1", "device-udid-2"],
        }
        xml = plistlib.dumps(dados)
        envelope = b"CMS_SIMULADO\x00" + xml + b"\x00CMS_TRAILER"
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = base64.b64encode(envelope).decode()
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notif", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "ProvisionedDevices"):
            assinatura.importar()

    def test_perfil_enterprise_recusado(self):
        dados = {
            "UUID": "uuid-enterprise", "Name": "Frila Enterprise", "TeamIdentifier": ["TESTE12345"],
            "Entitlements": {"application-identifier": "TESTE12345.com.frila.org.app", "get-task-allow": False, "aps-environment": "production"},
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30),
            "DeveloperCertificates": [self.der],
            "ProvisionsAllDevices": True,
        }
        xml = plistlib.dumps(dados)
        envelope = b"CMS_SIMULADO\x00" + xml + b"\x00CMS_TRAILER"
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = base64.b64encode(envelope).decode()
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-2", "Frila Notif", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        with self.assertRaisesRegex(RuntimeError, "ProvisionsAllDevices"):
            assinatura.importar()

    def test_escrita_parcial_perfil_limpa_temporario_e_nao_deixa_orfao(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-app", "Frila App", "TESTE12345", "com.frila.org.app", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-notif", "Frila Notif", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        original_write_bytes = pathlib.Path.write_bytes

        def falha_segundo_write(path_obj, data):
            if "uuid-notif" in path_obj.name:
                original_write_bytes(path_obj, data[:40])
                raise OSError("falha simulada de I/O na escrita do segundo perfil")
            return original_write_bytes(path_obj, data)

        with mock.patch.object(pathlib.Path, "write_bytes", falha_segundo_write):
            with self.assertRaises(OSError):
                assinatura.importar()

        keychain = self.keychain()
        assinatura.apagar(keychain.parent)
        remanescentes = list(self.pasta_perfis.glob("*.mobileprovision")) + list(self.pasta_perfis.glob("*.tmp"))
        self.assertEqual(remanescentes, [], f"Arquivos órfãos encontrados: {remanescentes}")

    def test_falha_transitoria_unlink_preserva_manifesto_e_limpa_no_always(self):
        os.environ["APPLE_PROVISIONING_PROFILE_APP_BASE64"] = criar_perfil_ficticio(
            "uuid-app", "Frila App", "TESTE12345", "com.frila.org.app", self.der
        )
        os.environ["APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64"] = criar_perfil_ficticio(
            "uuid-notif", "Frila Notif", "TESTE12345", "com.frila.org.app.notificationservice", self.der
        )
        original_write = pathlib.Path.write_bytes
        original_unlink = pathlib.Path.unlink
        falhas_unlink = True

        def falhar_segunda_escrita(path_obj, data):
            if "uuid-notif" in path_obj.name:
                raise OSError("falha simulada na escrita da extensão")
            return original_write(path_obj, data)

        def unlink_com_falha_transitoria(path_obj, *args, **kwargs):
            if "uuid-app" in path_obj.name and falhas_unlink:
                raise OSError("falha transitória simulada no unlink")
            return original_unlink(path_obj, *args, **kwargs)

        with mock.patch.object(pathlib.Path, "write_bytes", falhar_segunda_escrita), \
             mock.patch.object(pathlib.Path, "unlink", unlink_com_falha_transitoria):
            with self.assertRaises(RuntimeError):
                assinatura.importar()

        keychain = self.keychain()
        self.assertTrue(keychain.parent.exists())
        manifesto = json.loads((keychain.parent / "perfis-instalados.json").read_text())
        self.assertTrue(any("uuid-app" in item for item in manifesto), f"Manifesto: {manifesto}")

        # Simula o passo de limpeza always() após cessar a falha transitória
        falhas_unlink = False
        assinatura.apagar(keychain.parent)
        remanescentes = list(self.pasta_perfis.glob("*.mobileprovision"))
        self.assertEqual(remanescentes, [], f"Arquivos restantes após always: {remanescentes}")
        self.assertFalse(keychain.parent.exists())


class ErrosSemCredenciaisTests(unittest.TestCase):
    def test_erro_de_subprocesso_nao_publica_argv_nem_saida_com_segredos(self):
        resultado = subprocess.CompletedProcess(["security", "senha-ficticia"], 1,
                                                b"p12-ficticio", b"senha-ficticia")
        with mock.patch.object(subprocess, "run", return_value=resultado):
            with self.assertRaises(RuntimeError) as erro:
                assinatura.executar("importar p12", "security", "senha-ficticia")
        self.assertNotIn("senha-ficticia", str(erro.exception))
        self.assertNotIn("p12-ficticio", str(erro.exception))


class GuardaEnviarTestflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="frila-teste-guarda-")
        self.addCleanup(self.temp.cleanup)
        self.pasta = pathlib.Path(self.temp.name)
        (self.pasta / "iOS/project.yml").parent.mkdir(parents=True, exist_ok=True)
        (self.pasta / "iOS/project.yml").write_text("    DEVELOPMENT_TEAM: TESTE12345\n")
        (self.pasta / "iOS/Frila.xcodeproj").mkdir(exist_ok=True)
        firebase = self.pasta / "iOS/Resources/Firebase/Prod"
        firebase.mkdir(parents=True, exist_ok=True)
        (firebase / "GoogleService-Info.plist").write_text("fixture sem credenciais")
        self.authkey = self.pasta / "AuthKey.p8"
        self.authkey.write_text("fixture sem chave")
        self.bin = self.pasta / "bin"
        self.bin.mkdir(exist_ok=True)
        self.args_log = self.pasta / "args.json"
        stub = self.bin / "xcodebuild"
        stub.write_text(f'''#!/usr/bin/env python3
import json, os, sys, pathlib, plistlib
with open("{self.args_log}", "w") as f:
    json.dump(sys.argv[1:], f)
if "archive" in sys.argv:
    for i, arg in enumerate(sys.argv):
        if arg == "-archivePath" and i + 1 < len(sys.argv):
            app_dir = pathlib.Path(sys.argv[i + 1]) / "Products" / "Applications" / "Frila.app"
            app_dir.mkdir(parents=True, exist_ok=True)
            info = {{"CFBundleShortVersionString": "0.5.4", "CFBundleVersion": "20261029.1", "FRILA_ENVIRONMENT": "frila-prod"}}
            with open(app_dir / "Info.plist", "wb") as fp:
                plistlib.dump(info, fp)
            ext_dir = app_dir / "PlugIns" / "FrilaNotificationService.appex"
            ext_dir.mkdir(parents=True, exist_ok=True)
            with open(ext_dir / "Info.plist", "wb") as fp:
                plistlib.dump(info, fp)
''')
        stub.chmod(0o755)
        formatter = self.bin / "xcbeautify"
        formatter.write_text("#!/bin/bash\ncat\n")
        formatter.chmod(0o755)
        self.script_original = (pathlib.Path(__file__).parent / "enviar-testflight.sh").read_text()
        self.script_base = self.script_original.split("\nAPP_ARQUIVADO=")[0] + "\nexit 0\n"

    def rodar(self, script_texto=None, extra_env=None, args=None):
        texto = script_texto if script_texto is not None else self.script_base
        caminho_script = self.pasta / "iOS/Scripts/enviar-testflight.sh"
        caminho_script.parent.mkdir(parents=True, exist_ok=True)
        caminho_script.write_text(texto)
        base_env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("APPLE_", "FRILA_", "ASC_"))}
        env = dict(base_env,
                   PATH=f"{self.bin}:{os.environ['PATH']}",
                   CI="1",
                   FRILA_CERTIFICADO_DISTRIBUICAO_SHA256="ficticio",
                   ASC_KEY_PATH=str(self.authkey),
                   ASC_KEY_ID="FICTICIO",
                   ASC_ISSUER_ID="FICTICIO",
                   FRILA_NUMERO_DO_BUILD="20261029.1",
                   FRILA_PROVISIONING_PROFILE_APP="UUID-APP-FICTICIO",
                   FRILA_PROVISIONING_PROFILE_NOTIFICATION_SERVICE="UUID-EXT-FICTICIA",
                   FRILA_SAIDA=str(self.pasta / "saida"))
        if extra_env:
            env.update(extra_env)
        cmd_args = args if args is not None else ["Frila-Prod", "0.5.4", "--sem-envio"]
        return subprocess.run(["bash", str(caminho_script), *cmd_args],
                              env=env, capture_output=True, text=True)

    def test_baseline_archive_usa_manual_sem_allow_provisioning_updates(self):
        res = self.rodar()
        self.assertEqual(res.returncode, 0, f"falhou: {res.stderr}")
        self.assertTrue(self.args_log.exists())
        args = json.loads(self.args_log.read_text())
        self.assertIn("archive", args)
        self.assertIn("CODE_SIGN_STYLE=Manual", args)
        self.assertNotIn("-allowProvisioningUpdates", args)

    def test_mutante_flag_no_archive_falha_guarda(self):
        mutante = self.script_base.replace("xcodebuild archive \\\n", "xcodebuild archive -allowProvisioningUpdates \\\n", 1)
        self.assertNotEqual(mutante, self.script_base)
        res = self.rodar(script_texto=mutante)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("-allowProvisioningUpdates", res.stderr)

    def test_mutante_automatic_no_archive_falha_guarda(self):
        mutante = self.script_base.replace("CODE_SIGN_STYLE=Manual", "CODE_SIGN_STYLE=Automatic", 1)
        self.assertNotEqual(mutante, self.script_base)
        res = self.rodar(script_texto=mutante)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("CODE_SIGN_STYLE=Automatic", res.stderr)

    def test_mutante_omissao_de_manual_no_archive_falha_guarda(self):
        mutante = self.script_base.replace("CODE_SIGN_STYLE=Manual", "# sem estilo", 1)
        self.assertNotEqual(mutante, self.script_base)
        res = self.rodar(script_texto=mutante)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("assinatura manual ausente", res.stderr)

    def test_flag_em_autenticacao_falha_guarda(self):
        mutante = self.script_base.replace(
            "autenticacao=(-authenticationKeyPath",
            "autenticacao=(-allowProvisioningUpdates -authenticationKeyPath", 1
        )
        self.assertNotEqual(mutante, self.script_base)
        res = self.rodar(script_texto=mutante)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("-allowProvisioningUpdates", res.stderr)

    def test_flag_em_variavel_ambiente_falha_guarda(self):
        res = self.rodar(extra_env={"XCODEBUILD_EXTRA_ARGS": "-allowProvisioningUpdates"})
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("-allowProvisioningUpdates", res.stderr)

    def test_flag_em_argumento_falha_guarda(self):
        res = self.rodar(args=["Frila-Prod", "0.5.4", "-allowProvisioningUpdates", "--sem-envio"])
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("-allowProvisioningUpdates", res.stderr)

    def test_mutante_command_xcodebuild_falha_guarda(self):
        mutante = self.script_base.replace("xcodebuild archive \\\n", "command xcodebuild archive \\\n", 1)
        self.assertNotEqual(mutante, self.script_base)
        res = self.rodar(script_texto=mutante)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("command xcodebuild", res.stderr)

    def test_mutante_export_com_command_xcodebuild_falha_guarda(self):
        mutante = self.script_original.replace('xcodebuild -exportArchive "${args[@]}"',
                                               'command xcodebuild -exportArchive "${args[@]}"', 1)
        self.assertNotEqual(mutante, self.script_original)
        res = self.rodar(script_texto=mutante)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("command xcodebuild", res.stderr)

    def test_mutante_export_com_allow_provisioning_updates_falha_guarda(self):
        mutante = self.script_original.replace('xcodebuild -exportArchive "${args[@]}"',
                                               'xcodebuild -exportArchive -allowProvisioningUpdates "${args[@]}"', 1)
        self.assertNotEqual(mutante, self.script_original)
        script_com_export = mutante.split('\nIPA=')[0] + '\nexit 0\n'
        res = self.rodar(script_texto=script_com_export)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("-allowProvisioningUpdates", res.stderr)


if __name__ == "__main__":
    unittest.main()
