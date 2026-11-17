/* Prova independente do Lince Codex no #848 (retornos/WEB-V1-revisao-848-provas), copiada como veio. */
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
// Ajuste da Safira: o vencimento é calculado uma vez (duas chamadas em segundos diferentes davam tokens diferentes).
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
describe("Lince #848: denúncia e bloqueios",()=>{
 it("sessão Auth e Origin próprios obrigatórios em denunciar, bloquear e desbloquear HTML/.data",async()=>{
  for(const sufixo of ["",".data"])for(const [path,campos] of [["denunciar",dados()],["denunciar",{alvo:CASA,intencao:"bloquear"}],["bloqueados",{alvo:CASA}]] as const){for(const origem of [null,"null","https://outro.example"]){pedidos=[];expect((await pedir(path+sufixo,campos,origem)).status).toBe(403);expect(pedidos).toHaveLength(0);}for(const status of [0,401,503]){pedidos=[];authStatus=status||200;await (await pedir(path+sufixo,campos,"https://frilabr.com",status?A:null)).text();expect(envios()).toHaveLength(0);expect(conferencias()).toHaveLength(status?1:0);}authStatus=200;}
 });
 it("relato apenas no POST; logs, URL, resposta, protocolo extra e token não o revelam; autoria da sessão",async()=>{
  const espias=logs();for(const sufixo of ["",".data"]){pedidos=[];const r=await pedir(`denunciar${sufixo}?alvo=${CASA}`,{...dados(),usuario_id:B,denunciante_id:B,autor_id:B}),txt=await r.text();expect(txt).not.toContain(RELATO);expect(txt).not.toContain(token(A));expect(envios()).toHaveLength(1);expect(conferencias()).toHaveLength(1);expect(await envios()[0]!.json()).toEqual({alvo_tipo:"estabelecimento",alvo_id:CASA,turno_id:A,motivo:"assedio",relato:RELATO,chave:CHAVE});expect(envios()[0]!.headers.get("Authorization")).toBe(`Bearer ${token(A)}`);expect(pedidos.every(r=>!r.url.includes(RELATO))).toBe(true);expect(r.headers.get("Cache-Control")).toBe("private, no-store");}for(const e of espias)expect(JSON.stringify(e.mock.calls)).not.toContain(RELATO);
 });
 it("vaga, turno e chamada usam id público da casa, distinto do interno, em HTML/.data",async()=>{
  for(const sufixo of ["",".data"])for(const path of [`vagas/${A}`,`turnos/${A}`,`chamadas/${A}`]){const r=await pedir(path+sufixo),txt=await r.text();expect(r.status).toBe(200);expect(txt).toContain(CASA);expect(txt).not.toContain(INTERNO);if(!sufixo)expect(txt).toContain(`/app/denunciar?alvo=${CASA}`);}
 });
 it("lista/desbloquear usam token próprio e não aceitam autor forjado; não desfazem bloqueio de B",async()=>{
  for(const sufixo of ["",".data"]){const txt=await (await pedir("bloqueados"+sufixo)).text();expect(txt).toContain("Casa de A");expect(txt).not.toContain("Casa de B");expect(txt).not.toContain("PRIVADO-EXTRA");pedidos=[];await pedir("bloqueados"+sufixo,{alvo:INTERNO,usuario_id:B,autor_id:B});expect(listas.get(B)!.has(INTERNO)).toBe(true);expect(await envios()[0]!.json()).toEqual({alvo_tipo:"estabelecimento",alvo_id:INTERNO});expect(envios()[0]!.headers.get("Authorization")).toBe(`Bearer ${token(A)}`);expect(conferencias()).toHaveLength(1);}
 });
 it("chave de formulários distintos é nova; reenviar mesma chave conserva ocorrência; GET não escreve",async()=>{
  const k1=chaveDo(await (await pedir(`denunciar?alvo=${CASA}`)).text()),k2=chaveDo(await (await pedir(`denunciar?alvo=${CASA}`)).text());expect(k1).not.toBe(k2);expect(envios()).toHaveLength(0);await pedir("denunciar.data",dados(k1));await pedir("denunciar.data",dados(k1));expect(ocorrencias.size).toBe(1);
 });
 it("falha só no bloqueio deve manter a chave do formulário para retry sem duplicar a denúncia já salva",async()=>{
  bloqueioFalha=true;const path=`denunciar?alvo=${CASA}`;const k1=chaveDo(await (await pedir(path)).text());const falhou=await (await pedir(path,{...dados(k1),bloquear:"sim"})).text();expect(ocorrencias.size).toBe(1);const k2=chaveDo(falhou);await pedir(path,{...dados(k2),bloquear:"sim"});expect(ocorrencias.size).toBe(1);
 });
 it("resposta perdida após gravar deve conservar chave para retry idempotente",async()=>{
  perderResposta=true;const path=`denunciar?alvo=${CASA}`;const k1=chaveDo(await (await pedir(path)).text());const falhou=await (await pedir(path,dados(k1))).text();const k2=chaveDo(falhou);await pedir(path,dados(k2));expect(ocorrencias.size).toBe(1);
 });
});
