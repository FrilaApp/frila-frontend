# Capturas da App Store (6,9 polegadas) — Frila iOS
**Cartão 33 (uwBBwwoV) · Sprint 3 (Loja)**

Este diretório contém o pipeline automatizado e as capturas de tela oficiais geradas para a ficha da App Store (iPhone de 6,9" / 6,7"), cumprindo os requisitos de conformidade visual, técnica e de privacidade da Apple e do Frila.

---

## 1. Especificações Técnicas das Capturas
- **Dimensões aceitas pela App Store (6,9" / 6,7"):** `1320 × 2868 px` (iPhone 16 Pro Max / 17 Pro Max) ou `1290 × 2796 px` (iPhone 14 Pro Max / 15 Pro Max / 16 Plus).
- **Formato:** PNG (24-bit RGB sem transparência/canal alfa desnecessário).
- **Dispositivo de captura:** Simulador iPhone 17 Pro Max (resolução física 1320 × 2868 px @3x).
- **Build de referência:** Frila v1.0.0 (build 1) — registrado automaticamente a partir de `iOS/project.yml`.

---

## 2. Conformidade e Privacidade (LGPD)
Todas as capturas utilizam exclusivamente **dados de demonstração sintéticos** fornecidos pelo ambiente do dublê em memória (`ApiClienteEmMemoria.swift`):
- **E-mails:** Domínios fictícios de exemplo (`nome@exemplo.com`, `contato@bistroipe.com.br`).
- **Nomes:** Perfis fictícios do catálogo (`Bistrô Ipê`, `Café de teste`, `Ana Cunha`, `Lucas Silva`, `Marina`).
- **Telefones e documentos:** Formatos sintéticos de teste (`(61) 99999-0000`, `123.456.789-01`).
- **Rejeição estrita:** O script executa OCR automatizado nativo (`Vision.framework`) em cada captura gerada e bloqueia com erro caso detecte nomes reais do time ou de sócios (Cauê, Fabrício, Matheus, Jotapê, Júlia) ou e-mails pessoais reais (`@gmail`, `@icloud`, etc.).

---

## 3. Lista e Ordem das Capturas Geradas

| # | Arquivo | Perfil | Tela / Fluxo | Dimensões | Hash SHA-256 |
|---|---|---|---|:---:|---|
| 01 | `01_profissional_vagas_feed.png` | Profissional | Feed de Oportunidades no DF | 1320 × 2868 | `3a731cb0...` |
| 02 | `02_profissional_detalhe_vaga.png` | Profissional | Detalhe da Vaga e Valor Líquido | 1320 × 2868 | `06fdfd79...` |
| 03 | `03_profissional_avaliacao_turno.png` | Profissional | Avaliação Mútua e Reputação | 1320 × 2868 | `2cec2dbe...` |
| 04 | `04_contratante_minhas_vagas.png` | Contratante | Painel Minhas Vagas do Estabelecimento | 1320 × 2868 | `a8e99446...` |
| 05 | `05_contratante_detalhe_vaga.png` | Contratante | Gestão de Vaga e Posições Preenchidas | 1320 × 2868 | `e0dd45b1...` |
| 06 | `06_contratante_cadastro_estabelecimento.png` | Contratante | Cadastro do Negócio e Localização | 1320 × 2868 | `bf9ea628...` |
| 07 | `07_geral_suporte_turno.png` | Geral / Suporte | Canal de Ajuda e Segurança no Turno | 1320 × 2868 | `03ab5f53...` |
| 08 | `08_geral_entrada_autenticacao.png` | Geral / Autenticação | Entrada Sem Senha por Código de E-mail | 1320 × 2868 | `ba1d68e3...` |

O manifesto estruturado em formato JSON encontra-se em `manifesto.json`.

---

## 4. Como Executar e Validar

A partir da pasta `iOS/`:
```bash
# Geração completa com simulador de 6,9":
./Scripts/gerar-capturas-loja.sh

# Apenas validação de conformidade (dimensões com sips e privacidade por OCR):
./Scripts/gerar-capturas-loja.sh --validar-apenas

# Executar a suíte de autoteste do script:
./Scripts/teste-gerar-capturas-loja.sh
```

---

## 5. Próximas Etapas Humanas
Conforme os limites de atuação de agentes definidos no Cartão 33:
1. **Aprovação de ordem final:** Decisão visual de produto/design pelo Fabrício e pela Júlia.
2. **Build 1.0 final de produção:** Compilação final assinada (prevista para 05/11).
3. **Vídeo de prévia da loja:** Captura e edição de vídeo de prévia da App Store.
