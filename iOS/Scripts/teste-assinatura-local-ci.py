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
            "RUNNER_TEMP": str(self.pasta), "GITHUB_ENV": str(self.ambiente), "FRILA_EQUIPE": "TESTE12345",
            "FRILA_PROFILES_DIR": str(self.pasta_perfis),
            "APPLE_DISTRIBUTION_CERT_P12_BASE64": base64.b64encode(b"p12-ficticio").decode(),
            "APPLE_DISTRIBUTION_CERT_P12_PASSWORD": "senha-ficticia-nao-publicar",
        }
        self.patch_env = mock.patch.dict(os.environ, env)
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


class ErrosSemCredenciaisTests(unittest.TestCase):
    def test_erro_de_subprocesso_nao_publica_argv_nem_saida_com_segredos(self):
        resultado = subprocess.CompletedProcess(["security", "senha-ficticia"], 1,
                                                b"p12-ficticio", b"senha-ficticia")
        with mock.patch.object(subprocess, "run", return_value=resultado):
            with self.assertRaises(RuntimeError) as erro:
                assinatura.executar("importar p12", "security", "senha-ficticia")
        self.assertNotIn("senha-ficticia", str(erro.exception))
        self.assertNotIn("p12-ficticio", str(erro.exception))


if __name__ == "__main__":
    unittest.main()
