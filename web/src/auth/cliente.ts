import type { ArmazenamentoDeSessao, Sessao, SessaoGuardada } from './armazenamento.ts'
import type { ConfigAuth } from './config.ts'

export type Falha =
  | { ok: false; motivo: 'limite_excedido'; esperaSegundos: number }
  | { ok: false; motivo: 'codigo_invalido' | 'email_invalido' | 'rede' | 'erro_do_servidor' }

export type Resultado = { ok: true } | Falha

export type EstadoDaSessao = 'anonimo' | 'autenticado'

export interface OpcoesDoCliente {
  config: ConfigAuth
  armazenamento: ArmazenamentoDeSessao
  /** Relógio em ms; injetável nos testes. */
  agora?: () => number
}

/** Sem Retry-After legível, vale a janela de reenvio do Auth (max_frequency = 60 s no config.toml local). */
const ESPERA_PADRAO_S = 60
/** Teto: o limite de e-mails do Auth é por hora. */
const ESPERA_MAXIMA_S = 3600
/** Renova antes de chamar quando faltam menos de 30 s para o token de acesso expirar. */
const MARGEM_DE_EXPIRACAO_MS = 30_000

type DestinoDaRenovacao = 'renovada' | 'encerrada' | 'transitoria'

function esperaDoCabecalho(resposta: Response): number {
  const bruto = resposta.headers.get('retry-after')
  const segundos = bruto === null ? Number.NaN : Number.parseInt(bruto, 10)
  if (!Number.isFinite(segundos) || segundos <= 0) return ESPERA_PADRAO_S
  return Math.min(segundos, ESPERA_MAXIMA_S)
}

function sessaoDoCorpo(corpo: unknown, agora: number): SessaoGuardada | null {
  if (typeof corpo !== 'object' || corpo === null) return null
  const { access_token, refresh_token, expires_in } = corpo as Partial<Sessao>
  if (typeof access_token !== 'string' || typeof refresh_token !== 'string') return null
  if (typeof expires_in !== 'number') return null
  return { access_token, refresh_token, expiraEm: agora + expires_in * 1000 }
}

/**
 * Cliente de autenticação por código de e-mail (contrato: /otp, /verify, /token).
 *
 * Os tokens nunca saem daqui: quem chama recebe só `Resultado` e usa `fetchAutenticado`.
 * Este módulo não escreve em console.
 */
