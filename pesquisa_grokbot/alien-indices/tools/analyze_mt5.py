"""Le relatorio HTML do Strategy Tester (ALIEN_INDICES_V1) e calcula numeros comparaveis com a pesquisa."""
import sys, io, re, json, pandas as pd, numpy as np
path=sys.argv[1]
t=open(path,'rb').read().decode('utf-16')
tabs=pd.read_html(io.StringIO(t))
s=tabs[0].astype(str)
summ={}
for _,r in s.iterrows():
    vals=list(dict.fromkeys([str(v) for v in r.values if str(v)!='nan']))
    for i,v in enumerate(vals[:-1]):
        if v.endswith(':'): summ[v[:-1]]=vals[i+1]
d=tabs[1]
hdr=d.index[d.iloc[:,0].astype(str).eq('Time') & d.iloc[:,1].astype(str).eq('Deal')]
d.columns=d.iloc[hdr[-1]].values; d=d.iloc[hdr[-1]+1:]
d=d[d['Deal'].astype(str).str.fullmatch(r'\d+')].copy()
for c in ('Volume','Price','Commission','Swap','Profit','Balance'):
    d[c]=pd.to_numeric(d[c].astype(str).str.replace(' ',''),errors='coerce')
d['Time']=pd.to_datetime(d['Time'],format='%Y.%m.%d %H:%M:%S')
dep=d.iloc[0]['Profit'] if d.iloc[0]['Type']=='balance' else float(sys.argv[2])
x=d[d['Type']!='balance']
outs=x[x['Direction']=='out'].copy()
ins=x[x['Direction']=='in']
outs['net']=outs.Profit+outs.Commission+outs.Swap
comm_in=ins.Commission.sum()
bal=d.set_index('Time').Balance
daily=bal.resample('D').last().ffill()
yr=daily.resample('YE').last(); start=pd.Series([dep],index=[daily.index[0]-pd.Timedelta(days=1)])
yv=pd.concat([start,yr]); yret=yv.pct_change().dropna()
dd=(1-daily/daily.cummax()).max()
first=x.Time.min(); last=d.Time.max()
yrs=(last-first).days/365.25
cagr=(bal.iloc[-1]/dep)**(1/yrs)-1
w=outs.net>0
res=dict(deposit=dep,final=float(bal.iloc[-1]),first_trade=str(first),trades=int(len(outs)),per_month=len(outs)/(yrs*12),
 win=float(w.mean()),pf=float(outs.net[w].sum()/-outs.net[~w].sum()),cagr=cagr,maxdd_balance=float(dd),
 swap_total=float(outs.Swap.sum()),comm_total=float(outs.Commission.sum()+comm_in),
 by_symbol={k:dict(n=int(len(g)),net=round(float(g.net.sum()),2),win=round(float((g.net>0).mean()),3)) for k,g in outs.groupby('Symbol')},
 years={str(k.year):round(float(v),4) for k,v in yret.items()},
 report={k:summ.get(k) for k in ('Total Net Profit','Profit Factor','Equity Drawdown Maximal','Balance Drawdown Maximal','Equity Drawdown Relative','Total Trades','Profit Trades (% of total)','History Quality','Bars')})
# by comment (strategy)
cm=ins[['Order','Comment']] if 'Comment' in ins else None
print(json.dumps(res,indent=1,ensure_ascii=False))
outs.to_csv(path.rsplit('.',1)[0]+'_closed.csv',index=False)
