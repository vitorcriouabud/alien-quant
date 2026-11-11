import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {makeCases,inputs,makeIni,parseReport,validate} from '../lab/run-lab.mjs';
const c={testTerminalDir:path.resolve('ALIEN_TEST_MT5'),symbol:'XAUUSD',from:'2026.10.01',to:'2026.11.01',commissionPerLot:8,timeoutMinutes:240};
test('19 unique cases; one baseline plus six hypotheses by three exits',()=>{
 const cases=makeCases();assert.equal(cases.length,19);assert.equal(new Set(cases.map(x=>x.id)).size,19);
 for(let m=6;m<=11;m++)assert.deepEqual(cases.filter(x=>x.mode===m).map(x=>x.r),[.75,1,1.5]);
});
test('real-tick, isolated no-cloud settings; baseline original vs individual patterns',()=>{
 const item=makeCases()[1],ini=makeIni(item,c,'LAB_TEST');
 for(const value of ['Model=4','Deposit=5000','AllowLiveTrading=0','Enabled=1','UseCloud=0','UseRemote=0','ShutdownTerminal=1','Optimization=0'])assert.ok(ini.includes(value));
 const values=inputs(item,c);assert.equal(values.ScalpLabFixedExit,true);assert.equal(values.ScalpHypothesisMode,6);assert.equal(values.FixedLot,.01);assert.equal(values.EnableEvidenceScaling,false);
 assert.equal(values.RoundTurnCommissionPerLot,8);assert.equal(inputs(makeCases()[0],c).ScalpHypothesisMode,0);
});
test('English and Portuguese report metrics and unknown labels',()=>{
 const h='<td>Total Net Profit:</td><td><b>1 234.56</b></td><td>Profit Factor:</td><td>1.37</td><td>Total Trades:</td><td>120</td>';
 assert.deepEqual(parseReport(h),{net:1234.56,profitFactor:1.37,trades:120,equityDrawdownRaw:null,historyQualityRaw:null});
 const pt='<td>Lucro Líquido Total:</td><td>-1.234,56</td><td>Fator de Lucro:</td><td>0,91</td><td>Total de Negociações:</td><td>32</td>';
 assert.equal(parseReport(pt).net,-1234.56);assert.equal(parseReport(pt).profitFactor,.91);assert.equal(parseReport(pt).trades,32);
 assert.equal(parseReport('<p>no result</p>').net,null);
});
test('invalid or injected configs refused',()=>{
 assert.equal(validate(c),c);
 assert.throws(()=>validate({...c,symbol:'XAUUSD\nLogin=123'}));
 assert.throws(()=>validate({...c,from:c.to}));
 assert.throws(()=>validate({...c,commissionPerLot:NaN}));
 assert.throws(()=>makeIni(makeCases()[0],c,'BAD\nLogin=1'));
});
