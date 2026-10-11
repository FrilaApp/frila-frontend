# Especificação Técnica: Ícone do App e Launch Screen

Documento de especificação técnica e auditoria dos assets de ícone e tela de abertura (*Launch Screen*) do Frila iOS para o primeiro TestFlight e submissão à App Store, referente ao cartão [MXqhHjWK](https://trello.com/c/MXqhHjWK) (#169).

---

## 1. Requisitos Técnicos da Apple e Xcode

### 1.1. Asset do Ícone (`AppIcon`)
- **Tamanho único universal:** Resolução exata de **1024 × 1024 pixels** (quadrado 1:1), adotando o padrão introduzido a partir do Xcode 14 (`idiom: universal`, `platform: ios`, `size: 1024x1024` em `Contents.json`). O compilador de catálogo de assets (`actool`) gera automaticamente todas as resoluções derivadas necessárias (iPhone, iPad, notificações, busca Spotlight, Ajustes e App Store).
- **Sem canal alfa (opacidade total):** A Apple rejeita compilações e submissões no App Store Connect que contenham canal de transparência ou canal alfa (`hasAlpha: yes`). O PNG precisa ser exportado como 24-bit RGB ou 32-bit com canal alfa desabilitado/opaco (`noneSkipLast`).
- **Espaço de cores:** sRGB ou Display P3, com profundidade de 8 bits por canal de cor, sem perfis de cor anômalos.
- **Cantos retos:** Não aplicar máscaras de cantos arredondados na imagem de origem; o iOS aplica automaticamente o recorte de cantos arredondados contínuos (*squircle*) no sistema.
- **Camadas dinâmicas (iOS 26 / Icon Composer):** Para o suporte a ícones com profundidade, modo escuro (*Dark Mode*) e variantes tintadas (*Tinted*), o formato `.icon` exige a separação estruturada entre plano de fundo (*background*), elemento intermediário (*middle*) e primeiro plano (*foreground*).

### 1.2. Launch Screen
- **Geração automática (`UILaunchScreen_Generation`):** O projeto utiliza a geração nativa de tela de abertura do UIKit (`INFOPLIST_KEY_UILaunchScreen_Generation: YES` no `project.yml`).
- **Eliminação de Storyboards legadas:** Não são utilizados arquivos `.storyboard` ou `.xib` legados para Launch Screen, eliminando inconsistências visuais e atrasos de renderização na inicialização a frio (*cold start*).
- **Comportamento:** O sistema renderiza instantaneamente o fundo padrão enquanto os módulos do SwiftUI e a árvore de visualização (`AppCoordinatorView`) são carregados na memória.

---

## 2. Auditoria Estática do Asset Atual

O repositório possui atualmente o asset de ícone provisório gerado no PR #146 via script auxiliar (`iOS/Scripts/gerar-icone-provisorio.swift`), que desenha sobre o tom da marca `BrandPrimary` (`#B57005`).

### 2.1. Verificação via `sips`
Execução da auditoria nos metadados do arquivo `iOS/Resources/App.xcassets/AppIcon.appiconset/AppIcon.png`:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha iOS/Resources/App.xcassets/AppIcon.appiconset/AppIcon.png
```

**Resultado:**
- `pixelWidth`: `1024` (em conformidade)
- `pixelHeight`: `1024` (em conformidade)
- `hasAlpha`: `no` (em conformidade — ausência de transparência confirmada)

### 2.2. Configuração do Asset Catalog (`Contents.json`)
Arquivo: `iOS/Resources/App.xcassets/AppIcon.appiconset/Contents.json`:
```json
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
```

---

## 3. Configurações de Projeto e Verificações de Release

### 3.1. `iOS/project.yml`
No target principal `Frila`:
- Linha 285: `INFOPLIST_KEY_UILaunchScreen_Generation: YES` — habilita a geração nativa da Launch Screen.
- Linha 290: `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` — vincula o asset catalog `AppIcon` como ícone primário do bundle.

### 3.2. Script de Validação de Release (`iOS/Scripts/conferir-release.sh`)
As linhas 23 a 40 de `iOS/Scripts/conferir-release.sh` asseguram que o release empacotado para o TestFlight:
1. Declare a chave `CFBundleIconName` com o valor `AppIcon` no `Info.plist` extraído do `.ipa`.
2. Contenha o arquivo compilado `Assets.car`.
3. Contenha no `Assets.car` ao menos um asset com `Name: "AppIcon"` e `AssetType: "Icon Image"`, verificado via ferramenta `xcrun assetutil --info`.

---

## 4. Handoff de Design e Procedimento de Substituição

### 4.1. Dados Faltantes e Dependências
- **Arte definitiva e camadas:** A arte final do ícone e os arquivos em camadas do Icon Composer (`.icon`) dependem da entrega final do designer (Fabrício) e da consolidação da votação do time registrada no cartão do Trello #169 ([MXqhHjWK](https://trello.com/c/MXqhHjWK)).
- O aplicativo está apto para compilação e validação do TestFlight utilizando o asset provisório sem bloqueios técnicos.

### 4.2. Procedimento para Atualização pelo Design
Ao disponibilizar o arquivo definitivo:
1. **Exportação:** Gerar arquivo PNG exatamente em **1024 × 1024 pixels**, espaço de cores sRGB/Display P3, sem canal alfa/transparência.
2. **Substituição:** Substituir o arquivo em `iOS/Resources/App.xcassets/AppIcon.appiconset/AppIcon.png`.
3. **Auditoria de canal alfa:**
   ```bash
   sips -g pixelWidth -g pixelHeight -g hasAlpha iOS/Resources/App.xcassets/AppIcon.appiconset/AppIcon.png
   ```
   O resultado de `hasAlpha` deve obrigatoriamente ser `no`.
4. **Verificação de textos e release:**
   ```bash
   iOS/Scripts/conferir-textos.sh
   iOS/Scripts/conferir-release.sh <caminho-do-ipa>
   ```
