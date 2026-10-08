#!/usr/bin/env python3
"""Regressão do 90035, com assinaturas locais descartáveis e sem credenciais Apple."""
import contextlib
import io
import pathlib
import plistlib
import datetime
import hashlib
import importlib.util
import shutil
import subprocess
import tempfile
import sys
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("diagnostico", pathlib.Path(__file__).with_name("diagnosticar-assinatura.py"))
diagnostico = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostico)


class DiagnosticoAssinaturaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporario = tempfile.TemporaryDirectory(prefix="frila-teste-assinatura-")
        cls.pasta = pathlib.Path(cls.temporario.name)
        fonte = cls.pasta / "prova.c"
        fonte.write_text("int main(void) { return 0; }\n")
        cls.valido = cls.pasta / "valido"
        subprocess.run(["xcrun", "clang", str(fonte), "-o", str(cls.valido)], check=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(cls.valido)], check=True,
                       capture_output=True)
        cls.invalido = cls.pasta / "invalido"
        shutil.copyfile(cls.valido, cls.invalido)
        # A assinatura criptográfica é válida, mas seu requisito designado não é satisfeito.
        subprocess.run(["codesign", "--force", "--sign", "-", "--requirements",
                        '=designated => identifier "outro.identificador"', str(cls.invalido)],
                       check=True, capture_output=True)
        cls.script = pathlib.Path(__file__).with_name("diagnosticar-assinatura.py")

    @classmethod
    def tearDownClass(cls):
        cls.temporario.cleanup()

    def diagnosticar(self, caminho, *opcoes):
        return subprocess.run(["python3", str(self.script), *opcoes, str(caminho)],
                              capture_output=True, text=True)

    def test_codigo_com_requisito_satisfeito_passa(self):
        resultado = self.diagnosticar(self.valido)
        self.assertEqual(resultado.returncode, 0, resultado.stderr)
        self.assertIn("satisfies its Designated Requirement", resultado.stdout)

    def test_codigo_valido_com_requisito_incompativel_interrompe_envio(self):
        resultado = self.diagnosticar(self.invalido)
        self.assertNotEqual(resultado.returncode, 0)
        self.assertIn("valid on disk", resultado.stdout)
        self.assertIn("does not satisfy its designated Requirement", resultado.stdout)
        self.assertIn("envio ao TestFlight interrompido", resultado.stderr)

    def test_caminho_ausente_falha_em_vez_de_ignorar_diagnostico(self):
        resultado = self.diagnosticar(self.pasta / "ausente.app")
        self.assertNotEqual(resultado.returncode, 0)
        self.assertIn("não encontrado", resultado.stderr)

    def test_assinatura_ad_hoc_nao_substitui_certificado_importado(self):
        resultado = self.diagnosticar(self.valido, "--certificado-esperado", "a" * 64,
                                     "--equipe", "TESTE12345")
        self.assertNotEqual(resultado.returncode, 0)
        self.assertIn("certificado folha ausente", resultado.stdout)
        self.assertIn("envio ao TestFlight interrompido", resultado.stderr)


class PerfilDistribuicaoTests(unittest.TestCase):
    def setUp(self):
        self.certificado = hashlib.sha256(b"certificado-local-ficticio").hexdigest()
        self.dados = {
            "DeveloperCertificates": [b"certificado-cloud-ficticio", b"certificado-local-ficticio"],
            "TeamIdentifier": ["TESTE12345"],
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1),
            "Entitlements": {"application-identifier": "TESTE12345.exemplo.app", "get-task-allow": False,
                             "aps-environment": "production"},
        }

    def conferir(self):
        return diagnostico.conferir_perfil(self.dados, self.certificado, "TESTE12345", "exemplo.app")

    def test_perfil_com_certificados_local_e_cloud_passa(self):
        self.assertEqual(self.conferir(), [])

    def test_perfil_so_com_cloud_falha(self):
        self.dados["DeveloperCertificates"] = [b"certificado-cloud-ficticio"]
        self.assertIn("perfil não contém o certificado local importado", self.conferir())

    def test_perfil_de_outra_equipe_falha(self):
        self.dados["TeamIdentifier"] = ["OUTRA12345"]
        self.assertIn("perfil pertence a outra equipe", self.conferir())

    def test_perfil_de_outro_bundle_falha(self):
        self.dados["Entitlements"]["application-identifier"] = "TESTE12345.outro.app"
        self.assertIn("perfil não corresponde ao identificador do bundle", self.conferir())

    def test_perfil_expirado_falha(self):
        self.dados["ExpirationDate"] -= datetime.timedelta(days=2)
        self.assertIn("perfil ausente de validade ou expirado", self.conferir())

    def test_perfil_de_desenvolvimento_falha(self):
        self.dados["Entitlements"]["get-task-allow"] = True
        self.dados["Entitlements"]["aps-environment"] = "development"
        self.assertEqual(len(self.conferir()), 2)

    def test_extensao_sem_push_passa(self):
        del self.dados["Entitlements"]["aps-environment"]
        self.assertEqual(self.conferir(), [])


class CertificadoExportadoTests(unittest.TestCase):
    setUp = PerfilDistribuicaoTests.setUp

    def conferir_export(self, cloud=False, perfil_ausente=False):
        with tempfile.TemporaryDirectory(prefix="frila-teste-export-") as pasta:
            raiz = pathlib.Path(pasta) / "Frila.app"
            framework = raiz / "Frameworks" / "Teste.framework"
            extensao = raiz / "PlugIns" / "Teste.appex"
            framework.mkdir(parents=True)
            extensao.mkdir(parents=True)
            for bundle in (raiz, extensao):
                (bundle / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "exemplo.app"}))
                if not (perfil_ausente and bundle == extensao):
                    (bundle / "embedded.mobileprovision").touch()

            def executar(*args):
                if args[0] == "security":
                    return 0, plistlib.dumps(self.dados), b""
                for arg in args:
                    if arg.startswith("--extract-certificates="):
                        der = b"certificado-cloud-ficticio" if cloud and args[-1] == str(framework) else b"certificado-local-ficticio"
                        pathlib.Path(arg.split("=", 1)[1] + "0").write_bytes(der)
                return 0, b"", b""

            saida = io.StringIO()
            with mock.patch.object(diagnostico, "executar", side_effect=executar), \
                 mock.patch.object(sys, "argv", ["diagnostico", "--certificado-esperado", self.certificado,
                                                "--equipe", "TESTE12345", str(raiz)]), \
                 contextlib.redirect_stdout(saida):
                try:
                    diagnostico.main()
                    return None, saida.getvalue()
                except SystemExit as erro:
                    return erro.code, saida.getvalue()

    def test_export_local_em_todos_os_bundles_passa(self):
        erro, _ = self.conferir_export()
        self.assertIsNone(erro)

    def test_framework_com_certificado_cloud_interrompe_envio(self):
        erro, saida = self.conferir_export(cloud=True)
        self.assertIn("envio ao TestFlight interrompido", erro)
        self.assertIn("certificado folha diferente da identidade local importada", saida)

    def test_extensao_sem_perfil_interrompe_envio(self):
        erro, saida = self.conferir_export(perfil_ausente=True)
        self.assertIn("envio ao TestFlight interrompido", erro)
        self.assertIn("perfil de distribuição ausente", saida)


if __name__ == "__main__":
    unittest.main()
