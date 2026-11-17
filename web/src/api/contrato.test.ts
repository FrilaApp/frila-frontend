import { describe, expectTypeOf, it } from 'vitest'
import type { components, paths } from './contrato.d.ts'

// Verificados em tempo de compilação (npm run tipos): se o gerador perder um destes
// formatos, o tsc falha, mesmo que o gate de deriva esteja em dia.
describe('tipos gerados do contrato', () => {
  it('Sessao carrega os dois tokens que a camada de autenticação guarda', () => {
    type Sessao = components['schemas']['Sessao']
    expectTypeOf<Sessao['access_token']>().toBeString()
    expectTypeOf<Sessao['refresh_token']>().toBeString()
    expectTypeOf<Sessao['expires_in']>().toBeNumber()
  })

  it('expõe as rotas de Auth e a RPC do Painel', () => {
    expectTypeOf<keyof paths>().toExtend<string>()
    expectTypeOf<'/otp'>().toExtend<keyof paths>()
    expectTypeOf<'/verify'>().toExtend<keyof paths>()
    expectTypeOf<'/token'>().toExtend<keyof paths>()
    expectTypeOf<'/rpc/painel_estabelecimento'>().toExtend<keyof paths>()
  })

  it('expõe as respostas de recusa de autenticação e de limite', () => {
    expectTypeOf<components['responses']['NaoAutenticado']>().not.toBeNever()
    expectTypeOf<components['responses']['LimiteExcedido']>().not.toBeNever()
  })
})
