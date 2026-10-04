# Histórico de versões do Frila para iOS

O que muda para quem usa o app, da versão mais nova para a mais antiga. A data de cada versão é a
da tag correspondente no repositório (`v1.0.0`, e assim por diante).

## 03–04/10/2026 (preparação para os builds 0.4 e 0.5 do TestFlight)

Novidades integradas a partir de 45 PRs no ciclo preparatório para testes externos no DF:

### Para quem trabalha
- **Cancelamento com justificativa:** cancelamento de turno com motivos predefinidos ou justificativa livre, aviso claro de falta a menos de 24 h e recolhimento de teclado na barra para telas pequenas (#20, #92, #117, #128).
- **Segurança nos turnos:** botões Denunciar e Bloquear disponíveis no rodapé de Meu turno, com exibição de telefones de emergência (190 e 180) e geração de número de protocolo (#39, #116).
- **Ajuda no turno:** botão no rodapé que abre e-mail de suporte pré-preenchido com os identificadores do turno (#21, #131).
- **WhatsApp sem conexão:** telefone de contato e botão do WhatsApp permanecem acessíveis no detalhe do turno mesmo em modo avião ou sem conexão à internet (#10, #133).
- **Histórico e exportação:** consulta a turnos anteriores por período (mês atual, mês passado ou datas personalizadas) e exportação nativa de relatórios em PDF ou planilha CSV (#23, #106, #129).

### Para quem contrata
- **Avaliação do profissional:** após o término do turno com presença confirmada, resposta objetiva de Sim ou Não à pergunta "Chamaria este profissional de novo?" (#22, #126).
- **Cancelamento de vaga ou posição:** cancelamento de posições individuais ou da vaga inteira com seleção de motivo obrigatório (#20, #93, #117).
- **Segurança e ajuda no turno:** suporte dedicado ("Ajuda no turno"), denúncia e bloqueio também no rodapé do acompanhamento do turno (#116, #131).
- **Histórico do estabelecimento:** exportação de relatórios de turnos em PDF e CSV diretamente pelo perfil do negócio (#23, #106).
- **Rolagem fluida:** lista de vagas em Minhas vagas otimizada com carregamento sob demanda (`LazyVStack`) para suportar alto volume de registros (#127).

### Em todo o app e acessibilidade
- **Contestação de suspensão:** formulário de contestação habilitado e pré-preenchido com o identificador da conta caso ocorra suspensão (#105, #121).
- **Adaptação para iPhone SE e texto ampliado (AX5):** botão Cancelar visível no topo da confirmação de exclusão de conta em Dynamic Type gigante, seletor de formatos em pílulas escaláveis no histórico, e teclado que não encobre botões essenciais (#128, #129).
- **Tratamento de conexão indisponível:** aviso claro de falha de conexão cobrindo variações de instabilidade de rede (#130).

## 1.0.0 (em preparação, ainda sem tag)

Primeira versão da App Store. Atende o Distrito Federal.

### Entrada e conta
- Entrada por código de seis dígitos enviado ao e-mail, e escolha do perfil no primeiro acesso (#97).
- Perfis de conta e reputação: quantas pessoas chamariam de novo e a taxa de comparecimento (#54).
- A sessão é encerrada no aparelho quando o servidor recusa a autenticação.

### Para quem trabalha
- Lista de vagas do DF com filtros por função, data e distância, e o detalhe de cada vaga (#104).
- Candidatura à vaga, com o resultado mostrado na hora (#105).
- Perfil profissional com funções, ponto base e grade semanal de horários (#98).
- Meus turnos, com o detalhe do turno e o contato liberado (#109).
- Check-in e check-out com a localização lida só no toque, e check-in manual quando não dá para
  confirmar pelo GPS (#17).
- Avaliação de sim ou não depois do turno (#22).
- Cancelar o turno em Meu turno, com motivo obrigatório e o aviso de que a menos de 24 h o
  cancelamento conta como falta; sem rede, o cancelamento espera na fila e sai quando a internet
  volta (#20).

### Para quem contrata
- Cadastro do estabelecimento com o ponto marcado no mapa e a região administrativa (#99, #242).
- Publicação de vagas, no primeiro acesso e a partir de Minhas vagas, com reenvio que não duplica
  a vaga (#100).
- Minhas vagas, com o painel do estabelecimento (#107).
- Acompanhamento do turno: confirmar a presença de quem fez check-in manual e reabrir a vaga
  quando o profissional atrasa 15 minutos (#19).
- Cancelar uma posição no painel do turno ou a vaga inteira em Minhas vagas, com motivo
  obrigatório e o aviso de que a posição volta a ser oferecida antes do início e fica descoberta
  depois dele (#20).

### Em todo o app
- Notificações de vaga nova, confirmação, lembretes do turno, check-in, atraso e cancelamento. O
  toque abre a tela do aviso, e a permissão só é pedida depois de uma explicação (#8).
- Funciona sem conexão: o que já foi carregado continua visível, e as ações ficam na fila até a
  rede voltar (#111).
- Acessibilidade: alvos de toque do tamanho mínimo e leitura nos maiores tamanhos de texto (#139).
- Licenças das bibliotecas de código aberto usadas pelo app (#178).
- Relato automático de falhas, sem dados pessoais (#198).

### Privacidade e conformidade
- A localização é pedida só durante o uso. No check-in e no check-out, a coordenada lida do GPS
  não sai do aparelho: só a distância até a vaga é enviada.
- Os pontos escolhidos no mapa (o ponto base de quem trabalha e o ponto do estabelecimento) são
  enviados ao servidor.
- O app não rastreia e não pede permissão de rastreamento.
- O manifesto de privacidade declara os dados da conta e o uso de `UserDefaults` (#96).
- O build de Release não leva catálogo de componentes nem atalhos de desenvolvimento (#96).
