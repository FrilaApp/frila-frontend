# Histórico de versões do Frila para iOS

O que muda para quem usa o app, da versão mais nova para a mais antiga. A data de cada versão é a
da tag correspondente no repositório (`v1.0.0`, e assim por diante).

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

### Para quem contrata
- Cadastro do estabelecimento com o ponto marcado no mapa e a região administrativa (#99, #242).
- Publicação de vagas, no primeiro acesso e a partir de Minhas vagas, com reenvio que não duplica
  a vaga (#100).
- Minhas vagas, com o painel do estabelecimento (#107).
- Acompanhamento do turno: confirmar a presença de quem fez check-in manual e reabrir a vaga
  quando o profissional atrasa 15 minutos (#19).

### Em todo o app
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
