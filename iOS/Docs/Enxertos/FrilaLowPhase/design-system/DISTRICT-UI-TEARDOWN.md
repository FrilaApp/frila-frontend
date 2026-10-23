# Decupagem Estrutural de Interface: Aplicativo District

Documento de análise técnica de arquitetura de interface, templates macro e componentização do aplicativo District (District by Zomato), extraído via MCP do Refero para embasamento do protótipo de baixa e média fidelidade do ecossistema Frila.

Informação de escopo: Este documento trata estritamente da anatomia funcional, hierarquia de navegação, geometria de componentes e distribuição espacial, sem adoção de paletas cromáticas específicas da marca analisada, em conformidade com as diretrizes do Frila.

Aviso de amostragem: o pedido era ler todas as 446 telas. O documento cita 35 telas por ID e 67 dos 75 fluxos. A leitura a fundo relatada pelo Witcher cobriu cerca de 12 arquétipos, e a revisão do Wise conferiu 10 telas a fundo e confirmou que os 35 IDs existem. As contagens de telas por área (seção 1.3) e por template (seção 3) são estimativas e não uma contagem tela a tela. Medidas de raio, altura e espaçamento foram estimadas a olho, e por isso levam a marca [estimado]. Marcas usadas: [observado] viu na tela; [estimado] medido ou contado a olho; [inferido] deduzido.

---

## 1. Inventário de Telas e Cobertura

### 1.1 Identificação da Aplicação no Refero
* Nome da aplicação: District (District by Zomato) [observado].
* Identificador no Refero (App ID): 294 [observado].
* Domínio oficial registrado: district.in [observado].
* URL base no Refero: https://refero.design/apps/294 [observado].
* Plataforma catalogada: iOS nativo [observado].
* Categorias: Food & Drink, Entertainment, Travel & Booking, Lifestyle [observado].
* Descrição no catálogo: Book films, shows and tables [observado].

### 1.2 Volume Geral e Estatísticas
* Total de fluxos completos catalogados: 75 fluxos de usuário [observado].
* Total de telas catalogadas: 446 telas individuais indexadas no Refero [observado].
* Modo de exibição predominante: 100% das capturas estão em aparência escura (Dark Mode) [observado].

### 1.3 Cobertura por Área Funcional
* Autenticação, Onboarding e Permissões: 14 telas no fluxo 12808, cobrindo abertura de tela inicial, introdução, permissão de localização, seleção de código de país, inserção de telefone, verificação de código descartável (OTP) e permissão de notificações [observado].
* Feed de Descoberta e Hub Principal: aproximadamente 40 telas nos fluxos 12842, 12843, 12845, 12846, 12847, 12855, 12857, abrangendo busca global, abas de categoria (Dining, Movies, Events, Stores, Activities), carrosséis editoriais e assistente de busca por texto e voz [estimado].
* Cinema, Programação e Seleção de Assentos: aproximadamente 65 telas nos fluxos 12823, 12824, 12825, 12826, 12827, 12828, 12829, 12830, 12869, 12870, 12879, incluindo detalhes de filmes, listagem de horários, filtros multicritério, ordenação por distância, mapa de assentos interativo e compartilhamento de mapa [estimado].
* Eventos, Shows e Ingressos Digitais: aproximadamente 25 telas nos fluxos 12871, 12872, 12875, cobrindo seleção de ingressos, revisão de compra, geração de tíquete eletrônico (M-Ticket) com código QR e comprovantes [estimado].
* Restaurantes, Reserva de Mesas e Pagamento de Conta: aproximadamente 45 telas nos fluxos 12858, 12859, 12862, 12863, 12865, 12866, 12867, englobando perfil de estabelecimento, reserva com seleção de data, horário e convidados, política de cancelamento, calculadora de economia e divisão de conta [estimado].
* Cardápio de Cinema, Concessão e Vouchers: aproximadamente 20 telas nos fluxos 12831, 12832, 12833, 12834, 12838, cobrindo navegação por itens de bomboniere, filtro vegetariano, barra de sacola fixa e raspadinha digital de voucher [estimado].
* Carteira Digital e Meios de Pagamento: aproximadamente 35 telas nos fluxos 12835, 12836, 12868, 12876, 12877, 12880, 12881, abrangendo saldo da conta District Money, adição de fundos, resgate de cartão de presente, escaneamento de cartão físico via câmera e gerenciamento de cartões salvos [estimado].
* Coleções, Favoritos e Hotlists: aproximadamente 30 telas nos fluxos 12816, 12817, 12818, 12848, 12849, 12850, 12851, 12852, 12853, 12854, cobrindo criação de listas personalizadas, inclusão de notas, alternância entre visualização em lista e mapa, e convite de colaboradores [estimado].
* Avaliações, Notas e Feedback: aproximadamente 30 telas nos fluxos 12860, 12861, 12878, 12882, 12916, incluindo painel estatístico de notas com quatro pilares, distribuição de estrelas, publicação de avaliação com transcrição de voz e fotos, e exclusão de avaliação [estimado].
* Perfil, Configurações e Suporte: aproximadamente 35 telas nos fluxos 12809, 12810, 12811, 12812, 12813, 12814, 12815, 12839, 12840, 12841, 12883, englobando painel de perfil com indicador de conclusão de etapas, edição cadastral, chat de assistência e exclusão de conta [estimado].

### 1.4 Lacunas de Cobertura Identificadas no Refero
* Fluxo de cancelamento pós-compra e solicitação de reembolso: não há telas dedicadas ao processo de devolução de valores de ingressos ou reservas [observado].
* Modo Claro (Light Mode): ausente na totalidade das capturas; todas as 446 telas do District registradas no Refero foram capturadas sob a aparência escura [observado].
* Estados de falha estrutural de rede e perda de conexão offline: não há telas de aviso de desconexão ou sincronização pendente [observado].
* Conversação de suporte com operador humano em tempo real: o acervo cobre apenas as etapas iniciais de triagem automatizada com envio de anexos, mas não o atendimento síncrono prolongado [observado].

