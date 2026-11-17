// @vitest-environment node
import { spawnSync } from 'node:child_process'
import { appendFileSync, cpSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

const raizReal = resolve(import.meta.dirname, '..')

let raiz: string

// Cópia descartável de web/ (contrato, scripts e tipos), para a mutação nunca tocar o repositório.
beforeEach(() => {
  raiz = mkdtempSync(join(tmpdir(), 'contrato-confere-'))
  for (const pasta of ['contrato', 'scripts', 'src/api']) {
    cpSync(join(raizReal, pasta), join(raiz, pasta), { recursive: true })
  }
  symlinkSync(join(raizReal, 'node_modules'), join(raiz, 'node_modules'))
})

afterEach(() => rmSync(raiz, { recursive: true, force: true }))

function confere(...args: string[]) {
  // Ambiente sem token: nenhum teste pode chegar à rede.
  const env = { PATH: process.env['PATH'] ?? '', HOME: process.env['HOME'] ?? '' }
  const r = spawnSync(join(raiz, 'scripts/contrato-confere.sh'), args, { cwd: raiz, env, encoding: 'utf8' })
  return { status: r.status, saida: `${r.stdout}${r.stderr}` }
}

// Muda o espelho sem mudar os tipos (um comentário YAML) e regrava a soma de forma consistente.
function mudaEspelhoComSomaConsistente() {
  appendFileSync(join(raiz, 'contrato/openapi.yaml'), '\n# alteracao posterior ao backend\n')
  const r = spawnSync('shasum', ['-a', '256', join(raiz, 'contrato/openapi.yaml')], { encoding: 'utf8' })
  writeFileSync(join(raiz, 'contrato/openapi.yaml.sha256'), `${r.stdout.split(' ')[0]}\n`)
}

describe('contrato-confere.sh', () => {
  it('passa com o espelho, a soma e os tipos íntegros (--local)', () => {
    const r = confere('--local')
    expect(r.status).toBe(0)
    expect(r.saida).toContain('Tipos em dia com o espelho.')
  })

  it('sem token e sem --local falha com 3, em vez de passar calado', () => {
    const r = confere()
    expect(r.status).toBe(3)
    expect(r.saida).toContain('origem NÃO conferida')
  })

  it('--local sem token avisa em voz alta que a origem não foi conferida', () => {
    expect(confere('--local').saida).toContain('warning: origem NÃO conferida')
  })

  it('falha se o espelho mudou sem atualizar o sha256', () => {
    appendFileSync(join(raiz, 'contrato/openapi.yaml'), '\n# edicao a mao\n')
    const r = confere('--local')
    expect(r.status).toBe(1)
    expect(r.saida).toContain('mudou sem atualizar a soma')
  })

  it('falha se o .d.ts commitado difere do gerado', () => {
    appendFileSync(join(raiz, 'src/api/contrato.d.ts'), '\nexport type Intruso = never\n')
    const r = confere('--local')
    expect(r.status).toBe(1)
    expect(r.saida).toContain('difere do gerado')
  })

  it('falha se o .d.ts foi apagado', () => {
    rmSync(join(raiz, 'src/api/contrato.d.ts'))
    expect(confere('--local').status).toBe(1)
  })

  it('passa quando o espelho é idêntico à origem', () => {
    const r = confere('--origem', join(raizReal, 'contrato/openapi.yaml'))
    expect(r.status).toBe(0)
    expect(r.saida).toContain('Espelho em dia com o backend.')
  })

  it('falha se o espelho difere do backend, mesmo com soma e tipos consistentes', () => {
    const backend = join(raiz, 'backend.yaml')
    writeFileSync(backend, readFileSync(join(raizReal, 'contrato/openapi.yaml')))
    mudaEspelhoComSomaConsistente()
    const r = confere('--origem', backend)
    expect(r.status).toBe(1)
    expect(r.saida).toContain('difere do backend')
  })
})
