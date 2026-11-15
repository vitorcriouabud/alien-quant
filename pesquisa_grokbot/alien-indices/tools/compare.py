import pandas as pd, numpy as np, re, sys
sys.path.insert(0,'/workspace/alien-research/code/v2')
LOG=sys.argv[1] if len(sys.argv)>1 else '/workspace/alien-research/out/mt5/IDX_full_100k_files/ALIEN_INDICES_log.csv'
rows=[l.rstrip('\r\n').split(';',5) for l in open(LOG,encoding='latin-1')]
L=pd.DataFrame(rows[1:],columns=rows[0])
L['t']=pd.to_datetime(L.hora,format='%Y.%m.%d %H:%M:%S')
def kv(s,k):
    m=re.search(k+r'=([-\d.]+)',str(s)); return float(m.group(1)) if m else np.nan
E=L[L.evento=='ENTRADA'].copy(); X=L[L.evento.str.startswith('FECHOU')].copy()
for c in ('pos','risk','dist','dir'): E[c]=E.detalhe.map(lambda s:kv(s,c))
for c in ('pos','net','swap'): X[c]=X.detalhe.map(lambda s:kv(s,c))
M=E.merge(X[['pos','t','net','swap','evento']],on='pos',suffixes=('','_x'))
M['R']=M.net/M.risk; M['R_noswap']=(M.net-M.swap)/M.risk
M['stream']=M.simbolo.map({'.US500Cash':'usa500idxusd','.USTECHCash':'usatechidxusd','.DE40Cash':'deuidxeur'})+'|'+M.estrategia.map({'RSI2':'32','IBS':'35'})
M['day']=M.t.dt.normalize()
print('MT5 trades',len(M),'meanR %.3f  meanR_sem_swap %.3f  swap/risk medio %.3f R'%(M.R.mean(),M.R_noswap.mean(),(M.swap/M.risk).mean()))
print(M.groupby('stream').agg(n=('R','size'),R=('R','sum'),R_noswap=('R_noswap','sum'),win=('R',lambda r:(r>0).mean())).round(3))
# research trades in window
T=pd.read_csv('/workspace/alien-indices/tools/research_trades_window.csv')
T['entry']=pd.to_datetime(T.entry,utc=True).dt.tz_convert('America/New_York')
# research entry = open of the D1 bar starting 17:00 NY -> server day = (entry+7h).date
T['day']=(T.entry+pd.Timedelta(hours=7)).dt.tz_localize(None).dt.normalize()
print('research trades',len(T),'meanR %.3f'%T.R.mean())
print(T.groupby('key').agg(n=('R','size'),R=('R','sum'),win=('R',lambda r:(r>0).mean())).round(3))
mt5start=M.day.min()
T=T[T.day>=pd.Timestamp('2018-09-24')]; Mx=M[M.day>=pd.Timestamp('2018-09-24')]
both=Mx.merge(T,left_on=['stream','day'],right_on=['key','day'],suffixes=('_mt5','_res'))
print('desde 2018-09-24: MT5 %d trades, pesquisa %d, mesmo dia de entrada %d (%.0f%% da pesquisa)'%(len(Mx),len(T),len(both),100*len(both)/len(T)))
print('nos trades em comum: R medio MT5 %.3f (sem swap %.3f) vs pesquisa %.3f; corr %.2f'%(both.R_mt5.mean(),both.R_noswap.mean(),both.R_res.mean(),np.corrcoef(both.R_mt5,both.R_res)[0,1]))
only_r=T[~T.set_index(['key','day']).index.isin(both.set_index(['key','day']).index)]
only_m=Mx[~Mx.set_index(['stream','day']).index.isin(both.set_index(['stream','day']).index)]
print('so na pesquisa: %d trades, R medio %.3f, soma %.1f R'%(len(only_r),only_r.R.mean(),only_r.R.sum()))
print('so no MT5: %d trades, R medio %.3f, soma %.1f R'%(len(only_m),only_m.R.mean(),only_m.R.sum()))
M['yr']=M.t.dt.year; T['yr']=T.day.dt.year
print(pd.DataFrame({'MT5_R':M.groupby('yr').R.sum(),'MT5_R_semswap':M.groupby('yr').R_noswap.sum(),'pesq_R':T.groupby('yr').R.sum(),'MT5_n':M.groupby('yr').size(),'pesq_n':T.groupby('yr').size()}).round(1))
M.to_csv(LOG.replace('.csv','_trades.csv'),index=False)
