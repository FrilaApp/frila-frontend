#!/usr/bin/env python3
"""Regressão do 90035, com assinaturas locais descartáveis e sem credenciais Apple."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest


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

    def diagnosticar(self, caminho):
        return subprocess.run(["python3", str(self.script), str(caminho)],
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


if __name__ == "__main__":
    unittest.main()