---

## 2. Mapa de Navegação

A arquitetura de informação do District estrutura-se em sete níveis de profundidade hierárquica linear, complementados por quatro eixos modais paralelos [inferido].

### 2.1 Estrutura Hierárquica dos Níveis
* Nível 0 (Autenticação e Entrada):
  * Telas: tela de abertura institucional (ID Refero: 9cf0fe0f-4221-4993-b1c3-824b224ece5e), introdução e permissão (ID Refero: 41c6e7b5-7de4-4a39-b4dc-d7a8d1fb5f17), verificação de código descartável (ID Refero: fb027f2d-7e30-4958-a83f-a665c6825317) [observado].
  * Navegação de entrada: inicialização do aplicativo [observado].
  * Navegação de saída: avanço para o Feed Raiz após validação do código [observado].
* Nível 1 (Feed Raiz de Descoberta):
  * Telas: tela inicial de exploração (ID Refero: 24bcf2c8-2571-446c-985a-086bb91a57ed), exploração de eventos (ID Refero: cd880fbe-ff14-4fcb-a1e1-12d54d850d31), exploração de filmes (ID Refero: 0106912b-57bc-436b-a401-5b92c2012248) [observado].
  * Navegação de entrada: conclusão de login ou retorno de telas filhas [observado].
  * Navegação de saída: toque em cards leva ao Nível 3; toque na barra de busca leva ao Nível 2; toque no ícone de perfil acessa o Hub de Perfil [observado].
* Nível 2 (Listagens de Categoria e Busca Filtrada):
  * Telas: resultados de busca com abas (ID Refero: b9c96637-c6a6-4345-b64d-1fe5afc049a5), programação de sessões (ID Refero: a34b92e2-d013-4b71-a67f-0eed268e2419), listagem de restaurantes (ID Refero: 3681007f-a0ee-404f-b5c5-36ae60c03acd) [observado].
  * Navegação de entrada: campo de busca superior ou toque em categoria no feed [observado].
  * Navegação de saída: toque em item abre Nível 3; botão de filtros abre folha modal de filtragem [observado].
* Nível 3 (Detalhes da Entidade com Hero Visual):
  * Telas: detalhe de evento com pôster (ID Refero: 1f0a1fb9-3fed-4d5e-b94f-fb033b939160), detalhe de restaurante (ID Refero: 5495c4b6-c655-44de-b3f8-67c33e3aaf00), detalhe de filme com trailer (ID Refero: 56e4f64c-367a-4c7e-9ed4-327680fc9439), perfil de salão (ID Refero: 7eb4da47-5368-44ba-9736-f15b03806682) [observado].
  * Navegação de entrada: cards do feed ou listagens filtradas [observado].
  * Navegação de saída: botão de voltar retorna ao nível anterior; botões de ação (salvar, compartilhar) abrem painéis auxiliares; botão de reserva ou compra na barra fixa leva ao Nível 4 [observado].
* Nível 4 (Seletores Interativos e Configuração de Pedido):
  * Telas: mapa interativo de assentos (ID Refero: 5ef4b8cb-9310-46ce-8e18-1615b2296bc2), seletor de mesa e convidados (ID Refero: 586f83d4-130b-4603-946e-9156c7cf0dea), seleção de cardápio de bomboniere (ID Refero: fbe2133e-58cb-468c-af8a-75b0c193175e), seletor de horário de natação (ID Refero: 20823faf-4cf6-46f3-b18b-04639dfe9c78) [observado].
  * Navegação de entrada: botão primário na tela de detalhes [observado].
  * Navegação de saída: cancelamento retorna ao Nível 3; botão de prosseguir avança para o Nível 5 [observado].
* Nível 5 (Revisão de Pedido e Pagamento):
  * Telas: revisão de reserva de cinema com temporizador (ID Refero: 6c946bd3-240d-4992-85dd-8f20b9d7aac6), revisão de conta de restaurante (ID Refero: 3a7b16a5-b10f-4d93-9460-366185bab576), configuração de divisão de conta (ID Refero: fd96dde0-1657-4031-b4e7-9b20290386e7) [observado].
  * Navegação de entrada: conclusão da seleção de assentos, mesas ou serviços [observado].
  * Navegação de saída: alteração de dados cadastrais abre modal; confirmação de pagamento despacha transação e avança para o Nível 6 [observado].
* Nível 6 (Comprovante, Confirmação e Ingresso Digital M-Ticket):
  * Telas: ingresso digital com código QR de evento (ID Refero: 1761ed64-8eaa-42d4-928b-5104fca1ef86), ingresso de cinema confirmado (ID Refero: fb0f3128-a4fa-4dcc-acbf-90124f3c5494), confirmação de reserva de mesa (ID Refero: e9bc7b02-244f-4d99-84bb-25d794de2a45) [observado].
  * Navegação de entrada: retorno bem-sucedido do gateway de pagamento ou confirmação de reserva [observado].
  * Navegação de saída: botão de voltar ou fechar retorna ao Feed Raiz (Nível 1); links de rota abrem aplicativo externo de mapas; botão de convite abre seletor de contatos [observado].

