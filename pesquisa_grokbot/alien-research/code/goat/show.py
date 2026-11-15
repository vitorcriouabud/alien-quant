import sys
for l in open(sys.argv[1]):
    if l.startswith('{'):
        d=eval(l.rsplit('}',1)[0]+'}',{'np':__import__('numpy'),'nan':float('nan')})
        print(d['set'][:14],d['risk_usd'],d['maxpos'],d['lotstep'],'P1any',round(d['p1_any'],2),'pass',round(d['pass_both'],2),'brF',round(d['breach_float'],2),'br',round(d['breach'],2),'p1med',d['p1_med_days'],'both_med',d['both_med_days'],'p1_6m',round(d['p1_6m'],2),'p1_12m',round(d['p1_12m'],2),'both12',round(d['both_12m'],2),'both24',round(d['both_24m'],2))
    elif 'trades' in l: print(l.strip())
