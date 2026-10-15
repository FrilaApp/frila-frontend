# Conferência e Gate de Deriva de Contrato (iOS x OpenAPI 0.2.41)

Este documento descreve a ferramenta de gate automatizado contra deriva de contrato entre o aplicativo iOS (`frila-frontend`) e o backend Supabase (`frila-backend`), baseada na especificação OpenAPI 0.2.41.

---

## 1. Motivação e Objetivos

O Frila opera com um contrato estrito em OpenAPI (`Contrato/openapi.yaml`), espelhado a partir de `FrilaApp/frila-docs` e sincronizado com o `frila-backend`.

Antes desta ferramenta, o script `contrato-em-dia.sh` garantia apenas a integridade do arquivo `.yaml` (checksum SHA-256 e comparação remota). Não havia uma verificação estrutural automática garantindo que:
1. Toda RPC do contrato possui implementação real no cliente Swift (`SupabaseApiCliente.swift`).
2. Todo enum fechado do contrato possui os mesmos casos com os mesmos valores no domínio do app.
3. Todo código estável de erro/recusa documentado nas regras de negócio é tratado em `CodigoErroAPI`.
4. Todo DTO do app decodifica/envia todos os campos obrigatórios declarados nos schemas do OpenAPI.

O novo gate `contrato-ios-confere.sh` e seu validador `conferir-contrato-ios.py` fecham essa lacuna, rodando na CI e impedindo que código com deriva entre em `main`.

---

## 2. Estrutura dos Scripts

- **`iOS/Scripts/conferir-contrato-ios.py`**: Motor em Python 3. Lê o OpenAPI (usando o interpretador Ruby do macOS para conversão YAML -> JSON sem dependências externas adicionais) e inspeciona o código Swift do app.
- **`iOS/Scripts/contrato-ios-confere.sh`**: Wrapper executável para desenvolvedores e CI. Pode ser executado da raiz do repositório (`./scripts/contrato-ios-confere.sh`) ou de dentro da pasta `iOS/` (`./Scripts/contrato-ios-confere.sh`).
- **`iOS/Scripts/teste-contrato-ios-confere.sh`**: Autoteste com 7 verificações sintéticas (caso base positivo + 6 injeções de defeitos controladas), garantindo que o verificador falha de forma estrita em caso de regressão.

---

## 3. Os 5 Pilares de Conferência

### Pilar 1: Sincronia de Espelhos
Quando executado em ambiente com o repositório `frila-backend` adjacente (ex.: monorepo de trabalho local), compara se o espelho local do iOS está na mesma versão e íntegro com o backend.

### Pilar 2: Paridade de RPCs (44 de 44)
O contrato 0.2.41 define exatamente 44 rotas sob `/rpc/...`. O script verifica se cada uma delas é referenciada em `SupabaseApiCliente.swift` e se nenhuma rota desconhecida foi inventada no cliente:
- `abrir_suporte`
- `atualizar_perfil_profissional`
- `avaliar`
- `avisar_a_caminho`
- `bloquear`
- `cadastrar_estabelecimento`
- `cancelar_posicao`
- `cancelar_vaga`
- `candidatar`
- `candidatos_da_vaga`
- `configuracao_do_app`
- `confirmar_checkin_manual`
- `contato_do_turno`
- `contestar_suspensao`
- `criar_conta`
- `criar_perfil_profissional`
- `criterios_de_notificacao`
- `denunciar`
- `detalhe_vaga`
- `equipe_de_confianca`
- `escolher_candidato`
- `fazer_checkin`
- `fazer_checkout`
- `incluir_na_equipe`
- `meu_estabelecimento`
- `meu_perfil_profissional`
- `meus_estabelecimentos`
- `meus_turnos`
- `minha_conta`
- `minhas_candidaturas`
- `painel_estabelecimento`
- `pedir_revisao_despacho`
- `perfil_publico`
- `publicar_vaga`
- `reabrir_por_atraso`
- `registrar_dispositivo`
- `registrar_evento`
- `remover_da_equipe`
- `remover_dispositivo`
- `republicar_posicoes_restantes`
- `republicar_vaga`
- `retirar_candidatura`
- `situacao_da_conta`
- `vagas_abertas`

