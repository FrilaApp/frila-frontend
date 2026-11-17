/* Prova do Lince Codex no #848 (delta, versão estável), copiada; o último teste foi adaptado ao formulário novo. */
/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-non-null-assertion */
import {beforeEach,afterEach,describe,expect,it,vi} from "vitest";
import {createRequestHandler,UNSAFE_withComponentProps,UNSAFE_withErrorBoundaryProps} from "react-router";
import * as root from "../app/root";
import * as turno from "../app/rotas/profissional/turno";
import * as denunciar from "../app/rotas/profissional/denunciar";
import * as bloqueados from "../app/rotas/profissional/bloqueados";
import * as chamada from "../app/rotas/profissional/chamada";
import * as vaga from "../app/rotas/profissional/vaga";
import * as entry from "../app/entry.server";
import {cookiesDaSessao} from "../app/servidor/sessao";
import {respostaAntesDoApp} from "../app/servidor/porteiro";
import {comCabecalhosDeSeguranca} from "../app/servidor/cabecalhos";
vi.mock("cloudflare:workers",()=>({env:{WEB_LIGADA:"1",AMBIENTE:"dev",SUPABASE_URL:"https://sintetico.supabase.co",SUPABASE_CHAVE_PUBLICAVEL:"sb_publishable_sintetica"}}));
const A="11111111-1111-4111-8111-111111111111",B="22222222-2222-4222-8222-222222222222";
const EXP=Math.floor(Date.now()/1000)+3600;
const token=(id:string)=>`a.${btoa(JSON.stringify({sub:id,exp:EXP}))}.assinatura-${id}`;
const cookie=(id:string)=>cookiesDaSessao({access_token:token(id),refresh_token:`r-${id}`,expires_in:3600,token_type:"bearer"},true).map(x=>x.split(";")[0]).join("; ");

