// @vitest-environment node
import { delay } from 'msw'
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { mensagemDaFalha } from './mensagens.ts'
import {
  ACESSO_1,
  ACESSO_2,
  CODIGO,
  EMAIL,
  RENOVA_1,
  RENOVA_2,
  RPC,
  SENTINELAS,
  erroJwtExpirado,
  erroLimite,
  espiar,
  novoCliente,
  ok,
  rotas,
  servidor,
  sessaoDoServidor,
  sessaoGuardada,
  status,
} from './testes/apoio.ts'

beforeAll(() => servidor.listen({ onUnhandledFrame: 'error' }))
afterEach(() => {
  servidor.resetHandlers()
  servidor.events.removeAllListeners()
})
afterAll(() => servidor.close())

const HORA = 3_600_000

describe('código errado', () => {
  it('devolve codigo_invalido sem e-mail nem código no resultado nem na mensagem', async () => {
    servidor.use(rotas.verify(() => status(401, erroJwtExpirado())))
    const { cliente, armazenamento } = novoCliente()

    const resultado = await cliente.confirmarCodigo(EMAIL, CODIGO)

    expect(resultado).toEqual({ ok: false, motivo: 'codigo_invalido' })
    if (resultado.ok) throw new Error('esperava falha')
    for (const texto of [JSON.stringify(resultado), mensagemDaFalha(resultado)]) {
      expect(texto).not.toContain(EMAIL)
      expect(texto).not.toContain(CODIGO)
      expect(texto).not.toContain('@')
    }
    expect(await armazenamento.ler()).toBeNull()
    expect(await cliente.estado()).toBe('anonimo')
  })

  it.each([400, 401, 403, 422])('trata o status %i como código inválido, mesmo sem corpo', async (codigo) => {
    servidor.use(rotas.verify(() => status(codigo)))
    const { cliente } = novoCliente()
    expect(await cliente.confirmarCodigo(EMAIL, CODIGO)).toEqual({ ok: false, motivo: 'codigo_invalido' })
  })

  it('manda e-mail, código e type "email" ao /verify, com a chave publicável', async () => {
    const espiao = espiar()
    servidor.use(rotas.verify(() => ok(sessaoDoServidor(1))))
    const { cliente } = novoCliente()

    expect(await cliente.confirmarCodigo(EMAIL, CODIGO)).toEqual({ ok: true })

    await espiao.pronto()
    expect(espiao.chamadas).toHaveLength(1)
    expect(espiao.chamadas[0]?.corpo).toEqual({ email: EMAIL, token: CODIGO, type: 'email' })
    expect(espiao.chamadas[0]?.apikey).toBe('sb_publishable_chave_de_teste')
    expect(espiao.chamadas[0]?.autorizacao).toBeNull()
  })

  it('sessão aberta: grava os tokens e avisa os ouvintes', async () => {
    servidor.use(rotas.verify(() => ok(sessaoDoServidor(1))))
    const { cliente, armazenamento, relogio } = novoCliente()
    const estados: string[] = []
    cliente.aoMudarEstado((e) => estados.push(e))

    await cliente.confirmarCodigo(EMAIL, CODIGO)

    expect(await armazenamento.ler()).toEqual({ access_token: ACESSO_1, refresh_token: RENOVA_1, expiraEm: relogio.agora + HORA })
    expect(estados).toEqual(['autenticado'])
  })

  it('resposta 200 sem os tokens não abre sessão', async () => {
    servidor.use(rotas.verify(() => ok({ access_token: ACESSO_1 })))
    const { cliente, armazenamento } = novoCliente()
    expect(await cliente.confirmarCodigo(EMAIL, CODIGO)).toEqual({ ok: false, motivo: 'erro_do_servidor' })
    expect(await armazenamento.ler()).toBeNull()
  })
})

