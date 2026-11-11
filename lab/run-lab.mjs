/** Node >=18. Sequential MT5 Strategy Tester experiments; no trading API. */
import fs from 'node:fs';
import path from 'node:path';
import {spawn,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import crypto from 'node:crypto';
import {decode} from '../automation/alien-monitor.mjs';
const HERE=path.dirname(fileURLToPath(import.meta.url)),ROOT=path.resolve(HERE,'..');
const EXPERT='ALIEN_V12_2_SCALP_LAB';
let activeOut=null;
export function makeCases(){
 const cases=[{id:'BASE_ORIGINAL',mode:0,r:3}];
 for(let mode=6;mode<=11;mode++)for(const r of [.75,1,1.5])cases.push({id:`H${mode}_R${String(r).replace('.','_')}`,mode,r});
 return cases;
}
function dateValid(s){if(!/^\d{4}\.\d{2}\.\d{2}$/.test(s))return false;const iso=s.replaceAll('.','-');const d=new Date(iso);return Number.isFinite(d.getTime())&&d.toISOString().slice(0,10)===iso;}
export function validate(c){
 if(!c.testTerminalDir||!(path.isAbsolute(c.testTerminalDir)||path.win32.isAbsolute(c.testTerminalDir)))throw Error('Informe testTerminalDir absoluto no configuracao.json.');
 if(!dateValid(c.from)||!dateValid(c.to)||c.from>=c.to)throw Error('Datas invalidas: from deve ser anterior a to.');
 if(typeof c.symbol!=='string'||!c.symbol.length||c.symbol.length>64||/[\r\n=]/.test(c.symbol))throw Error('Simbolo invalido.');
 for(const k of ['commissionPerLot','timeoutMinutes'])if(!Number.isFinite(c[k])||c[k]<0)throw Error('Valor invalido: '+k);
 if(c.timeoutMinutes<1)throw Error('Timeout minimo: 1 minuto.');
 return c;
}
export function inputs(item,c){
 // Same lot and risk CAP, not identical realized monetary risk for different stops.
 return {ScalpHypothesisMode:item.mode,ScalpLabTargetR:item.r,ScalpLabFixedExit:true,
  ScalpLabMaxChaseATR:.25,ScalpLabMinTargetCostRatio:3,AllowLiveRealTrading:false,
  FixedLot:.01,ExpertMagic:802220,MaxAdaptiveLot:.01,EnableEvidenceScaling:false,
  EnablePyramid:false,MaxOwnPositions:1,EnableZonePendingOrders:false,
  UseRiskRewardTakeProfit:true,RiskRewardMultiple:3,MaxRiskPercentEquity:.25,
  RoundTurnCommissionPerLot:c.commissionPerLot,
  // Avoid stopping an entire month after USD5: strategy research, not mesa calibration.
  DailyMaxLossMoney:25,WeeklyMaxLossMoney:75,TotalMaxLossMoney:200,RiskStopMoney:12.5,
  MaxFloatingLossMoney:12.5,DailyProfitTargetMoney:0,StopOnDailyProfitTarget:false};
}
export function makeIni(item,c,reportName){
 if(!/^[A-Z0-9_]+$/i.test(reportName))throw Error('Nome de relatorio invalido');
 return ['[Common]','NewsEnable=0','','[Experts]','Enabled=1','AllowLiveTrading=0','AllowDllImport=0','',
  '[Tester]',`Expert=ALIEN_RESEARCH\\${EXPERT}`,`ExpertParameters=ALIEN_${item.id}.set`,
  `Symbol=${c.symbol}`,'Period=M1','Model=4','ExecutionMode=0','Optimization=0',
  `FromDate=${c.from}`,`ToDate=${c.to}`,'ForwardMode=0',`Report=${reportName}`,
  'ReplaceReport=1','ShutdownTerminal=1','Deposit=5000','Currency=USD','Leverage=1:20',
  'UseLocal=1','UseRemote=0','UseCloud=0','Visual=0',''].join('\r\n');
}
function plain(s){return s.replace(/<[^>]*>/g,'').replace(/&nbsp;|&#160;/g,' ').replace(/&amp;/g,'&').trim();}
const norm=s=>plain(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/:$/,'').trim().toLowerCase();
function number(s){
 let text=s.replace(/[^\d.,+-]/g,'');if(!text)return null;
 if(text.includes(',')&&text.includes('.'))text=text.lastIndexOf(',')>text.lastIndexOf('.')?text.replaceAll('.','').replace(',','.'):text.replaceAll(',','');
 else if(text.includes(','))text=text.replace(',','.');
 const n=Number(text);return Number.isFinite(n)?n:null;
}
export function parseReport(html){
 const cells=[...html.matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)].map(m=>plain(m[1]));
 function field(labels){const at=cells.findIndex(v=>labels.includes(norm(v)));return at>=0?cells[at+1]??null:null;}
 const netRaw=field(['total net profit','lucro liquido total']);
 const pfRaw=field(['profit factor','fator de lucro']);
 const tradesRaw=field(['total trades','total de negociacoes','total de negocios']);
 const equityDD=field(['equity drawdown maximal','rebaixamento maximo do capital liquido','rebaixamento maximo de equity']);
 const quality=field(['history quality','qualidade do historico']);
 return {net:netRaw===null?null:number(netRaw),profitFactor:pfRaw===null?null:number(pfRaw),
  trades:tradesRaw===null?null:number(tradesRaw),equityDrawdownRaw:equityDD,historyQualityRaw:quality};
}
function command(exe,args,timeout,cwd){
 return new Promise((resolve,reject)=>{
  const child=spawn(exe,args,{cwd,stdio:'inherit',windowsHide:false,shell:false});
  const timer=setTimeout(()=>{child.kill();reject(Error('Tempo excedido no terminal de testes. Confira logs.'));},timeout);
  const stop=()=>{child.kill();process.exit(130);};process.once('SIGINT',stop);
  child.on('error',e=>{clearTimeout(timer);process.removeListener('SIGINT',stop);reject(e);});
  child.on('exit',code=>{clearTimeout(timer);process.removeListener('SIGINT',stop);resolve(code);});
 });
}
function assertNotRunning(testDir){
 const script="@(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe' OR Name='metaeditor64.exe'\" | ForEach-Object {$_.ExecutablePath}) | ConvertTo-Json -Compress";
 const result=execFileSync('powershell.exe',['-NoProfile','-Command',script],{encoding:'utf8'}).trim();
 const paths=result?JSON.parse(result):[];
 for(const p of Array.isArray(paths)?paths:[paths])if(p&&path.dirname(p).toLowerCase()===testDir.toLowerCase())
  throw Error('Feche somente o terminal/editor de TESTES antes de iniciar; nenhum processo sera encerrado pelo preparador.');
}
async function main(){
 const run=process.argv.includes('--run'),smoke=process.argv.includes('--smoke');
 const configFile=path.join(HERE,'configuracao.json');
 const c=validate(JSON.parse(fs.readFileSync(configFile,'utf8')));
 const id=new Date().toISOString().replace(/[^0-9]/g,'').slice(0,17);
 const out=path.join(HERE,'resultados',id);activeOut=out;fs.mkdirSync(out,{recursive:true});
 const cases=smoke?[makeCases()[0],makeCases().find(x=>x.mode===6&&x.r===1)]:makeCases();
 const plan={createdAt:new Date().toISOString(),status:'PLANEJADO_NAO_EXECUTADO',config:c,cases,
  warning:'Resultado do teste ainda nao existe. Mesmo lote e teto de risco; risco realizado varia por stop.'};
 fs.writeFileSync(path.join(out,'plano.json'),JSON.stringify(plan,null,2));
 for(const item of cases){
  fs.writeFileSync(path.join(out,`ALIEN_${item.id}.set`),Object.entries(inputs(item,c)).map(([k,v])=>`${k}=${v}`).join('\r\n'));
  fs.writeFileSync(path.join(out,`ALIEN_${item.id}.ini`),makeIni(item,c,'LAB_'+id+'_'+item.id));
 }
 console.log(`Plano pronto: ${cases.length} testes em ${out}`);
 if(!run){console.log('Nenhum MT5 iniciado. Para executar: RODAR_TESTES.bat');return;}
 if(process.platform!=='win32')throw Error('A execucao do MT5 requer Windows; --prepare funciona sem MT5.');
 // Accept only the dedicated folder historically used by this project, or a clearly named
 // ALIEN_RESEARCH_MT5 folder. Never run against Program Files or the normal live terminal.
 const testDir=fs.realpathSync(c.testTerminalDir);
 if(!['ALIEN_TEST_MT5','ALIEN_RESEARCH_MT5'].includes(path.basename(testDir).toUpperCase())||/program files|appdata[\\/]roaming[\\/]metaquotes[\\/]terminal/i.test(testDir))
  throw Error('Use apenas uma instalacao portatil dedicada ALIEN_TEST_MT5 ou ALIEN_RESEARCH_MT5.');
 assertNotRunning(testDir);
 const lock=path.join(testDir,'ALIEN_RESEARCH_RUNNER.lock');
 try{fs.writeFileSync(lock,String(process.pid),{flag:'wx'});}catch(e){throw Error('Ja existe trava de um executor em '+lock+'. Confira se outro teste esta rodando antes de remover a trava.');}
 process.on('exit',()=>{try{if(fs.readFileSync(lock,'utf8')===String(process.pid))fs.unlinkSync(lock);}catch{}});
 const terminal=path.join(testDir,'terminal64.exe'),editor=path.join(testDir,'metaeditor64.exe');
 for(const p of [terminal,editor,path.join(testDir,'MQL5','Include','Trade','Trade.mqh')])if(!fs.existsSync(p))throw Error('Falta na instalacao de testes: '+p);
 const expertDir=path.join(testDir,'MQL5','Experts','ALIEN_RESEARCH'),includeDir=path.join(testDir,'MQL5','Include','AlienProfessor'),setsDir=path.join(testDir,'MQL5','Profiles','Tester');
 for(const p of [expertDir,includeDir,setsDir])fs.mkdirSync(p,{recursive:true});
 fs.copyFileSync(path.join(ROOT,'MQL5','Experts',EXPERT+'.mq5'),path.join(expertDir,EXPERT+'.mq5'));
 fs.copyFileSync(path.join(ROOT,'MQL5','Include','AlienProfessor','ScalpHypotheses.mqh'),path.join(includeDir,'ScalpHypotheses.mqh'));
 const mq5=path.join(expertDir,EXPERT+'.mq5'),ex5=path.join(expertDir,EXPERT+'.ex5'),log=path.join(expertDir,EXPERT+'.log');
 // Remove stale artifacts ONLY for this research EA to avoid accepting an older binary/log.
 for(const p of [ex5,log])if(fs.existsSync(p))fs.unlinkSync(p);
 await command(editor,['/portable','/compile:'+mq5,'/include:'+path.join(testDir,'MQL5'),'/log'],10*60*1000,testDir);
 if(!fs.existsSync(log)||!fs.existsSync(ex5))throw Error('Compilacao nao gerou EX5/log novos. Abra o MetaEditor de testes e envie o log.');
 fs.copyFileSync(log,path.join(out,'compilacao.log'));
 const logText=decode(fs.readFileSync(log));
 if(!/(?:Result|Resultado)\s*:\s*0\s+(?:errors?|erros?)\s*,\s*0\s+(?:warnings?|avisos?)/i.test(logText))throw Error('Compilacao deve terminar com 0 erros e 0 avisos; veja compilacao.log.');
 const compiledHash=crypto.createHash('sha256').update(fs.readFileSync(ex5)).digest('hex');
 const results=[];
 for(const item of cases){
  assertNotRunning(testDir);
  const prefix='LAB_'+id+'_'+item.id;
  fs.copyFileSync(path.join(out,`ALIEN_${item.id}.set`),path.join(setsDir,`ALIEN_${item.id}.set`));
  const ini=path.join(out,`ALIEN_${item.id}.ini`);
  console.log(`Iniciando ${item.id}; ${c.from} a ${c.to}; somente Tester, deposito simulado 5000.`);
  await command(terminal,['/portable','/config:'+ini],c.timeoutMinutes*60000,testDir);
  const candidates=[path.join(testDir,prefix+'.htm'),path.join(testDir,prefix+'.html'),path.join(testDir,'reports',prefix+'.htm'),path.join(testDir,'reports',prefix+'.html')];
  const report=candidates.find(p=>fs.existsSync(p));
  if(!report)throw Error('MT5 nao gerou relatorio para '+item.id+'. Confira login/dados/simbolo do terminal de testes.');
  const bytes=fs.readFileSync(report);fs.copyFileSync(report,path.join(out,path.basename(report)));
  const metrics=parseReport(decode(bytes));
  const result={...item,status:metrics.net===null||metrics.trades===null?'RELATORIO_NAO_INTERPRETADO':metrics.trades===0?'SEM_OPERACOES':'TESTE_EXECUTADO',metrics,compiledHash};
  results.push(result);
  fs.writeFileSync(path.join(out,'RESULTADOS.json'),JSON.stringify({config:c,results},null,2));
  console.log(result.status,JSON.stringify(metrics));
 }
 console.log('Concluido. Relatorios em '+out+'. Gerar pacote: ENVIAR_RESULTADOS.bat');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(e=>{console.error(e.message);if(activeOut)fs.writeFileSync(path.join(activeOut,'ERRO.txt'),e.message);process.exitCode=1;});
