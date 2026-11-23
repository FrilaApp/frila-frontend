import { ehPedidoSeguro } from "./sessao";

export type Aparencia = "claro" | "escuro";

const NOME_DO_COOKIE = "frila-aparencia";

export function aparenciaValida(valor: unknown): Aparencia {
  return valor === "escuro" ? "escuro" : "claro";
}

/** Preferência deste navegador, sem vínculo com a conta nem dado pessoal. */
export function lerAparencia(request: Request): Aparencia {
  for (const parte of (request.headers.get("Cookie") ?? "").split(";")) {
    const [nome, ...valor] = parte.trim().split("=");
    if (nome === NOME_DO_COOKIE) return aparenciaValida(valor.join("="));
  }
  return "claro";
}

export function cookieDaAparencia(valor: unknown, request: Request): string {
  // Path=/ cobre também /app.data, usado na revalidação do loader da raiz.
  return `${NOME_DO_COOKIE}=${aparenciaValida(valor)}; Path=/; Max-Age=31536000; SameSite=Lax${ehPedidoSeguro(request) ? "; Secure" : ""}`;
}
