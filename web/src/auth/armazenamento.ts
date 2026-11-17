import type { components } from '../api/contrato.d.ts'

export type Sessao = components['schemas']['Sessao']

/** Sessão como guardada: os campos do contrato mais o instante (ms desde a época) em que o token de acesso expira. */
export type SessaoGuardada = Pick<Sessao, 'access_token' | 'refresh_token'> & { expiraEm: number }

/**
 * Onde o token da sessão mora. O contrato manda cookie `HttpOnly` na web (RNF07), o que uma SPA
 * sem servidor não consegue; a decisão D2 ainda não foi tomada. O resto do módulo só conhece esta
 * interface, então a troca de lugar não reescreve nada.
 *
 * Assíncrona de propósito: nem IndexedDB nem uma ponte para o servidor são síncronos.
 */
export interface ArmazenamentoDeSessao {
  ler(): Promise<SessaoGuardada | null>
  gravar(sessao: SessaoGuardada): Promise<void>
  limpar(): Promise<void>
}

/** Só na memória da aba: some ao recarregar. Seguro por padrão e não escolhe a resposta da D2. */
export function criarArmazenamentoEmMemoria(): ArmazenamentoDeSessao {
  let guardada: SessaoGuardada | null = null
  return {
    ler: () => Promise.resolve(guardada),
    gravar: (sessao) => {
      guardada = sessao
      return Promise.resolve()
    },
    limpar: () => {
      guardada = null
      return Promise.resolve()
    },
  }
}
