/* Prova independente do Lince Codex no #844 (retornos/WEB-V1-revisao-844-provas), copiada como veio. */
/* eslint-disable @typescript-eslint/no-explicit-any */
import {describe,it,vi,expect,afterEach} from "vitest";
const estado=vi.hoisted(()=>({lendo:false,enviar:vi.fn(),campo:{current:{value:"20"}}}));
vi.mock("react",async(importOriginal)=>({...await importOriginal<typeof import("react")>(),useRef:()=>estado.campo,useState:()=>[estado.lendo,(v:boolean)=>{estado.lendo=v;}]}));
vi.mock("react-router",()=>({Form:"form",useSubmit:()=>estado.enviar}));
import {FormularioDePresenca} from "../app/rotas/profissional/localizacao";
afterEach(()=>{vi.unstubAllGlobals();vi.useRealTimers();estado.lendo=false;estado.enviar.mockReset();});
const render=()=>FormularioDePresenca({destino:{latitude:-15,longitude:-47},textoLendo:"lendo"});
const evento=()=>({currentTarget:{},preventDefault:vi.fn()});
describe("Lince #844: formulário aguardando posição",()=>{
 it("segundo toque durante a leitura deve continuar bloqueado",async()=>{
  let concluir:any;vi.stubGlobal("navigator",{geolocation:{getCurrentPosition:(ok:any)=>{concluir=ok;}}});
  const primeiro=evento();render().props.onSubmit(primeiro);expect(primeiro.preventDefault).toHaveBeenCalled();expect(estado.lendo).toBe(true);
  const segundo=evento();render().props.onSubmit(segundo);
  // Form do React Router prossegue com a submissão se onSubmit não tiver prevenido o evento.
  expect(segundo.preventDefault).toHaveBeenCalled();
  concluir({coords:{latitude:-15,longitude:-47}});await Promise.resolve();
 });
 it("fallback deve encerrar a espera em dez segundos mesmo sem callback do navegador",async()=>{
  vi.useFakeTimers();vi.stubGlobal("navigator",{geolocation:{getCurrentPosition:vi.fn()}});render().props.onSubmit(evento());await vi.advanceTimersByTimeAsync(10000);expect(estado.enviar).toHaveBeenCalledTimes(1);
 });
});