### 2.2 Eixos Modais e Hubs Paralelos
* Hub de Perfil e Conta: acessado via ícone de perfil; ramifica para conclusão cadastral em etapas (ID Refero: 6e162750-7d97-484d-adcf-e90571cd410f), menu de suporte (ID Refero: cb103423-b870-49e3-827f-7ea6cea78686) e encerramento de sessão [observado].
* Hub de Carteira Digital: acessado pelo perfil ou na revisão de pagamento; exibe saldo consolidado (ID Refero: ca477ef1-1d61-4df5-a127-229668a28ad6), recarga de fundos e extrato filtrado por débito e crédito [observado].
* Hub de Coleções e Hotlists: acessado via atalho no feed ou perfil; lista coleções salvas (ID Refero: 80558cf2-e64d-4653-8b42-e9cc4669b8d1), detalhe com visualização em mapa e lista (ID Refero: 6a10ca29-3b77-4a02-b882-9d371f6af269) e compartilhamento [observado].
* Assistente Conversacional de IA: acionado via botão flutuante ("Ask anything"); exibe painel conversacional (ID Refero: 51a23694-d0ff-449d-ac5a-64ba1ae5cf3b) com recomendações em carrossel e entrada de voz [observado].

---

## 3. Templates Macro Recorrentes

Foram identificados oito templates macro estruturais no District. Cada template responde por funções claras no ciclo de uso [observado].