### Pilar 3: Paridade de Enums (17 de 17)
Compara caso a caso todos os enums fechados do contrato com suas definições em `Modelos.swift`, `DTOsContrato.swift`, `Dispositivo.swift` e `AvisoDePush.swift`:
1. `CategoriaSuporte`: 5 casos (`endereco`, `atraso`, `conduta`, `seguranca`, `outro`)
2. `CausaDoCancelamento`: 5 casos (`profissional`, `estabelecimento`, `reabertura_por_atraso`, `no_show_sem_checkin`, `outro`)
3. `EstadoCandidatura`: 5 casos (`pendente`, `aceita`, `recusada`, `retirada`, `expirada`)
4. `EstadoConta`: 2 casos (`ativa`, `suspensa`)
5. `EstadoPosicao`: 4 casos (`aberta`, `confirmada`, `cumprida`, `cancelada`)
6. `EstadoVaga`: 4 casos (`publicada`, `preenchida`, `encerrada`, `cancelada`)
7. `EventoDeTelemetria`: 14 casos (`app_aberto`, `cadastro_concluido`, `permissao_push_negada`, `vaga_vista`, `vaga_detalhe_aberto`, `candidatura_enviada`, `candidatura_retirada`, `checkin_tentado`, `checkin_concluido`, `checkout_concluido`, `avaliacao_enviada`, `contato_aberto`, `acao_enfileirada_offline`, `atualizacao_obrigatoria_exibida`)
8. `ModoPreenchimento`: 2 casos (`urgencia`, `selecao`)
9. `MotivoDenuncia`: 4 casos (`assedio`, `discriminacao`, `risco_seguranca`, `outro`)
10. `PapelMembro`: 2 casos (`administrador`, `operador`)
11. `PerfilConta`: 2 casos (`profissional`, `contratante`)
12. `Plataforma`: 3 casos (`ios`, `android`, `web`)
13. `TipoDeAlvo`: 2 casos (`profissional`, `estabelecimento`)
14. `TipoEstabelecimento`: 6 casos (`food_service`, `evento`, `varejo`, `logistica`, `servico_domestico`, `outro`)
15. `TipoNotificacao`: 19 casos
16. `TipoRegistro`: 2 casos (`geolocalizado`, `manual`)
17. `Verificacao`: 3 casos (`pendente`, `verificado`, `nao_verificado`)

### Pilar 4: Códigos de Recusa Tratados
Extrai a tabela normativa de recusas estáveis sob `## Erros` na descrição do OpenAPI e verifica a presença em `CodigoErroAPI` (`ErrosDaAPI.swift`). Cobre todas as recusas por regra de negócio, regras de integridade e concorrência (ex.: `posicao_ja_preenchida`, `republicacao_indisponivel`, `a_caminho_fora_da_janela`, etc.).

### Pilar 5: Paridade de DTOs (43 de 43)
Mapeia os 43 schemas de componentes usados no app para seus structs correspondentes em `DTOsContrato.swift`, verificando que 100% dos campos obrigatórios (`required`) do contrato possuem representação equivalente (incluindo mapeamento via `CodingKeys`).

---

## 4. Correções de Código Realizadas

Durante a execução da auditoria inicial, foram identificadas e corrigidas pequenas discrepâncias:
1. **`ConfiguracaoDoAppDTO`**: Adicionado campo opcional `let plataforma: Plataforma?` e seu respectivo `case plataforma` nos `CodingKeys`, refletindo a propriedade declarada no schema `ConfiguracaoDoApp`.
2. **`SessaoDTO`**: Adicionados campos opcionais `let tokenType: String?` e `let expiresIn: Int?` nos `CodingKeys`, refletindo o payload padrão retornado por `/auth/v1/verify` e pelo endpoint `entrar-demonstracao`.
3. **`TipoDeAlvo`**: Adicionado `public typealias TipoDeAlvo = TipoPerfilPublico` em `Modelos.swift` para estabelecer equivalência semântica estrita com o schema `TipoDeAlvo` do contrato.

---

## 5. Execução Manual e Integração Contínua

### Executar a verificação
```bash
# Na raiz do repositório:
./scripts/contrato-ios-confere.sh

# Ou na pasta iOS/:
./Scripts/contrato-ios-confere.sh
```

### Executar o autoteste
```bash
./iOS/Scripts/teste-contrato-ios-confere.sh
```

### CI
O teste e o validador estão integrados no job `parte-1` do workflow `.github/workflows/ios.yml`, executando logo após a validação de fixtures.
