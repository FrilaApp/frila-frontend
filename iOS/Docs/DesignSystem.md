# Design system iOS

O módulo `FrilaApresentacao` concentra os tokens e componentes SwiftUI. Cores vivem em `DesignSystem.xcassets`, com variantes clara/escura; tipografia usa estilos semânticos do sistema para responder ao Dynamic Type.

## Tokens

- Espaçamento: 4, 8, 16, 24 e 32 pt.
- Raios: 8, 12 e 20 pt.
- Alvo interativo mínimo: 44 × 44 pt.
- Cores: primária, conteúdo sobre primária, fundo, superfície elevada, texto primário/secundário, sucesso, alerta e perigo.

## Componentes iniciais

Botões primário/secundário, campo comum, código de acesso, pill de filtro, cartão de vaga, selo de reputação, aviso, folha e avaliação sim/não. Estados reutilizáveis cobrem carregando, vazio, erro com retry, offline e envio pendente.

`CatalogoDesignSystem` é a referência executável em Debug e inclui preview com Dynamic Type de acessibilidade.
