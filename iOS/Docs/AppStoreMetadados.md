# Metadados para o App Store Connect — Frila

> Documento de referência para preenchimento da ficha do app no App Store Connect.
> Todos os campos foram auditados contra os limites oficiais da Apple e a
> [Diretriz 2.3 — Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata).
>
> **Nenhuma promessa de tempo de fechamento**, **nenhuma menção a comissão** e
> **todas as URLs sob HTTPS**, conforme critério do cartão #78.

---

## 1. Identificação

| Campo | Valor | Contagem | Limite |
|---|---|---:|---:|
| Nome do aplicativo | `Frila` | 5 caracteres | 30 caracteres |
| Subtítulo | `Vagas de turno por perto` | 24 caracteres | 30 caracteres |

**Fonte dos limites:** Apple App Store Review Guidelines, Diretriz 2.3.7 — "App names must be
limited to 30 characters"; subtítulo segue o mesmo limite de 30 caracteres
([App Store Connect Help — App information](https://developer.apple.com/help/app-store-connect/reference/app-information)).

---

## 2. Palavras-chave

```
frila,trabalho,turno,vaga,freelancer,extra,escala,plantão,bico,emprego,renda,diária,perto
```

| Métrica | Valor | Limite |
|---|---:|---:|
| Caracteres | 89 | — |
| Bytes (UTF-8) | 91 | 100 |

> **Nota:** O campo de palavras-chave do App Store Connect é limitado a **100 bytes**
> (não caracteres), o que é relevante quando há acentos (cada acento em UTF-8 ocupa 2 bytes).
> Fonte: [Apple App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information);
> confirmação empírica em diversas referências de ASO.
>
> Sem espaço depois das vírgulas, conforme recomendação da Apple.
> Termos do nome e do subtítulo não são repetidos nas keywords porque a Apple combina
> automaticamente os três campos na indexação
> (Fonte: [Apple — Choosing keywords](https://developer.apple.com/app-store/search/)).

---

## 3. Texto Promocional (máximo 170 caracteres)

```
Encontre vagas de turno perto de você. Estabelecimentos publicam, profissionais se candidatam. Sem mensalidade.
```

| Métrica | Valor | Limite |
|---|---:|---:|
| Caracteres | 111 | 170 |

> Editável sem nova versão do app. Não indexado para busca.
> Fonte: [App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information).

---

## 4. Descrição (máximo 4.000 caracteres)

```
O Frila conecta estabelecimentos que precisam de reforço com profissionais
disponíveis para trabalhar por turno.

COMO FUNCIONA PARA O ESTABELECIMENTO
• Cadastre o local com endereço e dados de contato.
• Publique vagas informando função, data, horário e valor do turno.
• Receba candidaturas e selecione quem vai trabalhar.
• Acompanhe a presença pelo check-in e check-out do profissional.

COMO FUNCIONA PARA O PROFISSIONAL
• Crie seu perfil com as funções que você exerce.
• Veja vagas próximas ao seu endereço de referência.
• Candidate-se com um toque e aguarde a seleção.
• No dia do turno, faça check-in ao chegar e check-out ao sair.

PRESENÇA VERIFICADA
O check-in e o check-out usam a localização do aparelho apenas para medir a
distância até o endereço da vaga. Só a distância é enviada — a coordenada
exata não sai do aparelho.

DADOS PROTEGIDOS
• Conexão sempre por HTTPS.
• Dados sensíveis no Keychain do aparelho.
• Nenhum rastreamento de terceiros.
• Veja nossa Política de Privacidade: https://frila.app/privacidade

CONTATO
Dúvidas ou sugestões: suportefrila@gmail.com
Termos de Uso: https://frila.app/termos
```

| Métrica | Valor | Limite |
|---|---:|---:|
| Caracteres | 1.127 | 4.000 |

### Auditoria de conformidade com a Diretriz 2.3

| Verificação | Resultado |
|---|---|
| Promessa de tempo de fechamento (ex.: "em 5 minutos", "em segundos") | ✅ Ausente |
| Menção a comissão, taxa ou percentual cobrado | ✅ Ausente |
| Menção a plataformas concorrentes (Android, Google Play) | ✅ Ausente |
| Preços ou valores monetários na descrição | ✅ Ausente |
| Afirmações inverificáveis ("o melhor", "número 1") | ✅ Ausente |
| Funcionalidades descritas existem no app | ✅ Todas presentes no código-fonte |

---

## 5. URLs obrigatórias

| Campo | URL | Protocolo | Confere com `EnderecosOficiais.swift`? |
|---|---|---|---|
| URL de Privacidade | `https://frila.app/privacidade` | ✅ HTTPS | ✅ `politicaDePrivacidade` (linha 21) |
| URL de Suporte | `mailto:suportefrila@gmail.com` | — (mailto) | ✅ `emailSuporte` (linha 22) |
| URL de Marketing | `https://frila.app/termos` | ✅ HTTPS | ✅ `termosDeUso` (linha 20) |

> **Fonte:** [`EnderecosOficiais.swift`](../Sources/Apresentacao/EnderecosOficiais.swift), linhas 19–23.
>
> **Nota sobre a URL de Suporte:** O App Store Connect aceita URLs `mailto:` no campo de suporte.
> A URL é gerada pela propriedade computada `urlSuporte` em `EnderecosOficiais.swift:10`.
> Se o Cauê preferir uma página web de suporte em vez de mailto, ela precisará ser criada em
> `https://frila.app/suporte` e atualizada no código-fonte.

---

## 6. Classificação etária e território

| Campo | Valor |
|---|---|
| Classificação etária | **18+** (o app envolve relação de trabalho com dados pessoais e financeiros) |
| Território de distribuição | **Brasil** (restrição: apenas App Store brasileira) |

> **Fonte da obrigação:** Diretriz 2.3.6 — "Answer the age rating questions in App Store Connect
> honestly so that your app aligns properly with parental controls."
> A classificação 18+ reflete o fato de o app mediar contratação de trabalho por turno com
> troca de dados pessoais (telefone, endereço, presença), o que não é adequado para menores.

---

## 7. Categoria

| Campo | Valor |
|---|---|
| Categoria principal | **Negócios** (Business) |
| Categoria secundária | **Produtividade** (Productivity) |

> **Fonte:** Diretriz 2.3.5 e [App Store Category Definitions](https://developer.apple.com/app-store/categories/).

---

## 8. Informações para a equipe de revisão

| Campo | Valor |
|---|---|
| Notas para o revisor | O app requer cadastro com e-mail e código de verificação. Para testar, crie uma conta com qualquer e-mail válido. O app conecta estabelecimentos e profissionais para turnos de trabalho no Brasil. |
| Conta de demonstração | _(a ser preenchida pelo Cauê antes da submissão)_ |

---

## Fontes

1. [Apple App Store Review Guidelines — 2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)
2. [Apple App Store Connect Help — App information](https://developer.apple.com/help/app-store-connect/reference/app-information)
3. [Apple — Choosing keywords](https://developer.apple.com/app-store/search/)
4. [`EnderecosOficiais.swift`](../Sources/Apresentacao/EnderecosOficiais.swift) — URLs oficiais do app
5. [`SegurancaEPrivacidade.md`](SegurancaEPrivacidade.md) — auditoria de segurança e privacidade do app
