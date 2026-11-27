import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

import {
  CampoDeSenha,
  reduzirVisibilidadeSenha,
  restaurarSelecaoAposAlternar,
  vincularOcultacaoEmSegundoPlano,
} from "../app/componentes/campo-de-senha";

describe("CampoDeSenha (SSR / sem JavaScript)", () => {
  it("renderiza input type=password com autocomplete=new-password e sem botão quando não há JS", () => {
    const html = renderToStaticMarkup(
      createElement(CampoDeSenha, {
        id: "senha",
        name: "senha",
        autoComplete: "new-password",
        required: true,
        minLength: 8,
      }),
    );

    expect(html).toContain('type="password"');
    expect(html.toLowerCase()).toContain('autocomplete="new-password"');
    expect(html.toLowerCase()).toContain('spellcheck="false"');
    expect(html).not.toContain("<button");
    expect(html).not.toContain("Mostrar senha");
  });
});

describe("CampoDeSenha (cliente: alternância, cursor e retorno a oculto)", () => {
  it("alterna entre oculto e visível e sempre volta a oculto em envio, segundo plano ou saída", () => {
    expect(reduzirVisibilidadeSenha(false, "alternar")).toBe(true);
    expect(reduzirVisibilidadeSenha(true, "alternar")).toBe(false);
    expect(reduzirVisibilidadeSenha(true, "ocultar_envio")).toBe(false);
    expect(reduzirVisibilidadeSenha(true, "ocultar_segundo_plano")).toBe(false);
    expect(reduzirVisibilidadeSenha(true, "ocultar_saida")).toBe(false);
  });

  it("oculta ao receber visibilitychange com hidden=true ou pagehide e limpa listeners ao desmontar", () => {
    const docListeners = new Map<string, () => void>();
    const winListeners = new Map<string, () => void>();
    const fakeDoc = {
      hidden: false,
      addEventListener: vi.fn((ev: string, fn: () => void) => docListeners.set(ev, fn)),
      removeEventListener: vi.fn((ev: string) => docListeners.delete(ev)),
    };
    const fakeWin = {
      addEventListener: vi.fn((ev: string, fn: () => void) => winListeners.set(ev, fn)),
      removeEventListener: vi.fn((ev: string) => winListeners.delete(ev)),
    };
    const aoOcultar = vi.fn();

    const limpar = vincularOcultacaoEmSegundoPlano(
      fakeDoc as unknown as Document,
      fakeWin as unknown as Window,
      aoOcultar,
    );

    // visibilitychange com hidden=false não oculta
    docListeners.get("visibilitychange")?.();
    expect(aoOcultar).not.toHaveBeenCalled();

    // visibilitychange com hidden=true oculta
    fakeDoc.hidden = true;
    docListeners.get("visibilitychange")?.();
    expect(aoOcultar).toHaveBeenCalledTimes(1);

    // pagehide oculta
    winListeners.get("pagehide")?.();
    expect(aoOcultar).toHaveBeenCalledTimes(2);

    // cleanup remove ambos os listeners
    limpar();
    expect(fakeDoc.removeEventListener).toHaveBeenCalledWith("visibilitychange", expect.any(Function));
    expect(fakeWin.removeEventListener).toHaveBeenCalledWith("pagehide", expect.any(Function));
  });

  it("restaura foco e posição do cursor/seleção após alternar o tipo do input", () => {
    const focus = vi.fn();
    const setSelectionRange = vi.fn();
    restaurarSelecaoAposAlternar({ focus, setSelectionRange }, { inicio: 3, fim: 3, manterFoco: true });
    expect(focus).toHaveBeenCalledWith({ preventScroll: true });
    expect(setSelectionRange).toHaveBeenCalledWith(3, 3);
  });
});
