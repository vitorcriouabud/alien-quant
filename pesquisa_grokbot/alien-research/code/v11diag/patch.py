import sys,re
src=open('/home/box/.mt5/drive_c/Program/MQL5/Experts/ALIEN/ALIEN_V11_SCALPER.mq5',encoding='utf-8').read()
out_name=sys.argv[1]; extra=sys.argv[2] if len(sys.argv)>2 else None
mod=open('diag_module.mqh').read()
def rep(a,b,count=1):
    global src
    assert src.count(a)>=1, a
    src=src.replace(a,b,count)
rep('CTrade trade;\n','CTrade trade;\n'+mod+'\n')
rep('''   if(sent && IsAcceptedRetcode(rc) && trade.ResultDeal() != 0)
   {
      enteredThisBar = true;''','''   if(sent && IsAcceptedRetcode(rc) && trade.ResultDeal() != 0)
   {
      DiagRegister(trade.ResultOrder(),direction,price,trade.ResultPrice(),stop,takeProfit,tick,cachedATRPoints,lastSetup);
      enteredThisBar = true;''')
rep('   ManageOpenPosition(tick, shortM, atrPts);\n','   ManageOpenPosition(tick, shortM, atrPts);\n   DiagUpdate(tick);\n')
rep('   EventKillTimer();\n   if(EnableTelemetry) WriteReport();','   EventKillTimer();\n   DiagWrite();\n   if(EnableTelemetry) WriteReport();')
if extra:
    exec(open(extra).read())
open(out_name,'w',encoding='utf-8').write(src)
print('ok',out_name)
