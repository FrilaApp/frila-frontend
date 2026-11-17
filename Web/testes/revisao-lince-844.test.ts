/* Prova independente do Lince Codex no #844 (retornos/WEB-V1-revisao-844-provas), copiada como veio. */
/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-non-null-assertion */
import {beforeEach,describe,expect,it,vi} from "vitest";
import {createRequestHandler,UNSAFE_withComponentProps,UNSAFE_withErrorBoundaryProps} from "react-router";
import * as root from "../app/root";
import * as turno from "../app/rotas/profissional/turno";
import * as turnos from "../app/rotas/profissional/turnos";
import * as entry from "../app/entry.server";
import {cookiesDaSessao} from "../app/servidor/sessao";
import {respostaAntesDoApp} from "../app/servidor/porteiro";
import {comCabecalhosDeSeguranca} from "../app/servidor/cabecalhos";
vi.mock("cloudflare:workers",()=>({env:{WEB_LIGADA:"1",AMBIENTE:"dev",SUPABASE_URL:"https://sintetico.supabase.co",SUPABASE_CHAVE_PUBLICAVEL:"sb_publishable_sintetica"}}));
const A="11111111-1111-4111-8111-111111111111",B="22222222-2222-4222-8222-222222222222";
const token=(id:string)=>`a.${btoa(JSON.stringify({sub:id,exp:Math.floor(Date.now()/1000)+3600}))}.assinatura-${id}`;
const cookie=(id:string)=>cookiesDaSessao({access_token:token(id),refresh_token:`r-${id}`,expires_in:3600,token_type:"bearer"},true).map(x=>x.split(";")[0]).join("; ");

let pedidos:any[],authStatus=200,postStatus=200,postErro:any,falta=true,inicioEm:string;
const registro=()=>({id:A,posicao_id:A,vaga:{id:A,funcao:"Garçom",local:"Asa Norte",regiao_administrativa:"Plano Piloto",inicio_em:inicioEm,fim_em:new Date(Date.now()+3600000).toISOString(),valor_centavos:15000,ponto:{latitude:-15,longitude:-47}},contraparte:{nome:"Casa-A",telefone:"TELEFONE-PRIVADO"},a_caminho_em:null,checkin_em:null,checkin_tipo:null,checkin_distancia_m:null,checkin_confirmado_em:null,checkout_em:null,checkout_distancia_m:null,verificacao:"pendente",valor_acordado_centavos:15000,pode_avaliar:false,estado:"confirmada",cancelamento:{motivo:"TEXTO-PRIVADO"}});
beforeEach(()=>{pedidos=[];authStatus=200;postStatus=200;postErro={};falta=true;inicioEm=new Date(Date.now()-1800000).toISOString();vi.stubGlobal("fetch",async(entrada:any,init:any)=>{
 const r=new Request(entrada,init),u=new URL(r.url);pedidos.push(r.clone());
 if(u.pathname.endsWith("/user"))return new Response(null,{status:authStatus});
 if(u.pathname.endsWith("/meus_turnos"))return Response.json([registro()]);
 if(r.method==="POST"){
  if(postStatus!==200)return Response.json(postErro,{status:postStatus});
  const body:any=await r.json();
  if((body.posicao_id??body.turno_id)!==A)return Response.json({code:"nao_encontrado",message:"INTERNO-PRIVADO"},{status:404});
  if(/\/(fazer_checkin|validar_codigo_checkin|fazer_checkout)$/.test(u.pathname))return Response.json({turno_id:A,tipo:"codigo",verificacao:"verificado",registrado_em:new Date().toISOString(),distancia_m:20});
  if(u.pathname.endsWith("/cancelar_posicao"))return Response.json({posicao_id:A,falta,reaberta:false,nova_posicao_id:null});
  if(u.pathname.endsWith("/avisar_a_caminho"))return Response.json({turno_id:A,a_caminho_em:new Date().toISOString()});
 }
 throw new Error(`pedido inesperado ${u.pathname}`);
});});
const routes:any={root:{id:"root",path:"",module:root},turno:{id:"turno",parentId:"root",path:"turnos/:turnoId",module:turno},turnos:{id:"turnos",parentId:"root",path:"turnos",module:turnos}};
for(const r of Object.values(routes) as any[]){r.module={...r.module,default:UNSAFE_withComponentProps(r.module.default),...(r.module.ErrorBoundary?{ErrorBoundary:UNSAFE_withErrorBoundaryProps(r.module.ErrorBoundary)}:{})};}
const manifest:any={};for(const [id,r] of Object.entries(routes) as any)manifest[id]={id,parentId:r.parentId,path:r.path,module:`/app/${id}.js`,imports:[],css:[],hasLoader:!!r.module.loader,hasAction:!!r.module.action,hasErrorBoundary:!!r.module.ErrorBoundary};
const handler=createRequestHandler({entry:{module:entry},routes,assets:{version:"teste",url:"/app/manifest.js",routes:manifest,entry:{module:"/app/entry.js",imports:[]}},basename:"/app",publicPath:"/app/",assetsBuildDirectory:"",future:{},ssr:true,isSpaMode:false,prerender:[],routeDiscovery:{mode:"initial",manifestPath:"/__manifest"}} as never,"test");
async function pedir(path:string,campos:Record<string,string>|null=null,origem:string|null="https://frilabr.com",id:string|null=A){const r=new Request(`https://frilabr.com/app/${path}`,{method:campos?"POST":"GET",headers:{...(id?{Cookie:cookie(id)}:{}),...(origem?{Origin:origem}:{})},...(campos?{body:new URLSearchParams(campos)}:{})});return comCabecalhosDeSeguranca(respostaAntesDoApp(r,{webLigada:true})??await handler(r));}
const envios=()=>pedidos.filter(r=>r.method==="POST");
const conferencias=()=>pedidos.filter(r=>new URL(r.url).pathname.endsWith("/user"));

