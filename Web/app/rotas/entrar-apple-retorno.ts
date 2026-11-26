import { concluirEntradaSocial } from "../servidor/social";
import type { Route } from "./+types/entrar-apple-retorno";

export async function loader({ request, context }: Route.LoaderArgs) {
  return concluirEntradaSocial("apple", request, context);
}