describe('429 LimiteExcedido', () => {
  it('usa o Retry-After e conta a espera regressivamente', async () => {
    servidor.use(rotas.otp(() => status(429, erroLimite(), { 'retry-after': '42' })))
    const { cliente, relogio } = novoCliente()

    const resultado = await cliente.pedirCodigo(EMAIL)

    expect(resultado).toEqual({ ok: false, motivo: 'limite_excedido', esperaSegundos: 42 })
    expect(cliente.esperaRestanteSegundos()).toBe(42)
    relogio.agora += 10_000
    expect(cliente.esperaRestanteSegundos()).toBe(32)
    relogio.agora += 40_000
    expect(cliente.esperaRestanteSegundos()).toBe(0)
    if (resultado.ok) throw new Error('esperava falha')
    expect(mensagemDaFalha(resultado)).toContain('42')
    expect(mensagemDaFalha(resultado)).not.toContain(EMAIL)
  })

  it.each([
    [undefined, 60],
    ['abc', 60],
    ['0', 60],
    ['-5', 60],
    ['999999', 3600],
  ])('Retry-After %s vira %i s', async (cabecalho, esperado) => {
    servidor.use(rotas.otp(() => status(429, erroLimite(), cabecalho === undefined ? {} : { 'retry-after': cabecalho })))
    const { cliente } = novoCliente()
    expect(await cliente.pedirCodigo(EMAIL)).toEqual({ ok: false, motivo: 'limite_excedido', esperaSegundos: esperado })
  })

  it('durante a espera não chama o servidor de novo; passada a espera, chama', async () => {
    const espiao = espiar()
    servidor.use(rotas.otp(() => status(429, erroLimite(), { 'retry-after': '30' })))
    const { cliente, relogio } = novoCliente()

    await cliente.pedirCodigo(EMAIL)
    relogio.agora += 5_000
    const bloqueado = await cliente.pedirCodigo(EMAIL)

    expect(bloqueado).toEqual({ ok: false, motivo: 'limite_excedido', esperaSegundos: 25 })
    expect(espiao.quantas('/auth/v1/otp')).toBe(1)

    relogio.agora += 25_000
    await cliente.pedirCodigo(EMAIL)
    expect(espiao.quantas('/auth/v1/otp')).toBe(2)
  })

  it('200 do /otp devolve ok e manda só o e-mail', async () => {
    const espiao = espiar()
    servidor.use(rotas.otp(() => ok()))
    const { cliente } = novoCliente()
    expect(await cliente.pedirCodigo(EMAIL)).toEqual({ ok: true })
    await espiao.pronto()
    expect(espiao.chamadas[0]?.corpo).toEqual({ email: EMAIL })
  })

  it('e-mail recusado (422) e queda de rede têm motivo próprio', async () => {
    servidor.use(rotas.otp(() => status(422)))
    const a = novoCliente()
    expect(await a.cliente.pedirCodigo(EMAIL)).toEqual({ ok: false, motivo: 'email_invalido' })

    servidor.use(rotas.otp(() => HttpErroDeRede()))
    const b = novoCliente()
    expect(await b.cliente.pedirCodigo(EMAIL)).toEqual({ ok: false, motivo: 'rede' })
  })
})

function HttpErroDeRede(): Response {
  return Response.error()
}