describe("Lince #844: presença pelo handler real",()=>{
 it("Origin ausente, nulo ou externo barra todas as intenções antes do Auth",async()=>{
  for(const sufixo of ["",".data"])for(const origem of [null,"null","https://outro.example"])for(const intencao of ["chegar","validar","encerrar"]){pedidos=[];const r=await pedir(`turnos/${A}${sufixo}`,{intencao,turno_id:A,codigo:"482913",distancia_m:"20"},origem);expect(r.status).toBe(403);expect(pedidos).toHaveLength(0);}
 });
 it("sem sessão, Auth recusado ou indisponível não há escrita",async()=>{
  for(const status of [0,401,403,503])for(const sufixo of ["",".data"])for(const intencao of ["chegar","validar","encerrar"]){pedidos=[];authStatus=status||200;const r=await pedir(`turnos/${A}${sufixo}`,{intencao,turno_id:A,codigo:"482913",distancia_m:"20"},"https://frilabr.com",status?A:null);await r.text();expect(envios()).toHaveLength(0);expect(conferencias()).toHaveLength(status?1:0);}
 });
 it("uma validação Auth por pedido, somente metros e token do usuário decidido; nunca coordenada/identidade do form",async()=>{
  for(const sufixo of ["",".data"])for(const intencao of ["chegar","validar","encerrar"]){pedidos=[];const r=await pedir(`turnos/${A}${sufixo}`,{intencao,turno_id:A,codigo:"482913",distancia_m:"20",latitude:"-15",longitude:"-47",usuario_id:B,sinais:"privado",registrado_em:"2000-01-01"});const txt=await r.text();expect(r.status).toBe(200);expect(conferencias()).toHaveLength(1);expect(envios()).toHaveLength(1);const corpo=await envios()[0]!.json();expect(corpo).toEqual(intencao==="validar"?{turno_id:A,codigo:"482913",distancia_m:20}:{turno_id:A,distancia_m:20,registrado_em:expect.any(String)});expect(envios()[0]!.headers.get("Authorization")).toBe(`Bearer ${token(A)}`);expect(txt).not.toContain(token(A));expect(txt).not.toContain("TELEFONE-PRIVADO");}
 });
 it("distância vazia vai nula e recusa orienta confirmação pela casa; erro interno não vaza",async()=>{
  postStatus=422;postErro={code:"sem_localizacao",message:"INTERNO-PRIVADO"};const r=await pedir(`turnos/${A}`,{intencao:"validar",turno_id:A,codigo:"482913",distancia_m:""});const txt=await r.text();expect(await envios()[0]!.json()).toEqual({turno_id:A,codigo:"482913",distancia_m:null});expect(txt).toContain("peça à casa para confirmar");expect(txt).not.toContain("INTERNO-PRIVADO");
 });
 it("GET não escreve; turno alheio dá 404 e mutação alheia respeita a recusa do backend",async()=>{
  for(const sufixo of ["",".data"]){pedidos=[];expect((await pedir(`turnos/${B}${sufixo}`)).status).toBe(404);expect(envios()).toHaveLength(0);const r=await pedir(`turnos/${A}${sufixo}`,{intencao:"validar",turno_id:B,codigo:"482913",distancia_m:"20"});const txt=await r.text();expect(txt).toContain("nao_encontrado");expect(txt).not.toContain("INTERNO-PRIVADO");}
 });
});