export function criarClienteAuth({ config, armazenamento, agora = Date.now }: OpcoesDoCliente) {
  const ouvintes = new Set<(estado: EstadoDaSessao) => void>()
  let bloqueadoAte = 0
  let renovacaoEmCurso: Promise<DestinoDaRenovacao> | null = null

  const avisar = (estado: EstadoDaSessao) => ouvintes.forEach((ouvinte) => ouvinte(estado))
  const cabecalhosBase = () => ({ apikey: config.chavePublicavel, 'content-type': 'application/json' })
  const post = (caminho: string, corpo: unknown) =>
    globalThis.fetch(`${config.urlBase}/auth/v1/${caminho}`, {
      method: 'POST',
      headers: cabecalhosBase(),
      body: JSON.stringify(corpo),
    })

  function esperaRestanteSegundos(): number {
    return Math.max(0, Math.ceil((bloqueadoAte - agora()) / 1000))
  }

  async function pedirCodigo(email: string): Promise<Resultado> {
    const restante = esperaRestanteSegundos()
    if (restante > 0) return { ok: false, motivo: 'limite_excedido', esperaSegundos: restante }

    let resposta: Response
    try {
      resposta = await post('otp', { email })
    } catch {
      return { ok: false, motivo: 'rede' }
    }
    if (resposta.ok) return { ok: true }
    if (resposta.status === 429) {
      const espera = esperaDoCabecalho(resposta)
      bloqueadoAte = agora() + espera * 1000
      return { ok: false, motivo: 'limite_excedido', esperaSegundos: espera }
    }
    if (resposta.status === 400 || resposta.status === 422) return { ok: false, motivo: 'email_invalido' }
    return { ok: false, motivo: 'erro_do_servidor' }
  }

  async function confirmarCodigo(email: string, codigo: string): Promise<Resultado> {
    let resposta: Response
    try {
      resposta = await post('verify', { email, token: codigo, type: 'email' })
    } catch {
      return { ok: false, motivo: 'rede' }
    }
    if (resposta.status === 429) return { ok: false, motivo: 'limite_excedido', esperaSegundos: esperaDoCabecalho(resposta) }
    // O contrato documenta 401; o Auth real pode devolver 400, 403 ou 422 para código errado ou expirado.
    if ([400, 401, 403, 422].includes(resposta.status)) return { ok: false, motivo: 'codigo_invalido' }
    if (!resposta.ok) return { ok: false, motivo: 'erro_do_servidor' }

    const sessao = sessaoDoCorpo(await resposta.json().catch(() => null), agora())
    if (!sessao) return { ok: false, motivo: 'erro_do_servidor' }
    await armazenamento.gravar(sessao)
    avisar('autenticado')
    return { ok: true }
  }

  async function encerrar(): Promise<void> {
    await armazenamento.limpar()
    avisar('anonimo')
  }

  /** Uma renovação por vez: o refresh token gira a cada uso, e duas chamadas concorrentes matariam a sessão. */
  function renovar(): Promise<DestinoDaRenovacao> {
    renovacaoEmCurso ??= executarRenovacao().finally(() => {
      renovacaoEmCurso = null
    })
    return renovacaoEmCurso
  }

  async function executarRenovacao(): Promise<DestinoDaRenovacao> {
    const atual = await armazenamento.ler()
    if (!atual) return 'encerrada'

    let resposta: Response
    try {
      resposta = await globalThis.fetch(`${config.urlBase}/auth/v1/token?grant_type=refresh_token`, {
        method: 'POST',
        headers: cabecalhosBase(),
        body: JSON.stringify({ refresh_token: atual.refresh_token }),
      })
    } catch {
      return 'transitoria'
    }
    // 5xx e 429 são falha do servidor ou do limite, não da sessão: não desloga.
    if (resposta.status === 429 || resposta.status >= 500) return 'transitoria'
    if (!resposta.ok) {
      await encerrar()
      return 'encerrada'
    }
    const nova = sessaoDoCorpo(await resposta.json().catch(() => null), agora())
    if (!nova) return 'transitoria'
    await armazenamento.gravar(nova)
    return 'renovada'
  }

  async function enviar(entrada: string | URL, init: RequestInit | undefined, sessao: SessaoGuardada | null) {
    const cabecalhos = new Headers(init?.headers)
    cabecalhos.set('apikey', config.chavePublicavel)
    if (sessao) cabecalhos.set('authorization', `Bearer ${sessao.access_token}`)
    return globalThis.fetch(entrada, { ...init, headers: cabecalhos })
  }

  /**
   * fetch com a sessão. Renova antes se o token está para expirar; num 401, renova uma vez e repete
   * a chamada uma vez. Se a renovação é recusada, ou o repetido ainda dá 401, a sessão acaba
   * (estado `anonimo`) e a resposta 401 é devolvida. O corpo da requisição tem de poder ser enviado
   * duas vezes (string ou similar, não stream).
   */
  async function fetchAutenticado(entrada: string | URL, init?: RequestInit): Promise<Response> {
    let sessao = await armazenamento.ler()
    if (sessao && sessao.expiraEm - agora() <= MARGEM_DE_EXPIRACAO_MS) {
      await renovar()
      sessao = await armazenamento.ler()
    }

    const primeira = await enviar(entrada, init, sessao)
    if (primeira.status !== 401 || !sessao) return primeira

    // Outra chamada pode já ter renovado enquanto esta estava em voo: então só repete.
    const guardada = await armazenamento.ler()
    const jaRenovada = guardada !== null && guardada.access_token !== sessao.access_token
    if (!jaRenovada && (await renovar()) !== 'renovada') return primeira

    const segunda = await enviar(entrada, init, await armazenamento.ler())
    if (segunda.status === 401) await encerrar()
    return segunda
  }

  return {
    pedirCodigo,
    confirmarCodigo,
    fetchAutenticado,
    esperaRestanteSegundos,
    async estado(): Promise<EstadoDaSessao> {
      return (await armazenamento.ler()) ? 'autenticado' : 'anonimo'
    },
    /** Devolve a função que cancela a assinatura. */
    aoMudarEstado(ouvinte: (estado: EstadoDaSessao) => void): () => void {
      ouvintes.add(ouvinte)
      return () => ouvintes.delete(ouvinte)
    },
    sair: encerrar,
  }
}

export type ClienteAuth = ReturnType<typeof criarClienteAuth>
