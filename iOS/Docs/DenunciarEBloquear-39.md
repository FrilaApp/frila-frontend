# Denunciar e bloquear — cartão #39, parte 1

## Inventário anterior

- `TelaDetalheVaga.swift` reservava os botões Denunciar e Bloquear, desabilitados.
- `Portas.swift`, `Modelos.swift`, `DTOsContrato.swift` e `SupabaseApiCliente.swift` já implementavam os pedidos e respostas. `ContratoDaSprint2Tests.swift` e `RpcsDaSprint2EmMemoriaTests.swift` já cobriam RPCs, motivos, validação, idempotência e efeito do bloqueio nas vagas.
- `MinhasVagas.swift` mostrava o perfil do confirmado a partir de dados do painel, sem consultar `perfil_publico` e sem ações. Não havia acesso ao perfil público do estabelecimento no detalhe profissional.
- `ApiClienteEmMemoria.perfilPublico` ainda respondia após bloquear, comportamento da versão 0.2.27. O contrato local, em `Contrato/openapi.yaml`, seção 0.2.28 e `/rpc/perfil_publico`, exige 404.

## Implementação

O rodapé do detalhe profissional e os perfis públicos dos dois lados usam `AcoesDeSeguranca`. A folha exige relato com pelo menos 10 caracteres após remover espaços nas extremidades e oferece os quatro motivos do contrato. Risco à segurança mostra a orientação e atalhos telefônicos antes do envio. O sucesso mostra o UUID do protocolo e a data civil devolvida, sem calcular um prazo no aparelho.

Repetir um envio sem editar o formulário conserva a chave após perda de resposta. Editar o corpo cria uma chave nova. Enquanto envia, o formulário e o fechamento ficam desabilitados; dois toques não criam duas chamadas. Falha de rede ou validação mantém o relato.

Bloquear exige confirmação. Só o sucesso registra o alvo em `BloqueiosDaSessao`, que vive no fluxo da conta. O feed filtra imediatamente as vagas do estabelecimento, inclusive respostas antigas; a contagem original da página é preservada para a paginação. Minhas vagas esconde o nome e acesso ao perfil/contato bloqueado, conservando a posição. A seção de candidatos no detalhe também esconde o perfil bloqueado. A nova tela pública consulta a API e trata 404 como “Perfil indisponível”, sem expor a razão. O dublê segue a versão 0.2.28 para essa leitura.

As ações têm rótulo textual, identificador e altura mínima dos componentes existentes. A confirmação da denúncia move o foco de acessibilidade para o resultado. Testes de interface conferem a árvore de acessibilidade, os rótulos e o alcance por toque; não substituem uma escuta manual com VoiceOver ligado.

Ficam fora desta parte os rodapés de Meu turno e do turno do contratante, seus view models, a fila offline e a aba Candidaturas, conforme a missão. Nenhuma mudança de contrato.

## Textos para validação do Cauê

Textos provisórios em `TextosDaSeguranca.swift`, via `bundleApresentacao`, com entradas no catálogo pt-BR. Incluem textos reutilizados:

- Denunciar
- Bloquear
- Bloquear este perfil?
- Vocês não voltam a se cruzar em notificações, listas ou candidaturas. O bloqueio vale para todo o estabelecimento.
- Cancelar
- Fechar
- Motivo da denúncia
- Relato
- O relato deve conter pelo menos 10 caracteres.
- Enviar denúncia
- Em risco imediato, ligue 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher)
- Ligar 190 — Polícia Militar
- Ligar 180 — Central de Atendimento à Mulher
- Denúncia enviada
- Número do protocolo
- Resposta por e-mail até
- Perfil público
- Ver perfil público
- Perfil indisponível
- Tentar novamente
- Não foi possível concluir esta ação. Tente novamente.
- Sem conexão. Verifique sua internet e tente novamente.
- Não foi possível enviar estes dados. Confira as informações e tente novamente.
- Assédio
- Discriminação
- Risco à segurança
- Outro

## Verificação

- `SegurancaViewModelTests`: relato válido/inválido, motivos, resposta/protocolo, 422, sem rede, mesma chave no reenvio, nova chave após edição, toque duplo, bloqueio recusado, filtro imediato e de resposta antiga, 404 e falha de perfil.
- `SegurancaUITests`: denúncia no detalhe, emergência antes de enviar, protocolo/prazo, cancelamento e confirmação do bloqueio, remoção sem reinício e ações nos dois perfis públicos.
- Resultado consolidado e comandos: descrição do PR.
