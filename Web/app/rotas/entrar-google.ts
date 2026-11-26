import { iniciarEntradaSocial } from "../servidor/social";
import type { Route } from "./+types/entrar-google";

export async function loader({ request, context }: Route.LoaderArgs) {
  return iniciarEntradaSocial("google", request, context);
}