describe('sessão expirada: renova uma vez e repete a chamada', () => {
  const rpcQueExigeTokenNovo = () =>
    rotas.rpc(({ request }) =>
      request.headers.get('authorization') === `Bearer ${ACESSO_2}` ? ok([{ id: 1 }]) : status(401, erroJwtExpirado()),
    )
  const renovacaoOk = () => rotas.token(() => ok(sessaoDoServidor(2)))

  it('401 → renova com o refresh token antigo → repete com o token novo', async () => {
    const espiao = espiar()
    servidor.use(rpcQueExigeTokenNovo(), renovacaoOk())
    const { cliente, armazenamento, relogio } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))

    const resposta = await cliente.fetchAutenticado(RPC)

    expect(resposta.status).toBe(200)
    await espiao.pronto()
    expect(espiao.quantas('/auth/v1/token')).toBe(1)
    expect(espiao.quantas('/rest/v1/rpc/meus_estabelecimentos')).toBe(2)
    expect(espiao.chamadas.find((c) => c.caminho === '/auth/v1/token')?.corpo).toEqual({ refresh_token: RENOVA_1 })
    expect(espiao.chamadas.filter((c) => c.caminho.includes('/rpc/')).map((c) => c.autorizacao)).toEqual([`Bearer ${ACESSO_1}`, `Bearer ${ACESSO_2}`])
    expect(await armazenamento.ler()).toEqual({ access_token: ACESSO_2, refresh_token: RENOVA_2, expiraEm: relogio.agora + HORA })
    expect(await cliente.estado()).toBe('autenticado')
  })

  it('chamadas simultâneas com o token vencido provocam uma única renovação', async () => {
    const espiao = espiar()
    servidor.use(rpcQueExigeTokenNovo(), rotas.token(async () => { await delay(30); return ok(sessaoDoServidor(2)) }))
    const { cliente } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))

    const respostas = await Promise.all([cliente.fetchAutenticado(RPC), cliente.fetchAutenticado(RPC), cliente.fetchAutenticado(RPC)])

    expect(respostas.map((r) => r.status)).toEqual([200, 200, 200])
    expect(espiao.quantas('/auth/v1/token')).toBe(1)
  })

  it('chamada que já estava em voo com o token antigo não renova de novo', async () => {
    const espiao = espiar()
    let primeira = true
    servidor.use(
      rotas.rpc(async ({ request }) => {
        if (request.headers.get('authorization') === `Bearer ${ACESSO_2}`) return ok([])
        const lenta = !primeira
        primeira = false
        if (lenta) await delay(120)
        return status(401, erroJwtExpirado())
      }),
      rotas.token(async () => { await delay(10); return ok(sessaoDoServidor(2)) }),
    )
    const { cliente } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))

    const respostas = await Promise.all([cliente.fetchAutenticado(RPC), cliente.fetchAutenticado(RPC)])

    expect(respostas.map((r) => r.status)).toEqual([200, 200])
    expect(espiao.quantas('/auth/v1/token')).toBe(1)
  })

  it('token a menos de 30 s de expirar é renovado antes da chamada', async () => {
    const espiao = espiar()
    servidor.use(rpcQueExigeTokenNovo(), renovacaoOk())
    const { cliente } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + 20_000))

    const resposta = await cliente.fetchAutenticado(RPC)

    expect(resposta.status).toBe(200)
    expect(espiao.chamadas.map((c) => c.caminho)).toEqual(['/auth/v1/token', '/rest/v1/rpc/meus_estabelecimentos'])
  })

  it('token com folga não é renovado antes da chamada', async () => {
    const espiao = espiar()
    servidor.use(rotas.rpc(() => ok([])))
    const { cliente } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))
    await cliente.fetchAutenticado(RPC)
    expect(espiao.quantas('/auth/v1/token')).toBe(0)
  })

  it('401 que persiste depois da renovação: uma repetição só, e a sessão acaba', async () => {
    const espiao = espiar()
    servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())), renovacaoOk())
    const { cliente, armazenamento } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))
    const estados: string[] = []
    cliente.aoMudarEstado((e) => estados.push(e))

    const resposta = await cliente.fetchAutenticado(RPC)

    expect(resposta.status).toBe(401)
    expect(espiao.quantas('/rest/v1/rpc/meus_estabelecimentos')).toBe(2)
    expect(espiao.quantas('/auth/v1/token')).toBe(1)
    expect(await armazenamento.ler()).toBeNull()
    expect(estados).toEqual(['anonimo'])
  })

  it('renovação com falha do servidor (503) não desloga e devolve o 401 original', async () => {
    const espiao = espiar()
    servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())), rotas.token(() => status(503)))
    const { cliente, armazenamento } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))

    const resposta = await cliente.fetchAutenticado(RPC)

    expect(resposta.status).toBe(401)
    expect(espiao.quantas('/rest/v1/rpc/meus_estabelecimentos')).toBe(1)
    expect((await armazenamento.ler())?.refresh_token).toBe(RENOVA_1)
    expect(await cliente.estado()).toBe('autenticado')
  })

  it('renovação barrada por limite (429) não desloga', async () => {
    servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())), rotas.token(() => status(429, erroLimite())))
    const { cliente, armazenamento } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))
    expect((await cliente.fetchAutenticado(RPC)).status).toBe(401)
    expect((await armazenamento.ler())?.refresh_token).toBe(RENOVA_1)
    expect(await cliente.estado()).toBe('autenticado')
  })

  it('renovação com queda de rede não desloga', async () => {
    servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())), rotas.token(() => Response.error()))
    const { cliente } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))
    expect((await cliente.fetchAutenticado(RPC)).status).toBe(401)
    expect(await cliente.estado()).toBe('autenticado')
  })

  it('sem sessão, chama só com a chave publicável e não tenta renovar', async () => {
    const espiao = espiar()
    servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())))
    const { cliente } = novoCliente()

    expect((await cliente.fetchAutenticado(RPC)).status).toBe(401)

    expect(espiao.chamadas).toHaveLength(1)
    expect(espiao.chamadas[0]?.autorizacao).toBeNull()
    expect(espiao.chamadas[0]?.apikey).toBe('sb_publishable_chave_de_teste')
  })
})

