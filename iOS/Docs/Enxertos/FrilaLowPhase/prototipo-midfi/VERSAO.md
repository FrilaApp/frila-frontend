# Espelho do Protótipo do Frila (MidFi)

Cópia somente leitura do canvas "Protótipo do Frila" no claude.ai, versionada no git.
Só o Wizard (Claude) publica no artefato e atualiza esta pasta. Witcher e Wise leem daqui e devolvem achados com `arquivo:linha`.
É referência de design para o port em SwiftUI: nunca é executada nem importada pelo código (regra G1 do `RULES.md`).
O `git log -- docs/prototype/midfi` mostra o que mudou entre versões do canvas.
Para publicar uma nova versão, siga `.orchestra/midfi-backend/PUBLICAR-CANVAS.md` (o script `verificar-canvas.py` confere o `canvas.json` e prepara os arquivos).

- Artefato: https://claude.ai/artifact/27750a8e-fd19-4fb0-8161-a26d06976b32
- Versão espelhada: 1792136457-47b4 (Version 65)
- Espelhado em: 2026-10-16
- Conteúdo: `project/canvas.json` (índice, posições e títulos dos quadros) e 104 quadros `project/*.dc.html` (390×844).

## Como ler

- Cada `.dc.html` é um quadro inteiro. O markup fica dentro de `<x-dc>`, e o estado e os Tweaks ficam no `<script type="text/x-dc">` (`data-props`).
- `<a href="X.dc.html">` é a navegação para outro quadro. `<sc-if>` mostra estados alternativos. `<dc-import>` embute outro quadro (usado pelos wrappers).
- Wrappers finos (Denuncia*, Mapa*, Excluir*, Exportar*, Editar*, VagasSemNotificacao; EditarHorario, PublicarCopia, TurnoContratanteHoje, CandidataPaulo, DenunciaContratantePaulo, TurnoProximoAmanha, TurnoHojeCancelado) só reaproveitam um quadro com outra prop.
- `Candidata.dc.html` integra o fluxo v1.0: abre pela identidade do profissional no turno confirmado do contratante (Q1), incluindo o envelope `CandidataPaulo.dc.html` para o turno de hoje.
- Decisões de design fixas: memória `project_midfi-prototype-decisions.md` do projeto.

## Histórico

| Data | Versão | Mudança |
| :--- | :--- | :--- |
| 2026-09-30 | 1790735592-a367 | Carga inicial do espelho |
| 2026-09-30 | 1790739217-4e13 | F1 rodada 1: versão do app em Main, conta e erros do código em Codigo, aceite de termos e menor de 18 em Perfil, exceções e ajuste de ponto em Estabelecimento, grade vazia em Disponibilidade; quadros novos JanelaHorario e EditarHorario |
| 2026-09-30 | 1790740282-d422 | F2 rodada 1: navegação do contratante B (Minhas vagas, Turnos, Perfil); TurnosContratante, RepetirVaga e PublicarCopia novos; Publicar, VagaAberta e TrocarLocal corrigidos |
| 2026-09-30 | Version 43 | Edição manual do usuário em ExcluirConta: main passou para dentro do sc-if confirmando |
| 2026-09-30 | 1790741241-3879 | F3 rodada 1: desfechos do aceite com envio e sem resposta em Vaga, aviso de contato com o prazo de 7 dias, cards de Vagas com inclusos e posições, estados vazios distintos, copy por pessoa e reputação no formato do §12.2 |
| 2026-09-30 | 1790743059-fe34 | J e layout: calendário único (hoje sex 25/09, sáb 26/09, dom 27/09, sáb anterior 19/09); TurnoContratante com pessoa e momento, e TurnoContratanteHoje; regra de não encolher em 34 quadros; contato em 50/50; respiro inferior de 88 px; 4 espaços em flex; CSS duplicado |
| 2026-09-30 | 1790743453-bf9d | J-05 e J-06: no turno encerrado do TurnoContratante, chip "Verificada" coerente com o texto e "Cancelar turno" oculto |
| 2026-10-15 | 1792042148-dec2 (Version 62) | Missão midfi-backend: 10 fluxos da E2; novos quadros Ajuda, ContaSuspensa, Abertura e CortinaPrivacidade, e envelopes CandidataPaulo, DenunciaContratantePaulo, TurnoProximoAmanha e TurnoHojeCancelado. Navegação sem parâmetros de URL conforme `.orchestra/midfi-backend/AVISO-E5-NAVEGACAO.md`; revisão em `.orchestra/midfi-backend/REVIEW-DESIGN.md`. Canvas aprovado pela pessoa. |
| 2026-10-16 | 1792127058-cac2 (Version 64) | Rodada `correcao-altos`: corrige os 13 defeitos de fluxo altos das revisões do contratante e do profissional (`.orchestra/correcao-altos/`). 31 envelopes novos em duas fileiras abaixo do canvas (cópias de vaga, turnos e denúncias por pessoa, horários de sábado e domingo, mapas e turnos de Buffet Primavera e Casa de Eventos do Lago). Dados fictícios autorizados pela pessoa em `DECISAO-PESSOA.md`. Aguarda revisão da pessoa. |
| 2026-10-16 | 1792136457-47b4 (Version 65) | Rodada `correcao-medios`: corrige 13 dos 16 defeitos médios (2 já resolvidos pelos altos; PRO:TRI-06 adiado para a alta fidelidade). 17 envelopes novos numa terceira fileira (cópia de Turnos, republicação de Garçom e Cumim, turno manual e em atraso, horários pelo Perfil). Dados de republicação conforme `.orchestra/correcao-medios/DECISAO-PESSOA.md`. Aguarda revisão da pessoa. |
