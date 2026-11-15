import pandas as pd, numpy as np, glob, os
rows=[]
for stem,label in [('DIAG_base_m0','BASE ticks GERADOS'),('DIAG_base_m4','BASE'),('FIX_F1_m4','F1 sem BE/trailing'),('FIX_F2_m4','F2 spread<=12% do SL'),('FIX_F3_m4','F3 SL>=0,5 ATR'),('FIX_F4_m4','F4 BE 1R/trail 2R'),('FIX_F5_m4','F5 spread max 10'),('FIX_F6_m4','F6 combinado')]:
    g=glob.glob(f'/workspace/alien-research/out/mt5/{stem}_files/ALIEN_DIAG_*.csv')
    if not g: continue
    d=pd.read_csv(g[0],sep=';'); d['t']=pd.to_datetime(d.open_ms,unit='ms')
    d['wk']=np.where(d.t<'2026-11-07','A (30/10-06/11)','B (09-13/11)')
    for wk,x in list(d.groupby('wk'))+[('TOTAL',d)]:
        gp=x.net[x.net>0].sum(); gl=-x.net[x.net<0].sum()
        rows.append(dict(teste=label,periodo=wk,trades=len(x),liquido=round(x.net.sum(),2),
            liquido_com16_8=round(x.net.sum()-len(x)*0.088,2),
            pf=round(gp/gl,2) if gl>0 else np.inf,acerto=round((x.net>0).mean()*100,1),
            pts_med=round((x.net/0.01/1).mean(),1) if len(x) else 0))
t=pd.DataFrame(rows); print(t.to_string()); t.to_csv('/workspace/alien-research/out/v11diag_compare.csv',index=False)
