/**
 * Prova do Lince Codex na 3ª rodada do #835 (copiada de /tmp/lince-pr835-34ea501e), com o Auth do Supabase simulado
 * no fetch. Os 2 últimos testes foram ADAPTADOS à decisão do Prisma (17/11): com o Auth falhando no sair, o sair não
 * se dá por concluído (volta com o aviso, os cookies ficam); com o Auth de volta, a pessoa sai de verdade, e a
 * renovação retida que chega depois é barrada. Antes, eles afirmavam o defeito (302 para /entrar com os cookies apagados).
 */
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RouterContextProvider } from "react-router";
import { criarAuth } from "../app/servidor/auth";
import { contextoDaSessao } from "../app/contexto";
import { middlewareDeSessao } from "../app/servidor/middleware-de-sessao";
import { action as sair } from "../app/rotas/sair";
import { cookiesDaSessao, type SessaoAtual } from "../app/servidor/sessao";
const estado = vi.hoisted(()=>({auth:null as unknown}));
vi.mock("../app/servidor/deste-ambiente",()=>({authDesteAmbiente:()=>estado.auth}));
const agora=Math.floor(Date.now()/1000);
const token=(id:string,vida=3600)=>`cabecalho.${btoa(JSON.stringify({sub:id,session_id:id,exp:agora+vida}))}.assinatura-${id}-${vida}`;
const sessao=(id:string,vida=3600)=>({access_token:token(id,vida),refresh_token:`r-${id}`,token_type:"bearer" as const,expires_in:vida});
const cookieDe=(id:string,vida=3600)=>cookiesDaSessao(sessao(id,vida),true).map(c=>c.split(";")[0]).join("; ");
const idDe=(t:string)=>JSON.parse(atob((t.split(".")[1] ?? ""))).session_id as string;
let ativas:Set<string>, falhaUser:boolean, falhaLogout:boolean, chamadas:string[];
beforeEach(()=>{
 ativas=new Set(["A","B"]);falhaUser=false;falhaLogout=false;chamadas=[];
 estado.auth=criarAuth({url:"https://sintetico.supabase.co",chavePublicavel:"chave-sintetica"},{fetch:async(entrada,inicio)=>{
  const r=new Request(entrada,inicio);const u=new URL(r.url);chamadas.push(u.pathname);
  if(u.pathname.endsWith("/user")){
   if(falhaUser)return new Response(null,{status:503});
   const id=idDe((r.headers.get("Authorization") ?? "").slice(7));
   return ativas.has(id)?Response.json({id}):Response.json({error_code:"session_not_found"},{status:403});
  }
  if(u.pathname.endsWith("/token")){
   const id=((await r.json()) as { refresh_token: string }).refresh_token.slice(2);
   return ativas.has(id)?Response.json(sessao(id)):new Response(null,{status:400});
  }
  if(u.pathname.endsWith("/logout")){
   if(falhaLogout)return new Response(null,{status:503});
   ativas.delete(idDe((r.headers.get("Authorization") ?? "").slice(7)));
   return new Response(null,{status:204});
  }
  throw new Error(`endpoint inesperado ${u.pathname}`);
 }});
});
const args=(cookie:string,metodo="GET")=>({request:new Request(`https://frilabr.com/app/${metodo==="POST"?"sair":""}`,{method:metodo,headers:{Origin:"https://frilabr.com",Cookie:cookie}}),context:new RouterContextProvider(),params:{},matches:[]});
async function pedir(cookie:string){const a=args(cookie);let vista:SessaoAtual|null=null;const resposta=await middlewareDeSessao(a as never,async()=>{vista=a.context.get(contextoDaSessao);return new Response("ok");}) as Response;return {vista,resposta};}
async function sairCom(cookie:string){const a=args(cookie,"POST");return await middlewareDeSessao(a as never,async()=>{try{await sair(a as never);}catch(r){if(r instanceof Response)return r;throw r;}throw new Error("faltou redirect");}) as Response;}
function pote(){const m=new Map<string,string>();return {aplicar(l:string[]){for(const c of l){const par=(c.split(";")[0] ?? "");const i=par.indexOf("=");if(c.includes("Max-Age=0"))m.delete(par.slice(0,i));else m.set(par.slice(0,i),par.slice(i+1));}},cookie(){return [...m].map(([k,v])=>`${k}=${v}`).join("; ");}};}
async function renovacaoRetida(id="A"){
 const a=args(cookieDe(id,30));let soltar!:()=>void,chegou!:()=>void;
 const espera=new Promise<void>(r=>chegou=r),pausa=new Promise<void>(r=>soltar=r);
 const emVoo=middlewareDeSessao(a as never,async()=>{chegou();await pausa;return new Response("leitura autorizada antes de sair");}) as Promise<Response>;
 await espera;return {emVoo,soltar};
}
describe("Lince r3, Auth e saída concorrente",()=>{
 it("A→B, duas saídas de A e renovação B realmente retida não reativam B",async()=>{
  const jar=pote();jar.aplicar(cookiesDaSessao(sessao("A"),true));
  const saidas=await Promise.all([sairCom(jar.cookie()),sairCom(jar.cookie())]);
  jar.aplicar(saidas[0]?.headers.getSetCookie() ?? []);
  jar.aplicar(cookiesDaSessao(sessao("B",30),true));
  const pendente=await renovacaoRetida("B");
  jar.aplicar((await sairCom(cookieDe("B"))).headers.getSetCookie());
  jar.aplicar(saidas[1]?.headers.getSetCookie() ?? []);
  pendente.soltar();jar.aplicar((await pendente.emVoo).headers.getSetCookie());
  expect((await pedir(jar.cookie())).vista).toBeNull();
 });
 it("marca apagada ou forjada não reativa; só refresh antigo também é recusado",async()=>{
  await sairCom(cookieDe("A"));
  for(const c of [cookieDe("A"),`${cookieDe("A")}; __Host-frila-encerradas=outra`,`__Host-frila-renovacao=r-A`]){
   expect((await pedir(c)).vista).toBeNull();
  }
 });
 it("uma validação por pedido: token folgado, perto de vencer e sem cookie",async()=>{
  await pedir(cookieDe("A"));expect(chamadas).toEqual(["/auth/v1/user"]);
  chamadas=[];await pedir(cookieDe("A",30));expect(chamadas).toEqual(["/auth/v1/token"]);
  chamadas=[];await pedir("");expect(chamadas).toEqual([]);
 });
 for(const falha of ["user","logout"]){
  it(`Auth falha em ${falha} durante sair: renovação retida não pode reativar a sessão`,async()=>{
   const jar=pote();jar.aplicar(cookiesDaSessao(sessao("A",30),true));
   const pendente=await renovacaoRetida();
   // Outra leitura termina a renovação antes: o pote já tem o token folgado.
   jar.aplicar((await pedir(jar.cookie())).resposta.headers.getSetCookie());
   // A falha atinge a conferência ou a revogação no logout seguinte.
   falhaUser=falha==="user";falhaLogout=falha==="logout";
   const saida=await sairCom(jar.cookie());
   // Decisão: sem a revogação confirmada, o sair não conclui: volta com o aviso e não apaga os cookies.
   expect(saida.status).toBe(302);expect(saida.headers.get("Location")).toBe("/?sair=falhou");
   expect(saida.headers.getSetCookie().filter(c=>c.includes("Max-Age=0"))).toEqual([]);
   jar.aplicar(saida.headers.getSetCookie());expect(jar.cookie()).not.toBe("");
   expect(ativas.has("A"),"a sessão segue viva no Auth: por isso o sair não pode dizer que saiu").toBe(true);
   // O Auth volta e a pessoa tenta de novo: agora a revogação se confirma.
   falhaUser=false;falhaLogout=false;
   const deNovo=await sairCom(jar.cookie());
   expect(deNovo.headers.get("Location")).toBe("/entrar");
   jar.aplicar(deNovo.headers.getSetCookie());expect(jar.cookie()).toBe("");
   expect(ativas.has("A")).toBe(false);
   // A renovação retida chega depois: o Auth já não tem a sessão, e ela não volta.
   pendente.soltar();jar.aplicar((await pendente.emVoo).headers.getSetCookie());
   const seguinte=await pedir(jar.cookie());
   expect(seguinte.vista,"Sair pareceu concluir, mas o Auth nunca encerrou a sessão").toBeNull();
  });
 }
});
