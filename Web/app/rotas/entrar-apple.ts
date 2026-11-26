import { iniciarEntradaSocial } from "../servidor/social";
import type { Route } from "./+types/entrar-apple";

export async function loader({ request, context }: Route.LoaderArgs) {
  return iniciarEntradaSocial("apple", request, context);
}
