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

## 2. Asset Atual

O ícone atual é o **ícone alpha da build**: F da Prodigy Sans Black sobre blueprint azul, montado no Icon Composer. O azul é proposital, para marcar a build como versão de teste até o logo definitivo. A origem é `entregas/icone-build/FrilaTest.icon` em [fbtostadev/frila-branding-design](https://github.com/fbtostadev/frila-branding-design).

- Arquivo: `iOS/Resources/AppIcon.icon` (`icon.json` + `Assets/f.svg` e `Assets/grade.svg`), registrado nos recursos do alvo `Frila` em `project.yml`.
- Não existe `AppIcon.appiconset`: dois ícones com o nome `AppIcon` entrariam em conflito.
- O `actool` gera a partir do `.icon` as imagens das versões anteriores ao iOS 26 (o app suporta desde o iOS 17).
- **Compatibilidade com o Xcode 26 da CI:** o `icon.json` não pode ter os campos que só o Icon Composer do Xcode 27 grava (`features`, `blur-material`, `refractivity`, `specular`) nem fill `automatic-gradient`; use fill `solid`. Com eles, o `actool` 26.6 quebra com "attempt to insert nil object".

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
- **Arte definitiva:** o logo definitivo ainda não existe; depende do design (cartão do Trello #169, [MXqhHjWK](https://trello.com/c/MXqhHjWK)). Até lá, o app compila e vai para o TestFlight com o ícone alpha.

### 4.2. Procedimento para Atualização pelo Design
1. **Montagem:** montar o ícone no Icon Composer e salvar o `.icon`.
2. **Substituição:** trocar o conteúdo de `iOS/Resources/AppIcon.icon`, mantendo o nome `AppIcon.icon`.
3. **Compatibilidade:** remover do `icon.json` os campos listados na seção 2, até a CI usar o Xcode 27.
4. **Verificação:**
   ```bash
   iOS/Scripts/teste-conferir-release.sh
   iOS/Scripts/conferir-release.sh <caminho-do-app>
   ```
