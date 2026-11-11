/** ALIEN local monitor. Node >=18, built-in modules only. No network/trading API. */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex').slice(0,12);
export const FILE_PATTERN=/^ALIEN_V\d+_TRADES_(.+)_(\d+)_(\d+)_(\d{8})_(\d{6})\.csv$/i;
const REQUIRED=['position_id','entrada_hora','saida_hora','lado','liquido_conta','lote','setup','motivo_saida'];

export function decode(buffer){
  if(buffer[0]===255&&buffer[1]===254) return buffer.subarray(2).toString('utf16le');
  try {return new TextDecoder('utf-8',{fatal:true}).decode(buffer).replace(/^\uFEFF/,'');}
  catch {return new TextDecoder('windows-1252').decode(buffer);}
}
export function parseCSV(text){
  // Import only complete newline-terminated records, avoiding an in-flight MT5 write.
  text=text.slice(0,text.lastIndexOf('\n')+1);
  const rows=[];let row=[],field='',quoted=false;
  for(let i=0;i<text.length;i++){
    const c=text[i];
    if(c==='"'){
      if(quoted&&text[i+1]==='"'){field+='"';i++;}
      else quoted=!quoted;
    }else if(c===';'&&!quoted){row.push(field);field='';}
    else if(c==='\n'&&!quoted){row.push(field.replace(/\r$/,''));if(row.some(Boolean))rows.push(row);row=[];field='';}
    else field+=c;
  }
  return rows;
}
function numeric(value){
  if(!/^[+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)$/.test(value??''))return null;
  const n=Number(value.replace(',','.'));return Number.isFinite(n)?n:null;
}
function validDate(s){
  if(!/^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$/.test(s??''))return false;
  const iso=s.slice(0,10).replace(/\./g,'-')+'T'+s.slice(11)+'Z';
  const d=new Date(iso);return Number.isFinite(d.getTime())&&d.toISOString().slice(0,19)===iso.slice(0,19);
}
export function readTrades(text,file){
  const m=path.basename(file).match(FILE_PATTERN);
  if(!m)throw Error('Nome de CSV nao reconhecido');
  const rows=parseCSV(text);const header=rows.shift()??[];
  if(!REQUIRED.every(k=>header.includes(k)))throw Error('Cabecalho de operacoes incompleto');
  // The path identifies a terminal/broker dataset; do not combine unrelated accounts.
  const dataset=hash(path.resolve(path.dirname(file))+'|'+m[1]+'|'+m[2]+'|'+m[3]);
  const trades=[];let rejected=0;
  for(const row of rows){
    if(row.length!==header.length){rejected++;continue;}
    const r=Object.fromEntries(header.map((k,i)=>[k,row[i]]));
    const net=numeric(r.liquido_conta),lot=numeric(r.lote);
    if(!/^\d+$/.test(r.position_id)||!validDate(r.entrada_hora)||!validDate(r.saida_hora)||
      r.saida_hora<r.entrada_hora||!['BUY','SELL'].includes(r.lado)||net===null||lot===null||lot<=0){rejected++;continue;}
    trades.push({key:dataset+':'+r.position_id,dataset,symbol:m[1],magic:m[3],
      opened:r.entrada_hora,closed:r.saida_hora,side:r.lado,net,lot,
      setup:r.setup||'SEM_SETUP',exit:r.motivo_saida||'SEM_MOTIVO',
      spread:numeric(r.spread_pts),score:numeric(r.score),session:r.sessao_entrada||'NAO_REGISTRADA'});
  }
  return {trades,rejected};
}
export function metrics(trades){
  const ordered=[...trades].sort((a,b)=>a.closed.localeCompare(b.closed)||a.key.localeCompare(b.key));
  let net=0,gains=0,losses=0,wins=0,lost=0,peak=0,dd=0,streak=0,maxStreak=0;
  for(const t of ordered){
    net+=t.net;
    if(t.net>0){gains+=t.net;wins++;streak=0;}
    else if(t.net<0){losses-=t.net;lost++;streak++;maxStreak=Math.max(maxStreak,streak);}
    else streak=0;
    peak=Math.max(peak,net);dd=Math.max(dd,peak-net);
  }
  return {trades:ordered.length,wins,losses:lost,flat:ordered.length-wins-lost,
    net,profitFactor:losses>0?gains/losses:null,winRate:ordered.length?wins/ordered.length*100:0,
    average:ordered.length?net/ordered.length:0,averageWin:wins?gains/wins:0,
    averageLoss:lost?losses/lost:0,realizedDrawdown:dd,maxLossStreak:maxStreak};
}
function grouped(trades,key){
  const g=Object.create(null);for(const t of trades){const label=key(t);(g[label]??=[]).push(t);}
  return Object.fromEntries(Object.entries(g).map(([k,v])=>[k,metrics(v)]));
}
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const f=n=>n===null?'—':Number(n).toFixed(2);
function table(groups){
  return '<table><tr><th>Grupo</th><th>Trades</th><th>Liquido*</th><th>PF</th><th>Acerto %</th><th>Media*</th></tr>'+
    Object.entries(groups).map(([k,m])=>`<tr><td>${escape(k)}</td><td>${m.trades}</td><td>${f(m.net)}</td><td>${f(m.profitFactor)}</td><td>${f(m.winRate)}</td><td>${f(m.average)}</td></tr>`).join('')+'</table>';
}
function atomic(file,text){const tmp=file+'.tmp';fs.writeFileSync(tmp,text,'utf8');fs.renameSync(tmp,file);}
function scan(root){
  const result=[];
  function walk(dir,depth){
    if(depth>10)return;
    let entries;try{entries=fs.readdirSync(dir,{withFileTypes:true});}catch{return;}
    for(const e of entries){
      // Skip tester folders and links; live/demo records remain separate from backtests.
      if(e.isSymbolicLink()||/^(tester|agent-.+|bases|logs|history|node_modules)$/i.test(e.name))continue;
      const p=path.join(dir,e.name);
      if(e.isDirectory())walk(p,depth+1);
      else if(FILE_PATTERN.test(e.name))result.push(p);
    }
  }
  walk(root,0);return result;
}
export function discover(extra=[]){
  if(extra.some(p=>path.resolve(p).split(/[\\/]/).some(part=>/^(tester|agent-.+)$/i.test(part))))
    throw Error("Use a pasta MQL5/Files de um terminal normal; Tester fica fora deste monitor.");
  const roots=[...extra];
  if(process.env.APPDATA)roots.push(path.join(process.env.APPDATA,'MetaQuotes','Terminal'));
  return [...new Set(roots.map(p=>path.resolve(p)))];
}
export function collect(state,roots){
  const warnings=[];let imported=0,changed=false,filesFound=0;
  for(const file of new Set(roots.flatMap(scan))){
    filesFound++;
    try{
      const before=fs.statSync(file),signature=before.size+':'+before.mtimeMs;
      if(state.files[file]?.signature===signature){
        if(state.files[file].rejected)warnings.push(`${hash(file)}: ${state.files[file].rejected} linhas invalidas ignoradas`);
        continue;
      }
      const bytes=fs.readFileSync(file),after=fs.statSync(file);
      if(before.size!==after.size||before.mtimeMs!==after.mtimeMs){warnings.push('Arquivo em gravacao: nova tentativa no proximo ciclo');continue;}
      const result=readTrades(decode(bytes),file);
      for(const t of result.trades){
        const prior=state.trades[t.key];
        if(prior&&JSON.stringify(prior)!==JSON.stringify(t)){
          state.conflicts[t.key]='Registros divergentes para a mesma posicao; primeira versao preservada';
        }else if(!prior){state.trades[t.key]=t;imported++;}
      }
      state.files[file]={signature,rejected:result.rejected,lastModifiedAt:new Date(after.mtimeMs).toISOString()};changed=true;
      if(result.rejected)warnings.push(`${hash(file)}: ${result.rejected} linhas invalidas ignoradas`);
    }catch(error){warnings.push(hash(file)+': '+(error.code??'CSV_INVALIDO'));}
  }
  return {imported,changed,filesFound,warnings};
}
export function buildReport(state,scanInfo){
  const trades=Object.values(state.trades),datasets={};
  for(const [id,items] of Object.entries(groupArrays(trades,t=>t.dataset))){
    datasets[id]={symbol:items[0].symbol,magic:items[0].magic,summary:metrics(items),
      bySetup:grouped(items,t=>t.setup),byExit:grouped(items,t=>t.exit),
      byHour:grouped(items,t=>t.opened.slice(11,13)+'h'),bySession:grouped(items,t=>t.session),
      byDay:grouped(items,t=>t.closed.slice(0,10))};
  }
  const notes=[
    'Moeda = moeda da conta de cada conjunto; nao somar contas, terminais ou magics distintos.',
    'Horarios dos trades sao os da corretora, sem conversao para Brasil.',
    'Drawdown calculado apenas com fechamentos; nao mede equity nem perdas flutuantes.',
    'Sem MAE/MFE ou SL/TP inicial no CSV atual: nao identifica com certeza stop apertado ou saida precoce.',
    'Liquido reproduz o campo do EA, sem descontar custos novamente; auditar com historico do broker.',
    'Sem recomendacao automatica de lote, mudanca de parametros ou prova de vantagem estatistica.',
    'Bloqueios nao sao contados: o CSV de operacoes fechadas nao registra todos os sinais recusados.'
  ];
  if(!scanInfo.filesFound)notes.unshift('Nenhum CSV do ALIEN encontrado. Monitor aguardando; confira MT5, telemetria e pasta.');
  if(!trades.length)notes.unshift('Ainda nao ha operacoes fechadas validas para analisar.');
  const observations=[];
  for(const [id,d]of Object.entries(datasets))for(const [setup,m]of Object.entries(d.bySetup)){
    observations.push(`${id} / ${setup}: ${m.trades} trades, liquido ${f(m.net)}, media ${f(m.average)}. `+
      (m.trades<30?'Amostra inicial; nao alterar a estrategia por este grupo.':
       m.net<0?'Resultado observado negativo; investigar custos, contexto e execucao em teste separado.':
       'Resultado observado positivo; conferir outro periodo e drawdown antes de concluir.'));
  }
  return {schema:1,generatedAt:new Date().toISOString(),
    latestDataWriteAt:Object.values(state.files).map(f=>f.lastModifiedAt).filter(Boolean).sort().at(-1)??null,
    filesFound:scanInfo.filesFound,
    importedThisCycle:scanInfo.imported,warnings:scanInfo.warnings,
    conflicts:Object.keys(state.conflicts).length,notes,observations,datasets,
    // No account numbers, local paths, position IDs or credentials in this export.
    trades:trades.map(({key,...t})=>t)};
}
function groupArrays(trades,key){const out=Object.create(null);for(const t of trades)(out[key(t)]??=[]).push(t);return out;}
export function render(report){
  const body=Object.entries(report.datasets).map(([id,d])=>`<section><h2>${escape(d.symbol)} · magic ${escape(d.magic)} · conjunto ${escape(id)}</h2>
    <p>${d.summary.trades} operacoes · liquido* ${f(d.summary.net)} · PF ${f(d.summary.profitFactor)} · queda entre fechamentos* ${f(d.summary.realizedDrawdown)} · maior sequencia de perdas ${d.summary.maxLossStreak}</p>
    <h3>Por hipotese</h3>${table(d.bySetup)}<h3>Por saida</h3>${table(d.byExit)}<h3>Por hora da corretora</h3>${table(d.byHour)}<h3>Por dia de fechamento</h3>${table(d.byDay)}</section>`).join('');
  return `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta http-equiv="refresh" content="30"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ALIEN — Diagnostico local</title>
  <style>body{font:16px system-ui;background:#101317;color:#e9edf1;max-width:1150px;margin:auto;padding:24px}h1,h2{color:#ffcf38}section{background:#1b2027;padding:20px;margin:22px 0;border-radius:12px}table{border-collapse:collapse;width:100%;display:block;overflow:auto}th,td{text-align:left;padding:10px;border-bottom:1px solid #454b52}small{color:#bbb}li{margin:8px 0}</style>
  <h1>ALIEN · Diagnostico local</h1><p>Atualizado em ${escape(report.generatedAt)} (UTC). ${report.filesFound} arquivos encontrados. Recarrega a cada 30s enquanto o monitor estiver aberto.</p>
  <p>Ultima gravacao de CSV observada: ${escape(report.latestDataWriteAt??"nenhuma")}. Atualizacao do monitor nao confirma que o EA esta operando.</p>
  <p>*Valores na moeda da respectiva conta. Dados observados; nenhuma ordem e enviada por este programa.</p>
  <h2>Estado e limites dos dados</h2><ul>${[...report.notes,...report.warnings,`Conflitos de registros: ${report.conflicts}`].map(n=>'<li>'+escape(n)+'</li>').join('')}</ul>${body}
  <h2>Leituras para investigacao</h2><ul>${report.observations.map(n=>'<li>'+escape(n)+'</li>').join('')}</ul></html>`;
}
function loadState(file){
  if(!fs.existsSync(file))return {schema:1,files:{},trades:{},conflicts:{}};
  const state=JSON.parse(fs.readFileSync(file,'utf8'));
  if(state.schema!==1||!state.trades||!state.files||!state.conflicts)throw Error('Estado salvo invalido; preserve o arquivo e revise antes de continuar');
  return state;
}
export function runCycle(out,roots){
  fs.mkdirSync(out,{recursive:true});
  const state=loadState(path.join(out,'estado-local.json'));
  const info=collect(state,roots),report=buildReport(state,info);
  if(info.changed||!fs.existsSync(path.join(out,'estado-local.json')))atomic(path.join(out,'estado-local.json'),JSON.stringify(state));
  atomic(path.join(out,'ENVIAR_AO_CHATGPT.json'),JSON.stringify(report,null,2));
  atomic(path.join(out,'PAINEL_ALIEN.html'),render(report));
  atomic(path.join(out,'DIAGNOSTICO.txt'),[report.generatedAt,...report.notes,...report.warnings,...report.observations].join(os.EOL));
  return report;
}
function main(){
  if(Number(process.versions.node.split('.')[0])<18)throw Error('Use Node.js 18 ou mais recente.');
  const args=process.argv.slice(2);let out=path.join(HERE,'dados'),once=false;const extra=[];
  for(let i=0;i<args.length;i++){
    if(args[i]==='--once')once=true;
    else if(args[i]==='--root'&&args[i+1])extra.push(args[++i]);
    else if(args[i]==='--out'&&args[i+1])out=path.resolve(args[++i]);
    else throw Error('Uso: node alien-monitor.mjs [--once] [--root "pasta MQL5/Files"] [--out "pasta"]');
  }
  const roots=discover(extra);fs.mkdirSync(out,{recursive:true});
  const lock=path.join(out,'monitor.lock');
  function takeLock(){
    try{fs.writeFileSync(lock,String(process.pid),{flag:'wx'});}
    catch(e){
      if(e.code!=='EEXIST')throw e;
      const pid=Number(fs.readFileSync(lock,'utf8'));
      if(!Number.isInteger(pid)||pid<=0)throw Error('Lock invalido: verifique se outro monitor esta aberto.');
      try{process.kill(pid,0);throw Error('Monitor ja esta aberto. Feche a outra janela primeiro.');}
      catch(alive){if(alive.code!=='ESRCH')throw alive;}
      fs.unlinkSync(lock);fs.writeFileSync(lock,String(process.pid),{flag:'wx'});
    }
  }
  takeLock();
  const cleanup=()=>{try{if(fs.readFileSync(lock,'utf8')===String(process.pid))fs.unlinkSync(lock);}catch{}};
  process.on('exit',cleanup);process.on('SIGINT',()=>process.exit(0));process.on('SIGTERM',()=>process.exit(0));
  const tick=()=>{
    try{const r=runCycle(out,roots);console.log(`${r.generatedAt} | CSVs ${r.filesFound} | novas ${r.importedThisCycle} | conjuntos ${Object.keys(r.datasets).length} | avisos ${r.warnings.length}`);}
    catch(e){console.error('Erro: '+e.message);if(once)process.exitCode=1;}
  };
  console.log('ALIEN: coleta local. Sem rede, sem ordens, sem alteracao do EA.');
  console.log('Painel: '+path.join(out,'PAINEL_ALIEN.html'));
  tick();if(!once)setInterval(tick,30000);
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{main();}catch(e){console.error(e.message);process.exitCode=1;}
}
