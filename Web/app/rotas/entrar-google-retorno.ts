import { concluirEntradaSocial } from "../servidor/social";
import type { Route } from "./+types/entrar-google-retorno";

export async function loader({ request, context }: Route.LoaderArgs) {
  return concluirEntradaSocial("google", request, context);
}
