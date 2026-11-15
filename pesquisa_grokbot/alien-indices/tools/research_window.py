import pandas as pd, numpy as np, sys
T=pd.read_parquet('/workspace/alien-research/out/v2_trades_RF.parquet'); T['key']=T.sym+'|'+T.cid.astype(str)
keys=['usa500idxusd|32','usa500idxusd|35','usatechidxusd|32','usatechidxusd|35','deuidxeur|32','deuidxeur|35']
x=T[T.key.isin(keys)].copy()
x['entry']=pd.to_datetime(x.entry).dt.tz_convert('America/New_York')
x['exit']=pd.to_datetime(x.exit).dt.tz_convert('America/New_York')
starts={'usa500idxusd':sys.argv[1],'usatechidxusd':sys.argv[1],'deuidxeur':sys.argv[2]}
x=x[x.apply(lambda r: r.entry.tz_localize(None)>=pd.Timestamp(starts[r.sym]),axis=1)]
x['d']=x.exit.dt.normalize().dt.tz_localize(None)
daily=x.groupby('d').R.sum()*0.01
st=pd.Timestamp(min(starts.values())); daily=daily.reindex(pd.date_range(st,'2026-11-13',freq='B'),fill_value=0)
eq=(1+daily).cumprod(); yrs=len(daily)/261
yr=eq.resample('YE').last(); yr=pd.concat([pd.Series([1.0],index=[st-pd.Timedelta(days=1)]),yr]).pct_change().dropna()
print('RESEARCH window: CAGR %.2f%% maxDD %.2f%% trades %d (%.1f/mes) PF %.2f WR %.0f%%'%(100*(eq.iloc[-1]**(1/yrs)-1),100*(1-eq/eq.cummax()).max(),len(x),len(x)/yrs/12,x.R[x.R>0].sum()/-x.R[x.R<0].sum(),100*(x.R>0).mean()))
print('years',' '.join(f'{k.year}:{v:+.1%}' for k,v in yr.items()))
print(x.groupby('sym').R.agg(['count','sum','mean']))
x.to_csv('/workspace/alien-indices/tools/research_trades_window.csv',index=False)
