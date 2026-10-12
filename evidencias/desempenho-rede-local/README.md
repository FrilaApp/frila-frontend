# Prova local de desempenho e rede — cartão #73

Execução em 11/10/2026, 23h09–23h10 (Brasília), pelo `xcb.sh`, na branch
`test/ios-desempenho-rede-local`, baseada em `cac7bc0`. Antes do PR, integrada a main
`13c9ec3`, cuja diferença é somente documentação de ECA e LGPD.

O ambiente e os resultados vêm do xcresult: simulador Homem-Aranha, iPhone 17, iOS 26.5
(build 23F77), UDID `85940BCB-553C-4145-8F8E-E83423D86431`, esquema Frila-Local.

- `resumo-local.json`: 19 aprovados, zero falhas, zero pulos.
- `testes-locais.json`: 11 testes de medição, 7 de modo avião e 1 de interface.
- `modo-aviao.json`: resultado do turno confirmado após encerrar e reabrir o app sem rede;
  mantém dados e contato, destino do WhatsApp e check-in na fila local.
- `xcb-trecho.log`: saída do contador real e resultados dos testes.

O teste novo chama o cliente Supabase contra um dublê HTTP em 127.0.0.1, com cache privado
vazio, autenticação em memória e respostas das fixtures do contrato: uma lista, três
consultas ao detalhe da mesma vaga e uma candidatura confirmada. Exige as cinco rotas,
cinco métricas, enviados maiores que zero, recebidos suficientes para os cinco corpos
e total menor que 1.000.000 B. A coleta deu **2.595 B enviados + 5.365 B recebidos = 7.960 B**.
Não cobre TLS, DNS, Firebase, backend real, aparelho físico ou rede celular.

O modo avião é o cenário sem rede do dublê; não houve acionamento do rádio de um aparelho.
O critério de p95 de 20 aberturas em 4G real num iPhone antigo continua com o Cauê,
assim como a medição de uma sessão real de consulta/candidatura. Nenhum critério do
cartão foi marcado e o Trello não foi alterado.

Bloqueios: 1 superado — a primeira compilação usava `.confirmada` no resultado em vez
de `.estado`; corrigida a asserção antes da execução aprovada. A primeira tentativa
não executou testes. Pulados: 0 nos testes selecionados. Suítes completas não executadas:
fora do recorte e do teto de 60 minutos. CI remota: apenas a automática do PR, sem reexecução.

Comando executado, a partir de `iOS/`:

```sh
/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/xcb.sh 'Homem-Aranha' -- \
  xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431' \
  -derivedDataPath /Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/derived-desempenho-rede \
  -resultBundlePath /Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/desempenho-rede-validacao.xcresult \
  -only-testing:FrilaTests/MedicaoDeDesempenhoTests \
  -only-testing:FrilaTests/ModoAviaoMeuTurnoTests \
  -only-testing:FrilaUITests/ModoAviaoUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Log completo: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261011-230807-68264.log`.
Os artefatos JSON foram exportados antes da remoção do DerivedData e dos xcresult próprios.
