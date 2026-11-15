import pandas as pd, numpy as np, sys, glob
stem=sys.argv[1]
d=pd.read_csv(glob.glob(f'/workspace/alien-research/out/mt5/{stem}_files/ALIEN_DIAG_*.csv')[0],sep=';')
d['t']=pd.to_datetime(d.open_ms,unit='ms'); d['dur_s']=(d.close_ms-d.open_ms)/1000
d['exit_pts']=d.dir*(d.exit_px-d.entry)/0.01
d['be_moved']=(d.dir*(d.final_sl-d.sl0)>0)
d['locked']=(d.dir*(d.final_sl-d.entry)>=0)
reason={4:'SL',5:'TP',3:'EA'}; d['why']=d.exit_reason.map(reason).fillna('outro')
d['cls']=np.where(d.why=='TP','TP',np.where((d.why=='SL')&d.locked,'SL_em_BE/trail',np.where(d.why=='SL','SL_original/parcial','EA')))
d['day']=d.t.dt.date; d['hr']=d.t.dt.hour
d['sp_over_sl']=d.spread_pts/d.sl_pts
print(stem,'trades',len(d),'net',round(d.net.sum(),2),'comm',round(d.comm.sum(),2),'win%',round((d.net>0).mean()*100,1))
print('PF', round(d.net[d.net>0].sum()/-d.net[d.net<0].sum(),2) if (d.net<0).any() else 'inf')
print(d[['spread_pts','atr_pts','sl_pts','tp_pts','sp_over_sl','mfe','mae','dur_s','exit_pts']].describe(percentiles=[.25,.5,.75]).round(2).T)
print(d.groupby('cls').agg(n=('net','size'),net=('net','sum'),pts=('exit_pts','mean'),mfe=('mfe','mean'),dur=('dur_s','median')).round(2))
print('virtual original bracket: ',d.vres.value_counts().to_dict())
print('stopped-by-SL-orig then TP would hit?: n/a (bracket stops at first hit)')
print('trades where real exit<=0 but virtual hit TP:',((d.net<=0)&(d.vres==1)).sum())
print('trades where real exit>0 but virtual hit SL:',((d.net>0)&(d.vres==-1)).sum())
print('virtual bracket EV (pts, gross): ', round(np.where(d.vres==1,d.tp_pts,np.where(d.vres==-1,-d.sl_pts,0)).mean(),1))
print('MFE>=BE trigger(=max(12,0.33atr)):',(d.mfe>=np.maximum(12,0.33*d.atr_pts)).mean().round(2))
print('MFE< spread:',(d.mfe<d.spread_pts).mean().round(2), ' MFE<=0:',(d.mfe<=0).mean().round(2))
print(d.groupby('setup').agg(n=('net','size'),net=('net','sum'),win=('net',lambda x:(x>0).mean())).round(2))
print(d.groupby('dir').agg(n=('net','size'),net=('net','sum')).round(2))
print(d.groupby('hr').agg(n=('net','size'),net=('net','sum')).round(2).T)
print(d.groupby('day').agg(n=('net','size'),net=('net','sum'),win=('net',lambda x:(x>0).mean())).round(2))
d.to_csv(f'/workspace/alien-research/out/v11diag_{stem}.csv',index=False)
