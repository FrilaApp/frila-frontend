export interface ConfigAuth {
  /** Ex.: https://<ref>.supabase.co, sem barra final. */
  urlBase: string
  /** Chave PUBLICÁVEL do projeto. Vai em toda requisição e não identifica o usuário. */
  chavePublicavel: string
}

function ehChaveSecreta(chave: string): boolean {
  if (chave.startsWith('sb_secret_')) return true
  const partes = chave.split('.')
  if (partes.length !== 3 || !partes[1]) return false
  try {
    const carga: unknown = JSON.parse(atob(partes[1].replace(/-/g, '+').replace(/_/g, '/')))
    return typeof carga === 'object' && carga !== null && 'role' in carga && carga.role === 'service_role'
  } catch {
    return false
  }
}

/** Lê a configuração do ambiente do Vite. As mensagens citam só o nome da variável, nunca o valor. */
export function lerConfigDoAmbiente(env: Record<string, string | undefined>): ConfigAuth {
  const url = env['VITE_SUPABASE_URL']?.trim()
  const chave = env['VITE_SUPABASE_PUBLISHABLE_KEY']?.trim()
  if (!url) throw new Error('VITE_SUPABASE_URL ausente (veja web/.env.example)')
  if (!chave) throw new Error('VITE_SUPABASE_PUBLISHABLE_KEY ausente (veja web/.env.example)')

  let endereco: URL
  try {
    endereco = new URL(url)
  } catch {
    throw new Error('VITE_SUPABASE_URL não é uma URL válida')
  }
  const local = endereco.hostname === 'localhost' || endereco.hostname === '127.0.0.1'
  if (endereco.protocol !== 'https:' && !(endereco.protocol === 'http:' && local)) {
    throw new Error('VITE_SUPABASE_URL precisa ser https (http só em localhost)')
  }
  if (ehChaveSecreta(chave)) {
    throw new Error('VITE_SUPABASE_PUBLISHABLE_KEY é uma chave secreta (service_role); use só a publicável')
  }
  return { urlBase: endereco.origin, chavePublicavel: chave }
}
