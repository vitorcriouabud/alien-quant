import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {decode,parseCSV,readTrades,metrics,collect,buildReport,render,runCycle,discover} from '../automation/alien-monitor.mjs';
const header='position_id;entrada_hora;saida_hora;lado;liquido_conta;lote;setup;motivo_saida;spread_pts;score;sessao_entrada\r\n';
const row=(id=1,net='1.25',setup='IMPULSO_CORRECAO')=>`${id};2026.11.10 10:00:00;2026.11.10 10:01:00;BUY;${net};0.01;${setup};TP;12;70;LONDRES\r\n`;
const filename='ALIEN_V1089_TRADES_XAU_USD_12345678_802220_20261110_100000.csv';
function temp(){return fs.mkdtempSync(path.join(os.tmpdir(),'alien-monitor-'));}
function state(){return {schema:1,files:{},trades:{},conflicts:{}};}

test('MQL5 UTF16 and ANSI encodings; quoted semicolon and escaped quote',()=>{
 const txt=header+row();assert.equal(decode(Buffer.concat([Buffer.from([255,254]),Buffer.from(txt,'utf16le')])),txt);
 assert.match(decode(Buffer.from([0xe7])),/ç/);
 assert.deepEqual(parseCSV('a;b\n"x;y";"as""pas"\n'),[['a','b'],['x;y','as"pas']]);
});
test('partial rows not imported; real schema and symbol underscores accepted',()=>{
 const data=readTrades(header+row()+'2;unfinished',filename);
 assert.equal(data.trades.length,1);assert.equal(data.trades[0].symbol,'XAU_USD');
 assert.equal(data.trades[0].net,1.25);
});
test('invalid dates, nonnumeric net, missing columns and malformed row rejected',()=>{
 for(const text of [row().replace('1.25','NaN'),row().replaceAll('2026.11.10','2026.02.30'),row().replace('0.01','0')]){
  const r=readTrades(header+text,filename);assert.equal(r.trades.length,0);assert.equal(r.rejected,1);
 }
 assert.throws(()=>readTrades('a;b\n',filename),/Cabecalho/);
 assert.equal(readTrades(header+'a;b\n',filename).rejected,1);
});
test('net PF and realized drawdown are calculated in close order',()=>{
 const trades=[2,-1,-3,4].map((net,i)=>({net,closed:String(i),key:String(i)}));
 const m=metrics(trades);assert.equal(m.net,2);assert.equal(m.profitFactor,1.5);
 assert.equal(m.realizedDrawdown,4);assert.equal(m.maxLossStreak,2);assert.equal(m.winRate,50);
 assert.equal(metrics([{net:2,closed:'1',key:'1'}]).profitFactor,null);
 assert.equal(metrics([]).average,0);
});
test('restarts and copied session logs do not duplicate trades',()=>{
 const dir=temp();try{
  fs.writeFileSync(path.join(dir,filename),header+row());let s=state();collect(s,[dir]);
  s=JSON.parse(JSON.stringify(s));assert.equal(collect(s,[dir]).imported,0);
  fs.writeFileSync(path.join(dir,filename.replace('_100000','_110000')),header+row());
  assert.equal(collect(s,[dir]).imported,0);assert.equal(Object.keys(s.trades).length,1);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('accounts/magics/terminal roots stay separate, Tester excluded',()=>{
 const dir=temp();try{
  for(const sub of ['terminal1','terminal2','Tester/Agent-1']){
   fs.mkdirSync(path.join(dir,sub),{recursive:true});fs.writeFileSync(path.join(dir,sub,filename),header+row());
  }
  fs.writeFileSync(path.join(dir,'terminal1',filename.replace('12345678','99999999')),header+row());
  fs.writeFileSync(path.join(dir,'terminal1',filename.replace('802220','802092')),header+row());
  const s=state(),info=collect(s,[dir]),r=buildReport(s,info);
  assert.equal(info.filesFound,4);assert.equal(Object.keys(r.datasets).length,4);
  assert.throws(()=>discover([path.join(dir,'Tester')]),/Tester/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('conflicting records are visible and first value preserved',()=>{
 const dir=temp();try{
  fs.writeFileSync(path.join(dir,filename),header+row());const s=state();collect(s,[dir]);
  fs.writeFileSync(path.join(dir,filename.replace('_100000','_110000')),header+row(1,'9.75'));
  const r=buildReport(s,collect(s,[dir]));assert.equal(r.conflicts,1);assert.equal(r.trades[0].net,1.25);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('share export contains no account, position IDs, paths; HTML escapes labels',()=>{
 const dir=temp();try{
  fs.writeFileSync(path.join(dir,filename),header+row(987654321,'1.25','<script>alert(1)</script>'));
  const s=state(),r=buildReport(s,collect(s,[dir])),json=JSON.stringify(r);
  for(const secret of ['12345678','987654321',dir])assert.ok(!json.includes(secret));
  assert.ok(!render(r).includes('<script>'));assert.ok(render(r).includes('&lt;script&gt;'));
  assert.ok(r.latestDataWriteAt);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('invalid-file diagnostics do not expose account or local path',()=>{
 const dir=temp();try{
  fs.writeFileSync(path.join(dir,filename),'wrong;header\n');
  const s=state(),r=buildReport(s,collect(s,[dir])),json=JSON.stringify(r);
  assert.ok(r.warnings.length>0);assert.ok(!json.includes('12345678'));assert.ok(!json.includes(dir));
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('cycle creates deliverables, preserves state, and reports no-data honestly',()=>{
 const root=temp(),out=temp();try{
  const empty=runCycle(out,[root]);assert.equal(empty.trades.length,0);assert.match(empty.notes.join(' '),/Nenhum CSV/);
  fs.writeFileSync(path.join(root,filename),header+row());const r=runCycle(out,[root]);assert.equal(r.trades.length,1);
  assert.equal(runCycle(out,[root]).trades.length,1);
  for(const f of ['estado-local.json','PAINEL_ALIEN.html','DIAGNOSTICO.txt','ENVIAR_AO_CHATGPT.json'])assert.ok(fs.existsSync(path.join(out,f)));
  fs.writeFileSync(path.join(out,'estado-local.json'),'broken');assert.throws(()=>runCycle(out,[root]));
 }finally{fs.rmSync(root,{recursive:true,force:true});fs.rmSync(out,{recursive:true,force:true});}
});