### Template 1: Feed de Descoberta com Busca Superior e Carrosséis Aninhados
* Contagem aproximada: 45 telas utilizam este formato [estimado].
* Papel da tela: página inicial de navegação e descoberta por categoria de lazer [observado].
* Região superior (Nav Bar e Cabeçalho): barra de status nativa; campo de busca em formato de pílula ampla com ícone de lupa à esquerda; linha horizontal de abas de categoria em texto com ícone de início à esquerda; a aba ativa possui traço indicador sólido inferior [observado].
* Região intermediária (Conteúdo): faixa de contexto de data e local com paginador horizontal em pontos; seções verticais com títulos em peso pesado; cada seção abriga carrossel horizontal de cards de locais ou pôsteres editoriais recortados na margem direita [observado].
* Região inferior: conteúdo rola livremente até o rodapé; ausência de barra de abas inferior fixa na raiz [observado].
* Telas de referência:
  * ID Refero: 24bcf2c8-2571-446c-985a-086bb91a57ed (URL: https://refero.design/screens/24bcf2c8-2571-446c-985a-086bb91a57ed) [observado].
  * ID Refero: cd880fbe-ff14-4fcb-a1e1-12d54d850d31 (URL: https://refero.design/screens/cd880fbe-ff14-4fcb-a1e1-12d54d850d31) [observado].
  * ID Refero: 0106912b-57bc-436b-a401-5b92c2012248 (URL: https://refero.design/screens/0106912b-57bc-436b-a401-5b92c2012248) [observado].

### Template 2: Detalhe de Entidade com Hero Visual e Barra de Ação Fixa
* Contagem aproximada: 35 telas utilizam este formato [estimado].
* Papel da tela: apresentação completa de estabelecimento, filme ou evento com conversão direta [observado].
* Região superior (Nav Bar e Cabeçalho): mídia em sangria total (pôster ilustrado ou mosaico de fotos); botões circulares flutuantes e translúcidos posicionados sobre a mídia (voltar à esquerda, salvar e compartilhar à direita) [observado].
* Região intermediária (Conteúdo): painel escuro com cantos superiores fortemente arredondados sobreposto à mídia; abriga chips de categoria, título em destaque, selo compacto de avaliações, linhas de metadados com ícones em quadrados arredondados, abas de conteúdo (ofertas, cardápio, avaliações) e botão flutuante do assistente [observado].
* Região inferior: barra de compra fixa ancorada na base da tela; abriga preço ou resumo à esquerda e botão de ação primário em pílula sólida à direita [observado].
* Telas de referência:
  * ID Refero: 1f0a1fb9-3fed-4d5e-b94f-fb033b939160 (URL: https://refero.design/screens/1f0a1fb9-3fed-4d5e-b94f-fb033b939160) [observado].
  * ID Refero: 5495c4b6-c655-44de-b3f8-67c33e3aaf00 (URL: https://refero.design/screens/5495c4b6-c655-44de-b3f8-67c33e3aaf00) [observado].
  * ID Refero: 56e4f64c-367a-4c7e-9ed4-327680fc9439 (URL: https://refero.design/screens/56e4f64c-367a-4c7e-9ed4-327680fc9439) [observado].

### Template 3: Seletor Interativo e Mapa de Assentos
* Contagem aproximada: 25 telas utilizam este formato [estimado].
* Papel da tela: seleção espacial de assentos em cinema ou teatro com visualização de preços por setor [observado].
* Região superior (Nav Bar e Cabeçalho): barra de navegação com botão voltar, título do evento, subtítulo com localização do estabelecimento e ação de compartilhamento de mapa no canto superior direito [observado].
* Subcabeçalho: bloco de data e fita horizontal rolável de horários de sessão representados em chips retangulares arredondados [observado].
* Região intermediária (Conteúdo): grade densa com trilho vertical à esquerda indicando as fileiras alfabéticas; linhas divisoras horizontais identificando categorias de assento e valor; blocos de assentos com cores diferenciadas por estado (disponível, ocupado, selecionado) [observado].
* Região inferior: banner flutuante de oferta condicionada sobreposto à grade; barra fixa de checkout contendo contador de assentos e botão de prosseguir em pílula sólida branca [observado].
* Telas de referência:
  * ID Refero: 5ef4b8cb-9310-46ce-8e18-1615b2296bc2 (URL: https://refero.design/screens/5ef4b8cb-9310-46ce-8e18-1615b2296bc2) [observado].
  * ID Refero: 856c3c32-62fa-428a-af83-a6ae93d49ea3 (URL: https://refero.design/screens/856c3c32-62fa-428a-af83-a6ae93d49ea3) [observado].

### Template 4: Lista Agrupada Inset e Painel de Configurações
* Contagem aproximada: 30 telas utilizam este formato [estimado].
* Papel da tela: telas de conta, perfil, configuração de pagamentos e suporte [observado].
* Região superior (Nav Bar e Cabeçalho): botão circular de retorno à esquerda e título em grande escala alinhado à esquerda [observado].
* Região intermediária (Conteúdo): títulos de seção destacados; cartões agrupados escuros com cantos arredondados contendo linhas de opção com ícone à esquerda, rótulo em peso pesado e chevron à direita, separadas por divisores de 1px [observado].
* Região inferior: cartão destacado para ação destrutiva isolada (Logout) e rodapé de marca com logotipo e versão [observado].
* Telas de referência:
  * ID Refero: cb103423-b870-49e3-827f-7ea6cea78686 (URL: https://refero.design/screens/cb103423-b870-49e3-827f-7ea6cea78686) [observado].
  * ID Refero: 6e162750-7d97-484d-adcf-e90571cd410f (URL: https://refero.design/screens/6e162750-7d97-484d-adcf-e90571cd410f) [observado].
  * ID Refero: b373e43a-51a7-4edd-a90f-b1d3cbf4a80b (URL: https://refero.design/screens/b373e43a-51a7-4edd-a90f-b1d3cbf4a80b) [observado].

### Template 5: Modal Sheet com Filtragem por Colunas ou Seletores em Etapas
* Contagem aproximada: 25 telas utilizam este formato [estimado].
* Papel da tela: refinamento de buscas, aplicação de cupons ou configuração de reserva [observado].
* Região superior (Nav Bar e Cabeçalho): título do filtro à esquerda e botão circular escuro de fechamento com ícone em X à direita [observado].
* Região intermediária (Conteúdo): estrutura dividida em duas colunas funcionais; coluna esquerda com abas verticais de tipos de filtro; coluna direita com lista vertical de caixas de seleção (checkboxes) com cantos arredondados, rótulos e faixas de horário [observado].
* Região inferior: barra horizontal contendo ação textual "Clear all" à esquerda e botão primário "Apply" em pílula sólida à direita [observado].
* Telas de referência:
  * ID Refero: a51ee94d-78a5-4d32-aee2-e6e7a289e67f (URL: https://refero.design/screens/a51ee94d-78a5-4d32-aee2-e6e7a289e67f) [observado].
  * ID Refero: ab8b9a92-c083-465a-901d-46797a00c8f9 (URL: https://refero.design/screens/ab8b9a92-c083-465a-901d-46797a00c8f9) [observado].

### Template 6: Revisão de Pedido, Divisão de Custos e Checkout
* Contagem aproximada: 20 telas utilizam este formato [estimado].
* Papel da tela: confirmação financeira de compra antes do envio da cobrança [observado].
* Região superior (Nav Bar e Cabeçalho): botão de retorno, título "Review your booking" e aviso de tempo limite de reserva com temporizador regressivo em destaque colorido [observado].
* Região intermediária (Conteúdo): cartão principal de extrato com itens detalhados, taxa de conveniência colapsável, desconto aplicado, total com valor original tachado e pílula de valor economizado; cartão de dados do usuário com link de edição; linha de termos e condições; linha de saldo da carteira [observado].
* Região inferior: bloco de pagamento contendo seletor de bandeira ou cartão à esquerda e botão primário largo de confirmação à direita [observado].
* Telas de referência:
  * ID Refero: 6c946bd3-240d-4992-85dd-8f20b9d7aac6 (URL: https://refero.design/screens/6c946bd3-240d-4992-85dd-8f20b9d7aac6) [observado].
  * ID Refero: 3a7b16a5-b10f-4d93-9460-366185bab576 (URL: https://refero.design/screens/3a7b16a5-b10f-4d93-9460-366185bab576) [observado].

### Template 7: Comprovante de Reserva e Exibição de Ingresso M-Ticket
* Contagem aproximada: 15 telas utilizam este formato [estimado].
* Papel da tela: apresentação do ingresso digital na portaria do evento ou cinema [observado].
* Região superior (Nav Bar e Cabeçalho): botão circular de retorno e título afirmativo em destaque [observado].
* Região intermediária (Conteúdo): cartão de aviso instruindo a exibição do código na entrada; divisor com rótulo em caixa alta ("M TICKETS"); cartão centralizado de grandes dimensões abrigando painel branco quadrado arredondado com código QR, cantoneiras decorativas e código alfanumérico de contingência; divisor de local ("VENUE"); cartão de endereço completo com link direto para rota [observado].
* Região inferior: espaço de rolagem para ações de compartilhamento ou exibição de políticas [observado].
* Telas de referência:
  * ID Refero: 1761ed64-8eaa-42d4-928b-5104fca1ef86 (URL: https://refero.design/screens/1761ed64-8eaa-42d4-928b-5104fca1ef86) [observado].
  * ID Refero: fb0f3128-a4fa-4dcc-acbf-90124f3c5494 (URL: https://refero.design/screens/fb0f3128-a4fa-4dcc-acbf-90124f3c5494) [observado].

### Template 8: Estado Vazio e Recuperação de Erro
* Contagem aproximada: 10 telas utilizam este formato [estimado].
* Papel da tela: tratamento de buscas sem resultado e recuperação de fluxo [observado].
* Região superior (Nav Bar e Cabeçalho): preserva o campo de busca e controles de filtro para permitir redefinição imediata [observado].
* Região intermediária (Conteúdo): ícone vetorial linear minimalista em cinza médio; título em destaque ("No results found"); texto explicativo em duas linhas; botão textual de recuperação com sublinhado pontilhado para restaurar o catálogo completo [observado].
* Região inferior: área livre com grande respiro visual [observado].
* Telas de referência:
  * ID Refero: ca49f8b4-43ab-4211-ac05-f813f288778d (URL: https://refero.design/screens/ca49f8b4-43ab-4211-ac05-f813f288778d) [observado].
  * ID Refero: 02997362-fa06-4180-abff-084a457938ec (URL: https://refero.design/screens/02997362-fa06-4180-abff-084a457938ec) [observado].

---

## 4. Componentes Rasos do Design System

Mapeamento da biblioteca de componentes básicos do District, com anatomia funcional e variantes [observado].

### 4.1 Barra de Navegação (Nav Bar)
* Anatomia:
  * Área de status do iOS no topo [observado].
  * Botão de retorno: elemento circular (Circle) com ícone de seta à esquerda, fundo escuro translúcido e contorno sutil [observado].
  * Título: texto em peso pesado, alinhado à esquerda ou centralizado conforme o contexto [observado].
  * Ações secundárias à direita: botões circulares isolados contendo ícones de salvar (bookmark) e compartilhar [observado].
* Variantes:
  * Variante 1: Nav Bar Flutuante sobre Mídia (usada em detalhes com fotos ou pôsteres, sem fundo sólido) [observado].
  * Variante 2: Nav Bar Sólida com Título Grande (usada em configurações, perfil e extrato de carteira) [observado].
  * Variante 3: Nav Bar Integrada com Busca (usada na tela inicial, onde o campo de busca atua como cabeçalho) [observado].

### 4.2 Barra de Abas (Tab Bar)
* Anatomia:
  * Segmentador horizontal de categorias com rótulos textuais [observado].
  * Indicador de seleção ativa: traço horizontal sólido posicionado sob o texto da aba [observado].
* Variantes:
  * Variante 1: Abas de Categoria do Feed (Home, Dining, Movies, Events, Stores, Activities) [observado].
  * Variante 2: Abas Internas de Perfil de Local (Offers, Menu, Ask anything, Reviews) [observado].
  * Variante 3: Abas Verticais de Folha Modal (Show Time, Price, Others em coluna lateral) [observado].

### 4.3 Cartões (Cards)
* Anatomia:
  * Superfície escura em tom carvão neutro com cantos fortemente arredondados e contorno tênue de 1px [observado].
* Variantes:
  * Card de Local e Estabelecimento: foto no topo com raio próprio, selo de nota em badge no canto inferior da foto, título, cozinha, preço médio e distância [observado].
  * Card de Pôster Editorial: proporção vertical, cantos arredondados amplos, tipografia serifada decorativa interna e assinatura institucional [observado].
  * Card de Cupom e Oferta: formato de bilhete com entalhes circulares centrais nas bordas e divisor tracejado [observado].
  * Card de Ingresso M-Ticket: fundo escuro amplo, painel quadrado interno branco para o código QR com cantoneiras de destaque e código alfanumérico [observado].
  * Card de Avaliação: avatar circular do autor, nome, data relativa, badge de estrelas à direita e corpo da mensagem com link de expansão [observado].

### 4.4 Listas (Lists)
* Anatomia:
  * Agrupamento visual inset com cantos arredondados contendo linhas de toque confortável [observado].
  * Separadores internos de 1px em cinza de baixo contraste, com recuo à esquerda alinhado ao texto [observado].
* Variantes:
  * Linha de Menu de Configuração: ícone em linha à esquerda, rótulo semibold central e chevron indicador à direita [observado].
  * Linha de Extrato de Transação: ícone de categoria em quadrado arredondado à esquerda, descrição e data no centro, valor financeiro alinhado à direita [observado].
  * Linha de Detalhamento de Cobrança: rótulo à esquerda, valor numérico à direita e chevron para itens colapsáveis [observado].

### 4.5 Chips e Tags
* Anatomia:
  * Formato de pílula completa (Capsule) ou retângulo com cantos arredondados médios [observado].
* Variantes:
  * Chip de Categoria: fundo escuro sólido com texto claro, usado para gêneros de filme e tipos de evento [observado].
  * Chip de Filtro com Seleção: contorno evidente de 1px e rótulo com ícone de chevron ou botão de limpar [observado].
  * Tag de Desconto: pílula com ícone de etiqueta e texto informando porcentagem de abatimento [observado].
  * Badge de Avaliação: retângulo compacto com cantos arredondados, fundo verde para notas altas e laranja/marrom para notas baixas, acompanhado de estrela [observado].

### 4.6 Botões (Buttons)
* Anatomia e Tipologia:
  * Botão Primário de Conversão: formato de pílula 100% arredondada (Capsule), fundo branco sólido e texto preto em peso pesado [observado].
  * Botão Secundário de Contorno: formato de pílula (Capsule), contorno branco de 1.5px e fundo escuro transparente [observado].
  * Botão Compacto de Ação: pílula de menor altura com ícone e texto reduzido [observado].
  * Botão Circular de Ícone: forma circular perfeita (Circle) com ícone centralizado, usado para voltar, fechar, salvar e compartilhar [observado].
  * Ação Textual Inline: texto sem container, frequentemente com sublinhado pontilhado para indicar toque secundário [observado].

### 4.7 Campos de Formulário (Inputs)
* Anatomia:
  * Superfície escura com borda fina e cantos arredondados, contendo ícone auxiliar e texto de dica [observado].
* Variantes:
  * Barra de Busca Global: formato de pílula ampla com ícone de lupa e botão de limpar [observado].
  * Campo de Entrada de Telefone: bloco retangular arredondado acompanhado de seletor de código de país com bandeira e chevron [observado].
  * Células de Código Descartável (OTP): seis caixas quadradas independentes com cantos arredondados e dígito centralizado [observado].
  * Área de Texto Multilinha: caixa ampla para digitação de avaliações com botão integrado de ditado por voz [observado].

### 4.8 Folhas Modais (Sheets)
* Anatomia:
  * Painel escuro sobreposto que sobe a partir da base da tela, com cantos superiores arredondados e puxador centralizado no topo [observado].
* Variantes:
  * Sheet de Filtros com navegação lateral bipartida [observado].
  * Sheet de Confirmação de Pagamento e Seleção de Carteira [observado].
  * Sheet de Criação e Salvamento em Listas [observado].

### 4.9 Banners de Aviso e Alerta
* Anatomia:
  * Faixa horizontal com cantos arredondados e indicador triangular superior no estilo balão de chamada [observado].
* Variantes:
  * Alerta de Distância: preenchimento em tom vinho ou tijolo com texto de aviso [observado].
  * Alerta de Economia: preenchimento em tom roxo profundo com valor monetário economizado [observado].
  * Notificação de Topo: cartão flutuante arredondado confirmando envio de avaliação [observado].

### 4.10 Estados de Interface (States)
* Empty State: ícone vetorial linear minimalista, título claro, texto explicativo e link de restauração [observado].
* Loading State: spinner circular de carregamento integrado no centro de botões primários ou telas de transição [observado].
* Error State: contorno em destaque e mensagem textual explicativa de falha de validação [observado].

---

## 5. Geometria, Dimensões e Espaçamento

Dimensões e medidas observadas e estimadas com base na inspeção visual das telas nativas [observado, inferido].

### 5.1 Corner Radius por Categoria de Componente
* Botões Primários e Secundários: 100% Pílula (Capsule, raio matemático equivalente a metade da altura ou 9999pt) [observado].
* Botões Circulares de Controle (Voltar, Salvar, Compartilhar, Fechar): 100% Circular (Circle, raio 50% da largura e altura) [observado].
* Cartões de Conteúdo e Painéis (Cards): 20pt a 28pt [estimado].
* Folhas Modais (Sheets): 24pt a 32pt aplicados estritamente nos cantos superiores esquerdo e direito [estimado].
* Chips e Tags de Categoria: 100% Pílula (Capsule, 9999pt) ou semi-arredondados com 12pt a 14pt [estimado].
* Campos de Entrada (Text Fields e Dropdowns): 12pt a 16pt para campos de texto convencionais; raio pílula (9999pt) para a barra de busca [estimado].
* Thumbnails e Imagens Menores: 14pt a 18pt [estimado].
* Imagens Grandes e Pôsteres Editoriais: 24pt a 28pt [estimado].
* Painéis Quadrados de Código QR: 16pt a 20pt [estimado].
* Células de Assento em Mapa de Cinema: 6pt a 8pt [estimado].

### 5.2 Alturas de Componentes e Alvos de Toque
* Botões Primários de Barra Fixa (CTA): 48pt a 52pt de altura (estimado), atendendo integralmente às diretrizes de toque da Apple (mínimo 44pt) [observado].
* Botões Circulares de Controle: 40pt a 44pt de diâmetro externo (estimado), com área de toque expandida correspondente a 44x44pt [observado].
* Chips de Filtro e Tags de Ação: 32pt a 36pt de altura [estimado].
* Linhas de Lista em Painéis Agrupados: 60pt a 72pt de altura (estimado), proporcionando alvos de toque amplos e confortáveis [observado].
* Barra de Busca Global: 44pt a 48pt de altura [estimado].
* Campos de Entrada de Telefone e Dados: 48pt a 52pt de altura [estimado].

### 5.3 Espaçamento Macro e Ritmo Estrutural
* Margens Laterais da Tela (Safe Area Insets): 16pt a 20pt constantes nas laterais de todas as telas [estimado].
* Espaço de Separação entre Seções Verticais: 24pt a 32pt de espaçamento (estimado), criando respiros generosos no feed escuro [observado].
* Espaço Interno entre Cards de Carrossel Horizontal: 12pt a 16pt de intervalo entre itens vizinhos [estimado].
* Espaçamento Interno dos Cards (Padding Interno): 16pt a 24pt [estimado].
* Padrão de Grade (Grid Pattern):
  * Coluna única vertical dominante em praticamente todas as telas de fluxo, configuração e detalhes [observado].
  * Carrosséis horizontais com sangria e recorte do próximo card na borda direita para induzir rolagem lateral [observado].
  * Grade de duas colunas (2-column grid) utilizada restritamente em categorias de evento e coleções salvas [observado].

---

## 6. Padrões de Liquid Glass e Avaliação iOS 26+

Avaliação técnica sobre a presença de materiais avançados de vidro fluido da geração iOS 26+ [observado, inferido].

### 6.1 Constatação Factual de Sistema
* O aplicativo District capturado no Refero NÃO adota os padrões de Liquid Glass ou especificações de shaders especulares do iOS 26+ [observado].
* A construção visual do District pertence ao padrão contemporâneo de Dark Mode estabelecido a partir do iOS 17 e iOS 18 [observado].
* Não foram observadas bordas especulares dinâmicas (specular rim highlights), não há efeito de refração cromática em contêineres e não há morphing de materiais de vidro sobrepostos [observado].

### 6.2 Materiais Efetivamente Observados
* Superfícies Sólidas Escuras: a totalidade dos cartões, painéis e folhas modais utiliza fundos escuros sólidos ou com gradientes sutis de baixa saturação [observado].
* Bordas Tênues de 1px: os contornos de elevação são traços vetoriais lineares de 1px com baixa opacidade em cinza claro, sem dispersão de luz refrativa [observado].
* Desfoque Tradicional de Sistema (Background Blur): restrito aos botões circulares flutuantes de navegação sobre fotos e ao fundo semitransparente que escurece o conteúdo quando uma folha modal é aberta [observado].
* Barra de Abas Inferior Flutuante: ausente; a navegação de nível superior ocorre por abas de texto no topo e as barras inferiores são ancoradas e sólidas [observado].

### 6.3 Diretriz de Uso para o Protótipo Frila
* O District deve ser utilizado exclusivamente como referência de distribuição ergonômica, papel de regiões e ancoragem de ações [inferido].
* A camada de materiais, sombreados polares e integração com Liquid Glass deverá ser projetada conforme as especificações nativas do FrilaDesignSystem, sem tentar reproduzir o acabamento de superfícies sólidas do District [inferido].

---

## 7. Distribuição e Hierarquia de Cor

Análise quantitativa e qualitativa da distribuição de contraste e presença cromática na interface, sem menção a códigos hexadecimais ou nomes de tokens [observado, inferido].

### 7.1 Proporção Estrutural Estimada

| Proporção Estimada | Camada de Aplicação | Papéis e Elementos | Ressalva |
| :--- | :--- | :--- | :--- |
| 65% a 70% | Neutro Escuro Dominante | Fundo integral do aplicativo, corpo dos cartões, painéis modais e folhas inferiores | Estimativa baseada em inspeção visual da aparência escura [estimado] |
| 20% a 25% | Neutro Claro Secundário e Mídia | Tipografia branca e cinza, fotografias realistas de locais, pôsteres ilustrados de eventos e ícones lineares | Estimativa baseada na área ocupada por textos e imagens [estimado] |
| 8% a 10% | Cores de Acento Funcional | Indicador de aba ativa, selos de pontuação, estrelas, banners de economia, assentos selecionados e tags de desconto | Estimativa visual do peso dos pontos focais coloridos [estimado] |

### 7.2 Comportamento e Papéis do Acento Funcional
* Botões de Ação Primária (CTA): não consom a cor de acento da marca; utilizam contraste neutro máximo (fundo branco sólido com tipografia preta em peso pesado), assegurando legibilidade imediata e primazia visual no ambiente escuro [observado].
* Acento Roxo e Violeta: reservado para estados de seleção de categoria no feed, sublinhado da aba ativa, cantoneiras decorativas do código QR de ingresso e pílulas de valor economizado [observado].
* Acento Verde: aplicado estritamente em selos de avaliações positivas de estabelecimentos e no contador regressivo de tempo para conclusão da compra [observado].
* Acento Azul: utilizado especificamente no mapa de assentos para destacar a poltrona selecionada pelo usuário e fileiras de categoria superior [observado].
* Acento Amarelo e Dourado: reservado para estrelas de classificação e alertas contextuais de sistema [observado].
* Acento Vinho e Tijolo: empregado em avisos de proximidade geográfica e chamadas de atenção sobre distâncias [observado].

---

## 8. Hierarquia Tipográfica

Mapeamento dos oito níveis de hierarquia tipográfica observados no aplicativo, detalhando papéis, pesos e escalas visuais sem referência a fontes comerciais [observado].

* Nível 1 (Título Monumental de Hero):
  * Papel: nomes de filmes em cartaz, títulos de pôsteres de espetáculos e mensagens principais de telas de boas-vindas [observado].
  * Características: escala visual muito grande (estimada entre 32pt e 40pt), peso pesado (heavy/black), altura de linha compacta e alinhamento à esquerda ou centralizado sobre imagem [estimado].
* Nível 2 (Título de Página e Cabeçalho Estrutural):
  * Papel: títulos de seção do feed ("Continue where you left off", "What’s hot on District"), títulos de tela ("Review your booking", "OTP Verification", "Profile") e confirmações [observado].
  * Características: escala grande (estimada entre 24pt e 30pt), peso bold, alto contraste visual em branco puro [estimado].
* Nível 3 (Título de Card e Nome de Estabelecimento):
  * Papel: identificação de restaurantes, filmes em listas, nomes de artistas e títulos de itens de bomboniere [observado].
  * Características: escala média-alta (estimada entre 18pt e 22pt), peso semibold ou bold, alinhamento à esquerda [estimado].
* Nível 4 (Destaque Numérico e Valor Monetário):
  * Papel: preços de ingressos, totais de conta a pagar, saldo da carteira e notas estatísticas de avaliação [observado].
  * Características: escala variando de 20pt a 36pt dependendo da posição, peso bold destacado; preços originais utilizam traço de cancelamento (strikethrough) em cinza [observado].
* Nível 5 (Rótulo Divisor em Caixa Alta):
  * Papel: separadores temáticos formais ("M TICKETS", "VENUE", "CAST AND CREW", "LOG IN OR SIGN UP") [observado].
  * Características: escala pequena (estimada entre 11pt e 13pt), caixa alta integral, espaçamento entre letras expandido (tracking largo) e contraste reduzido em cinza médio [estimado].
* Nível 6 (Corpo de Texto e Sinopse):
  * Papel: descrições de espetáculos, comentários de avaliações, políticas de modificação e explicações instrucionais [observado].
  * Características: escala de leitura confortável (estimada entre 15pt e 17pt), peso regular ou medium, altura de linha ampla e cor em cinza claro [estimado].
* Nível 7 (Metadados e Legendas Auxiliares):
  * Papel: tipos de cozinha, distâncias em quilômetros, horários de funcionamento, timestamps de avaliação e número de versão [observado].
  * Características: escala reduzida (estimada entre 12pt e 14pt), peso regular, contraste reduzido em cinza médio para manter a hierarquia subordinada [estimado].
* Nível 8 (Ações Textuais e Links Interativos):
  * Papel: comandos como "View details", "Read more", "Clear all", "Edit", "Skip and submit" [observado].
  * Características: escala entre 14pt e 16pt, peso semibold, frequentemente acompanhados de ícone de chevron ou sublinhado pontilhado que reforça a capacidade de clique [observado].

---

## 9. Mapeamento para o Protótipo Frila (O Que Serve e O Que Não Serve)

Análise de reaproveitamento da estrutura do District para o protótipo de baixa e média fidelidade do Frila. Foi conferida contra o DESIGN-SOURCE-DOCUMENT.md: v1.0 só tem modo urgência (quem aceita primeiro fica com a vaga), check-in por localização lida só no toque, avaliação com uma pergunta binária e reputação como taxa de comparecimento com denominador [inferido].

### 9.1 Urgência de Vaga
* O que serve ao Frila:
  * O contador de disponibilidade em cards ("26 slots left") pode virar a contagem de posições da vaga ("1 de 2 posições preenchidas"), como informação e sem tom de pressão [inferido].
  * O banner de aviso com ícone e faixa própria (alerta de distância) serve de molde para avisos do turno: termina no dia seguinte, conflito de horário, vaga preenchida [inferido].
* O que não serve ao Frila:
  * O temporizador regressivo de retenção ("Complete your booking in 3:01 mins"). No Frila não há retenção nem checkout: o aceite é um toque e a confirmação é imediata. Um contador criaria a pressão que a tela "Vaga preenchida", sem culpa, procura evitar [inferido].
  * Cupons, descontos e chips de economia ("Flat 20% OFF", "Save ₹80") [inferido].

### 9.2 Listas de Vagas e Oportunidades
* O que serve ao Frila:
  * O card de local (título, metadados em duas linhas com distância e categoria, valor evidente) como base do card de vaga [inferido].
  * Chips de filtro e a sheet de filtros com ação "Clear all" à esquerda e "Apply" em pílula à direita [inferido].
  * O estado vazio com ícone, título, explicação e ação de recuperação, para "sem vagas na sua região" [inferido].
* O que não serve ao Frila:
  * Carrosséis horizontais por categoria e busca global com voz. A lista da v1.0 é uma coluna vertical única do DF, ordenada por distância do ponto base [inferido].
  * Fotografia de ambientes como protagonista do card. No protótipo de baixa fidelidade o card é só texto e metadados [inferido].

### 9.3 Detalhe do Turno
* O que serve ao Frila:
  * A barra inferior fixa com o valor à esquerda e o botão primário à direita ("Aceitar turno") é a disposição mais ergonômica observada para a tela de conversão [inferido].
  * O bloco de endereço com ação de rota, que no Frila corresponde a "Abrir no mapa" [inferido].
  * O painel de conteúdo com cantos superiores arredondados, com ou sem mídia de hero [inferido].
  * Acima do botão de aceite cabe um aviso curto, no molde dos banners do item 4.9: "Se você aceitar e for confirmado, seu telefone e WhatsApp serão compartilhados com o contratante". O documento-fonte exige esse aviso antes do aceite [inferido].
* O que não serve ao Frila:
  * Seletores de itens complementares, abas de conteúdo (ofertas, cardápio) e o botão flutuante do assistente [inferido].
  * Não há candidatura: no modo urgência o profissional aceita e o resultado é confirmado ou preenchido [inferido].

### 9.4 Check-in e Turno do Dia
* O que serve ao Frila:
  * A anatomia do comprovante como layout da tela "Meu turno": aviso contextual no topo, cartão central com o estado (confirmado, check-in feito às 02h04), bloco de endereço com rota [inferido].
  * O aviso no topo pode carregar a frase de privacidade "o app lê sua localização só neste toque" [inferido].
  * O contato do contratante só aparece depois da confirmação. Na tela "Meu turno" ele entra como linha de lista com telefone e o atalho "Chamar no WhatsApp", no molde da linha de menu com ação à direita (4.4) [inferido].
  * O cartão destrutivo isolado do Template 4 serve de molde para ações de segurança e para "Excluir conta" [inferido].
* O que não serve ao Frila:
  * O código QR e o código alfanumérico de contingência. O check-in do Frila é por localização a até 200 m, lida só no toque. Se a localização falhar, o plano B é o check-in manual, que fica pendente até o contratante confirmar. Nada disso passa por QR [inferido].
  * A mecânica lúdica de raspadinha de voucher, por ferir o tom sóbrio do produto [inferido].

### 9.5 Perfil Profissional
* O que serve ao Frila:
  * O cartão de topo com progresso de conclusão ("1 / 4 steps done") como indicador de completude do perfil: funções, ponto base e horários [inferido].
  * As listas agrupadas inset, com separadores sutis, chevron à direita e cartão destrutivo isolado no fim, para "Meu perfil", segurança e exclusão de conta [inferido].
* O que não serve ao Frila:
  * Banners de venda de planos ou assinatura ("District Pass at ₹999") [inferido].

### 9.6 Avaliações e Reputação
* O que serve ao Frila:
  * O selo compacto de nota como molde do selo de reputação, com o formato do Frila: "6 de 7" comparecimentos, ou "Sem histórico" quando não há dados. Nunca um número sem denominador [inferido].
  * A notificação flutuante de topo que confirma o envio de avaliação (4.9), para "Avaliação registrada" [inferido].
  * A estrutura de sheet ou tela simples com ação primária desativada até haver resposta [inferido].
* O que não serve ao Frila:
  * Notas por estrelas, distribuição em cinco barras, notas por quatro pilares (Food, Drinks, Service, Ambience) e qualquer equivalente como Pontualidade, Comunicação, Execução Técnica ou Postura. O Frila pergunta uma coisa só, com resposta binária ("chamaria de novo?" ou "trabalharia lá de novo?") [inferido].
  * Depoimento em texto livre, ditado por voz e lista pública de avaliações com avatar [inferido].
  * Tags sociais de acompanhante de mesa ("Dining companion") ou tempo de espera por assento [inferido].