const CASA="33333333-3333-4333-8333-333333333333",INTERNO="44444444-4444-4444-8444-444444444444";
const RELATO="RELATO-SINTETICO-SIGILOSO",CHAVE="55555555-5555-4555-8555-555555555555";
let pedidos:any[],authStatus=200,bloqueioFalha=false,perderResposta=false,ocorrencias:Map<string,string>,listas:Map<string,Set<string>>;
const logs=()=>[vi.spyOn(console,"log").mockImplementation(()=>{}),vi.spyOn(console,"error").mockImplementation(()=>{}),vi.spyOn(console,"warn").mockImplementation(()=>{})];
const comum=()=>({id:A,estabelecimento_id:INTERNO,funcao:{nome:"Garçom"},outra_parte:{id:CASA,nome:"Casa pública"},inicio_em:new Date().toISOString(),fim_em:new Date(Date.now()+3600000).toISOString(),valor_centavos:10000,regiao_administrativa:"Plano Piloto",inclui_refeicao:false,inclui_transporte:false,exige_material_proprio:false,estado:"aberta",expira_em:new Date(Date.now()+3600000).toISOString()});
beforeEach(()=>{pedidos=[];authStatus=200;bloqueioFalha=false;perderResposta=false;ocorrencias=new Map();listas=new Map([[A,new Set([CASA])],[B,new Set([INTERNO])]]);vi.stubGlobal("fetch",async(entrada:any,init:any)=>{
 const r=new Request(entrada,init),u=new URL(r.url);pedidos.push(r.clone());const autor=r.headers.get("Authorization")?.includes(token(B))?B:A;
 if(u.pathname.endsWith("/user"))return new Response(null,{status:authStatus});
 if(u.pathname.endsWith("/listar_bloqueios"))return Response.json([...listas.get(autor)!].map(alvo=>({alvo_tipo:"estabelecimento",alvo_id:alvo,nome:autor===A?"Casa de A":"Casa de B",usuario_id:"PRIVADO-EXTRA"})));
 if(u.pathname.endsWith("/detalhe_chamada"))return Response.json(comum());
 if(u.pathname.endsWith("/detalhe_vaga"))return Response.json({...comum(),estado:"publicada",posicoes_abertas:1,estabelecimento:{id:CASA,nome:"Casa pública"},inclusos:{inclui_refeicao:false,inclui_transporte:false,exige_material_proprio:false}});
 if(u.pathname.endsWith("/minhas_candidaturas"))return Response.json([]);
 if(u.pathname.endsWith("/meus_turnos"))return Response.json([{id:A,posicao_id:A,vaga:{id:A,funcao:"Garçom",local:"Local",regiao_administrativa:"Plano Piloto",inicio_em:new Date().toISOString(),fim_em:new Date(Date.now()+3600000).toISOString(),valor_centavos:10000},contraparte:{id:CASA,nome:"Casa pública"},estabelecimento_id:INTERNO,a_caminho_em:null,checkin_em:null,checkout_em:null,verificacao:"pendente",valor_acordado_centavos:10000,pode_avaliar:false,estado:"confirmada"}]);
 if(r.method==="POST"){
  const body:any=await r.json();
  if(u.pathname.endsWith("/denunciar")){const k=`${autor}:${body.chave}`;if(!ocorrencias.has(k))ocorrencias.set(k,crypto.randomUUID());if(perderResposta)throw new Error("resposta perdida "+RELATO);return Response.json({ocorrencia_id:ocorrencias.get(k),tipo:"denuncia",relato:RELATO,usuario_id:B});}
  if(u.pathname.endsWith("/bloquear")){if(bloqueioFalha)return Response.json({code:"indisponivel",message:RELATO},{status:503});listas.get(autor)!.add(body.alvo_id);return Response.json({alvo_tipo:"estabelecimento",alvo_id:body.alvo_id});}
  if(u.pathname.endsWith("/desbloquear")){listas.get(autor)!.delete(body.alvo_id);return Response.json({alvo_tipo:"estabelecimento",alvo_id:body.alvo_id});}
 }
 throw new Error("inesperado "+u.pathname);
});});
afterEach(()=>{vi.restoreAllMocks();vi.unstubAllGlobals();});
const routes:any={root:{id:"root",path:"",module:root},denunciar:{id:"denunciar",parentId:"root",path:"denunciar",module:denunciar},bloqueados:{id:"bloqueados",parentId:"root",path:"bloqueados",module:bloqueados},chamada:{id:"chamada",parentId:"root",path:"chamadas/:chamadaId",module:chamada},vaga:{id:"vaga",parentId:"root",path:"vagas/:vagaId",module:vaga},turno:{id:"turno",parentId:"root",path:"turnos/:turnoId",module:turno}};
for(const r of Object.values(routes) as any[]){r.module={...r.module,default:UNSAFE_withComponentProps(r.module.default),...(r.module.ErrorBoundary?{ErrorBoundary:UNSAFE_withErrorBoundaryProps(r.module.ErrorBoundary)}:{})};}
const manifest:any={};for(const [id,r] of Object.entries(routes) as any)manifest[id]={id,parentId:r.parentId,path:r.path,module:`/app/${id}.js`,imports:[],css:[],hasLoader:!!r.module.loader,hasAction:!!r.module.action,hasErrorBoundary:!!r.module.ErrorBoundary};
const handler=createRequestHandler({entry:{module:entry},routes,assets:{version:"teste",url:"/app/manifest.js",routes:manifest,entry:{module:"/app/entry.js",imports:[]}},basename:"/app",publicPath:"/app/",assetsBuildDirectory:"",future:{},ssr:true,isSpaMode:false,prerender:[],routeDiscovery:{mode:"initial",manifestPath:"/__manifest"}} as never,"test");
async function pedir(path:string,campos:Record<string,string>|null=null,origem:string|null="https://frilabr.com",id:string|null=A){const r=new Request(`https://frilabr.com/app/${path}`,{method:campos?"POST":"GET",headers:{...(id?{Cookie:cookie(id)}:{}),...(origem?{Origin:origem}:{})},...(campos?{body:new URLSearchParams(campos)}:{})});return comCabecalhosDeSeguranca(respostaAntesDoApp(r,{webLigada:true})??await handler(r));}
const envios=()=>pedidos.filter(r=>r.method==="POST"),conferencias=()=>pedidos.filter(r=>new URL(r.url).pathname.endsWith("/user"));
const dados=(chave=CHAVE)=>({alvo:CASA,turno:A,motivo:"assedio",relato:RELATO,chave});
const chaveDo=(html:string)=>{const c=/name="chave" value="([0-9a-f-]{36})"/.exec(html)?.[1];expect(c).toBeTruthy();return c!;};
describe("Lince delta #848: reenvio real do formulário",()=>{
 it("denúncia salva: HTML oferece só bloquear e reenvios com falha e sucesso não voltam a denunciar",async()=>{
  bloqueioFalha=true;const path=`denunciar?alvo=${CASA}`;const k=chaveDo(await (await pedir(path)).text());
  const txt=await (await pedir(path,{...dados(k),bloquear:"sim"})).text();
  const protocolo=[...ocorrencias.values()][0]!.replace(/-/g,"").slice(0,8).toUpperCase();
  expect(txt).toContain(protocolo);expect(chaveDo(txt)).toBe(k);expect(txt).toContain('name="intencao" value="bloquear"');expect(txt).not.toContain('name="relato"');expect(txt).not.toContain('name="motivo"');expect(txt.match(/<form /g)).toHaveLength(1);
  for(const falhar of [true,true,false]){bloqueioFalha=falhar;pedidos=[];const retry=await (await pedir(path,{alvo:CASA,chave:k,intencao:"bloquear"})).text();expect(conferencias()).toHaveLength(1);expect(envios()).toHaveLength(1);expect(envios()[0]!.url).toContain('/rpc/bloquear');expect(ocorrencias.size).toBe(1);expect(retry).not.toContain('name="relato"');if(falhar)expect(chaveDo(retry)).toBe(k);else expect(retry).not.toContain('<form ');}
 });
 it("resposta perdida: chave persiste por dois erros e confirmação encerra o formulário sem duplicata",async()=>{
  perderResposta=true;const path=`denunciar?alvo=${CASA}`;const k=chaveDo(await (await pedir(path)).text());
  for(const perder of [true,true,false]){perderResposta=perder;const txt=await (await pedir(path,dados(k))).text();expect(ocorrencias.size).toBe(1);expect(txt).not.toContain(RELATO);if(perder)expect(chaveDo(txt)).toBe(k);else {expect(txt).not.toContain('<form ');expect(txt).toContain([...ocorrencias.values()][0]!.replace(/-/g,"").slice(0,8).toUpperCase());}}
 });
 it("erro em .data devolve a chave e não devolve relato, token ou mensagem interna",async()=>{
  const espias=logs();for(const parcial of [false,true]){pedidos=[];bloqueioFalha=parcial;perderResposta=!parcial;const txt=await (await pedir(`denunciar.data?alvo=${CASA}`,{...dados(),...(parcial?{bloquear:"sim"}:{})})).text();expect(txt).toContain(CHAVE);expect(txt).not.toContain(RELATO);expect(txt).not.toContain(token(A));expect(conferencias()).toHaveLength(1);}for(const e of espias)expect(JSON.stringify(e.mock.calls)).not.toContain(RELATO);
 });
 it("MENOR: protocolo confirmado permanece visível se repetir só o bloqueio falhar novamente",async()=>{
  bloqueioFalha=true;const path=`denunciar?alvo=${CASA}`;const txt=await (await pedir(path,{...dados(),bloquear:"sim"})).text();const protocolo=[...ocorrencias.values()][0]!.replace(/-/g,"").slice(0,8).toUpperCase();expect(txt).toContain(protocolo);
  // Adaptado pela Safira: o retry envia os campos que o formulário de "só bloquear" mostra agora (inclui o protocolo).
  const campo=(nome:string)=>new RegExp(`name="${nome}" value="([^"]*)"`).exec(txt)?.[1]??"";
  const retry=await (await pedir(path,{alvo:CASA,chave:CHAVE,intencao:"bloquear",protocolo:campo("protocolo")})).text();expect(retry).toContain(protocolo);
  expect(campo("protocolo")).toBe(protocolo);
 });
});
