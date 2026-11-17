/* Prova independente do Lince Codex no #843 (retornos/WEB-V1-revisao-843-provas), copiada como veio. */
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

describe("Lince #843, sessão, desistência e UI",()=>{
 it("Origin ausente/externo barra ambas as actions antes do Auth",async()=>{
  for(const sufixo of ["",".data"])for(const origem of [null,"https://outro.example"])for(const intencao of ["a_caminho","desistir"]){pedidos=[];const r=await pedir(`turnos/${A}${sufixo}`,{intencao,turno_id:A,posicao_id:A,motivo:"imprevisto"},origem);expect(r.status).toBe(403);expect(pedidos).toHaveLength(0);}
 });
 it("sem sessão ou Auth recusado/fora nenhuma action escreve",async()=>{
  for(const status of [0,403,503])for(const sufixo of ["",".data"])for(const intencao of ["a_caminho","desistir"]){pedidos=[];authStatus=status||200;const r=await pedir(`turnos/${A}${sufixo}`,{intencao,turno_id:A,posicao_id:A,motivo:"imprevisto"},"https://frilabr.com",status?A:null);await r.text();expect(envios()).toHaveLength(0);expect(conferencias()).toHaveLength(status?1:0);}
 });
 it("turno alheio é 404 em HTML e .data; lista e detalhe não expõem token/campos extras",async()=>{
  for(const sufixo of ["",".data"]){let r=await pedir(`turnos/${B}${sufixo}`);let txt=await r.text();expect(r.status).toBe(404);expect(txt).not.toContain("Casa-A");
   for(const path of [`turnos${sufixo}`,`turnos/${A}${sufixo}`]){r=await pedir(path);txt=await r.text();expect(r.status).toBe(200);expect(txt).not.toContain(token(A));expect(txt).not.toContain("TELEFONE-PRIVADO");expect(txt).not.toContain("TEXTO-PRIVADO");expect(r.headers.get("Cache-Control")).toBe("private, no-store");}
  }
 });
 it("desistir requer motivo, aviso prévio e POST; GET com intenção não cancela",async()=>{
  const r=await pedir(`turnos/${A}?intencao=desistir&posicao_id=${A}&motivo=imprevisto`),txt=await r.text();expect(r.status).toBe(200);expect(txt).toContain("24 horas");expect(txt).toContain('name="motivo"');expect(txt).toContain('minLength="3"');expect(txt).toContain('required=""');expect(txt).toContain('method="post"');expect(envios()).toHaveLength(0);
  for(const motivo of ["","ok","  "]){const r=await pedir(`turnos/${A}.data`,{intencao:"desistir",posicao_id:A,motivo});expect(await r.text()).toContain("motivo_curto");}expect(envios()).toHaveLength(0);
 });
 it("não assume a falta nem a identidade do formulário: só envia posição e motivo com token A",async()=>{
  for(const valor of [true,false]){pedidos=[];falta=valor;const r=await pedir(`turnos/${A}.data`,{intencao:"desistir",posicao_id:A,motivo:"  imprevisto em casa  ",profissional_id:B,usuario_id:B,falta:String(!valor),reaberta:"true"});const txt=await r.text();expect(txt).toContain(valor?"desistiu_com_falta":"desistiu");if(!valor)expect(txt).not.toContain("desistiu_com_falta");expect(envios()).toHaveLength(1);expect(conferencias()).toHaveLength(1);expect(await envios()[0]!.json()).toEqual({posicao_id:A,motivo:"imprevisto em casa"});expect(envios()[0]!.headers.get("Authorization")).toBe(`Bearer ${token(A)}`);}
 });
 it("posição alheia não cancela; recusas do servidor viram avisos",async()=>{
  let r=await pedir(`turnos/${A}.data`,{intencao:"desistir",posicao_id:B,motivo:"imprevisto"});let txt=await r.text();expect(txt).toContain("nao_encontrada");expect(txt).not.toContain("INTERNO-PRIVADO");
  for(const [status,erro,resultado] of [[409,{code:"posicao_nao_cancelavel"},"nao_cancelavel"],[422,{code:"campo_invalido",details:"motivo"},"motivo_recusado"],[422,{code:"campo_obrigatorio",details:"motivo"},"motivo_curto"],[403,{code:"sem_permissao"},"sem_permissao"]] as const){postStatus=status;postErro={...erro,message:"INTERNO-PRIVADO"};r=await pedir(`turnos/${A}.data`,{intencao:"desistir",posicao_id:A,motivo:"imprevisto"});txt=await r.text();expect(txt).toContain(resultado);expect(txt).not.toContain("INTERNO-PRIVADO");}
  postStatus=422;postErro={code:"a_caminho_fora_da_janela"};r=await pedir(`turnos/${A}.data`,{intencao:"a_caminho",turno_id:A});expect(await r.text()).toContain("fora_da_janela");
 });
 it("após o início não promete reoferecer a vaga antes de confirmar a desistência",async()=>{
  // O contrato permite cancelar posição confirmada após início, mas reaberta=false; sem check-in há formulário.
  const r=await pedir(`turnos/${A}`),txt=await r.text();expect(r.status).toBe(200);expect(txt).toContain('value="desistir"');
  expect(txt).not.toContain("A vaga volta a ser oferecida.");
 });
});
