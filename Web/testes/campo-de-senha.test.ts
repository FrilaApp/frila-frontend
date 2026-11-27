import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { CampoDeSenha } from "../app/componentes/campo-de-senha";

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