describe('renovação recusada (401) leva ao login', () => {
  it.each([400, 401, 403])('refresh token recusado com %i: limpa a sessão e avisa', async (codigo) => {
    const espiao = espiar()
    servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())), rotas.token(() => status(codigo, { code: 'refresh_token_not_found' })))
    const { cliente, armazenamento } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))
    const estados: string[] = []
    cliente.aoMudarEstado((e) => estados.push(e))

    const resposta = await cliente.fetchAutenticado(RPC)

    expect(resposta.status).toBe(401)
    expect(espiao.quantas('/rest/v1/rpc/meus_estabelecimentos')).toBe(1)
    expect(await armazenamento.ler()).toBeNull()
    expect(await cliente.estado()).toBe('anonimo')
    expect(estados).toEqual(['anonimo'])
  })

  it('sair() limpa a sessão e avisa', async () => {
    const { cliente, armazenamento } = novoCliente(sessaoGuardada(1, 1_700_000_000_000 + HORA))
    const estados: string[] = []
    cliente.aoMudarEstado((e) => estados.push(e))
    await cliente.sair()
    expect(await armazenamento.ler()).toBeNull()
    expect(estados).toEqual(['anonimo'])
  })
})

describe('zero token no console', () => {
  const metodos = ['log', 'info', 'warn', 'error', 'debug', 'trace', 'dir'] as const

  function capturarConsole() {
    const espioes = metodos.map((m) => vi.spyOn(console, m).mockImplementation(() => undefined))
    return {
      texto: () => espioes.flatMap((e) => e.mock.calls).map((args) => args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' ')).join('\n'),
      restaurar: () => espioes.forEach((e) => e.mockRestore()),
    }
  }

  it('a captura enxerga um console.log com token (o teste não é decorativo)', () => {
    const captura = capturarConsole()
    console.log(ACESSO_1)
    const texto = captura.texto()
    captura.restaurar()
    expect(texto).toContain(ACESSO_1)
  })

  it('login, código errado, 429, renovação, renovação recusada e saída não escrevem nada sensível', async () => {
    const captura = capturarConsole()
    try {
      servidor.use(
        rotas.otp(() => status(429, erroLimite(), { 'retry-after': '30' })),
        rotas.verify(({ request }) => (request.headers.get('x-ok') ? ok() : status(401, erroJwtExpirado()))),
      )
      const a = novoCliente()
      await a.cliente.pedirCodigo(EMAIL)
      await a.cliente.confirmarCodigo(EMAIL, CODIGO)

      servidor.use(rotas.verify(() => ok(sessaoDoServidor(1))))
      await a.cliente.confirmarCodigo(EMAIL, CODIGO)

      servidor.use(
        rotas.rpc(({ request }) => (request.headers.get('authorization') === `Bearer ${ACESSO_2}` ? ok([]) : status(401, erroJwtExpirado()))),
        rotas.token(() => ok(sessaoDoServidor(2))),
      )
      await a.cliente.fetchAutenticado(RPC)

      servidor.use(rotas.rpc(() => status(401, erroJwtExpirado())), rotas.token(() => status(401)))
      await a.cliente.fetchAutenticado(RPC)
      await a.cliente.sair()

      const saida = captura.texto()
      for (const segredo of SENTINELAS) expect(saida).not.toContain(segredo)
    } finally {
      captura.restaurar()
    }
  })
})
