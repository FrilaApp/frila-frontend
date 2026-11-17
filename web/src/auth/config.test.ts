import { describe, expect, it } from 'vitest'
import { criarArmazenamentoEmMemoria } from './armazenamento.ts'
import { lerConfigDoAmbiente } from './config.ts'

const jwt = (carga: object) => `${btoa('{"alg":"HS256"}')}.${btoa(JSON.stringify(carga)).replace(/=+$/, '')}.assinatura`
const ambiente = (extra: Record<string, string> = {}) => ({
  VITE_SUPABASE_URL: 'https://abc.supabase.co/',
  VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_exemplo',
  ...extra,
})

describe('lerConfigDoAmbiente', () => {
  it('aceita URL https e chave publicável, e tira a barra final', () => {
    expect(lerConfigDoAmbiente(ambiente())).toEqual({ urlBase: 'https://abc.supabase.co', chavePublicavel: 'sb_publishable_exemplo' })
  })

  it('aceita http só em localhost', () => {
    expect(lerConfigDoAmbiente(ambiente({ VITE_SUPABASE_URL: 'http://127.0.0.1:54321' })).urlBase).toBe('http://127.0.0.1:54321')
    expect(() => lerConfigDoAmbiente(ambiente({ VITE_SUPABASE_URL: 'http://abc.supabase.co' }))).toThrow('https')
  })

  it('recusa chave secreta sb_secret_ e JWT com role service_role, sem repetir a chave na mensagem', () => {
    for (const chave of ['sb_secret_valor_que_nao_pode_aparecer', jwt({ role: 'service_role' })]) {
      const erro = (() => {
        try {
          lerConfigDoAmbiente(ambiente({ VITE_SUPABASE_PUBLISHABLE_KEY: chave }))
        } catch (e) {
          return e as Error
        }
        return null
      })()
      expect(erro?.message).toContain('secreta')
      expect(erro?.message).not.toContain(chave)
    }
  })

  it('aceita o JWT legado com role anon', () => {
    expect(lerConfigDoAmbiente(ambiente({ VITE_SUPABASE_PUBLISHABLE_KEY: jwt({ role: 'anon' }) })).chavePublicavel).toContain('.')
  })

  it('recusa variável ausente ou URL inválida, citando só o nome', () => {
    expect(() => lerConfigDoAmbiente({})).toThrow('VITE_SUPABASE_URL')
    expect(() => lerConfigDoAmbiente({ VITE_SUPABASE_URL: 'https://abc.supabase.co' })).toThrow('VITE_SUPABASE_PUBLISHABLE_KEY')
    expect(() => lerConfigDoAmbiente(ambiente({ VITE_SUPABASE_URL: 'não é url' }))).toThrow('URL válida')
  })
})

describe('armazenamento em memória', () => {
  it('guarda, devolve e limpa', async () => {
    const armazenamento = criarArmazenamentoEmMemoria()
    expect(await armazenamento.ler()).toBeNull()
    await armazenamento.gravar({ access_token: 'a', refresh_token: 'r', expiraEm: 1 })
    expect(await armazenamento.ler()).toEqual({ access_token: 'a', refresh_token: 'r', expiraEm: 1 })
    await armazenamento.limpar()
    expect(await armazenamento.ler()).toBeNull()
  })
})
