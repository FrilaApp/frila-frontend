import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import type { components } from '../../api/contrato.d.ts'
import { criarArmazenamentoEmMemoria, type SessaoGuardada } from '../armazenamento.ts'
import { criarClienteAuth } from '../cliente.ts'

export const BASE = 'https://teste.supabase.co'
export const CHAVE = 'sb_publishable_chave_de_teste'
export const RPC = `${BASE}/rest/v1/rpc/meus_estabelecimentos`

// Valores sintéticos e reconhecíveis: o teste do console procura por eles.
export const EMAIL = 'maria.teste@exemplo.invalid'
export const CODIGO = '918273'
export const ACESSO_1 = 'ACESSO-UM-sentinela'
export const ACESSO_2 = 'ACESSO-DOIS-sentinela'
export const RENOVA_1 = 'RENOVA-UM-sentinela'
export const RENOVA_2 = 'RENOVA-DOIS-sentinela'
export const SENTINELAS = [EMAIL, CODIGO, ACESSO_1, ACESSO_2, RENOVA_1, RENOVA_2]

type Erro = components['schemas']['Erro']
type Sessao = components['schemas']['Sessao']

// Formatos do contrato: `satisfies` quebra a compilação se o contrato mudar o formato.
export const sessaoDoServidor = (n: 1 | 2): Sessao =>
  ({
    access_token: n === 1 ? ACESSO_1 : ACESSO_2,
    token_type: 'bearer',
    expires_in: 3600,
    refresh_token: n === 1 ? RENOVA_1 : RENOVA_2,
  }) satisfies Sessao

export const erroLimite = (): Erro => ({ code: 'limite_excedido', message: 'limite_excedido', details: null, hint: null })
export const erroJwtExpirado = (): Erro => ({ code: 'PGRST301', message: 'JWT expired', details: null, hint: null })

export const servidor = setupServer()

export const ok = (corpo: unknown = {}) => HttpResponse.json(corpo as Record<string, unknown>, { status: 200 })
export const status = (codigo: number, corpo?: unknown, cabecalhos?: Record<string, string>) =>
  corpo === undefined
    ? new HttpResponse(null, { status: codigo, ...(cabecalhos ? { headers: cabecalhos } : {}) })
    : HttpResponse.json(corpo as Record<string, unknown>, { status: codigo, ...(cabecalhos ? { headers: cabecalhos } : {}) })

/** Conta e guarda o que o servidor falso recebeu. Registra na hora; `pronto()` espera a leitura dos corpos. */
export function espiar() {
  const chamadas: { caminho: string; autorizacao: string | null; apikey: string | null; corpo: unknown }[] = []
  const leituras: Promise<void>[] = []
  servidor.events.on('request:start', ({ request }) => {
    const entrada = {
      caminho: new URL(request.url).pathname,
      autorizacao: request.headers.get('authorization'),
      apikey: request.headers.get('apikey'),
      corpo: undefined as unknown,
    }
    chamadas.push(entrada)
    leituras.push(
      request
        .clone()
        .text()
        .then((texto) => {
          try {
            entrada.corpo = JSON.parse(texto)
          } catch {
            entrada.corpo = texto
          }
        })
        .catch(() => undefined),
    )
  })
  return {
    chamadas,
    quantas: (caminho: string) => chamadas.filter((c) => c.caminho === caminho).length,
    pronto: () => Promise.all(leituras).then(() => undefined),
  }
}

export function novoCliente(sessaoInicial?: SessaoGuardada) {
  const armazenamento = criarArmazenamentoEmMemoria()
  const relogio = { agora: 1_700_000_000_000 }
  const cliente = criarClienteAuth({ config: { urlBase: BASE, chavePublicavel: CHAVE }, armazenamento, agora: () => relogio.agora })
  if (sessaoInicial) void armazenamento.gravar(sessaoInicial)
  return { cliente, armazenamento, relogio }
}

export const sessaoGuardada = (n: 1 | 2, expiraEm: number): SessaoGuardada => {
  const { access_token, refresh_token } = sessaoDoServidor(n)
  return { access_token, refresh_token, expiraEm }
}

export const rotas = {
  otp: (resolvedor: Parameters<typeof http.post>[1]) => http.post(`${BASE}/auth/v1/otp`, resolvedor),
  verify: (resolvedor: Parameters<typeof http.post>[1]) => http.post(`${BASE}/auth/v1/verify`, resolvedor),
  token: (resolvedor: Parameters<typeof http.post>[1]) => http.post(`${BASE}/auth/v1/token`, resolvedor),
  rpc: (resolvedor: Parameters<typeof http.get>[1]) => http.get(RPC, resolvedor),
}
