//==================== ALIEN DIAG (somente diagnostico, nao muda sinais) ====
input int DiagHorizonMinutes = 240;
struct DiagT {
   ulong pos; long tOpenMs; int dir; double req, entry, sl0, tp0, spread, atr; int setup;
   double mfe, mae;        // enquanto a posicao real estava aberta (pts)
   double vmfe, vmae;      // trajeto virtual com SL/TP originais (pts)
   bool closed; long tCloseMs; double exitPx, net, comm; int exitReason; double finalSL;
   int vres; long vresMs;  // 1 TP original, -1 SL original, 2 horizonte
   double mfe5, mfe15;     // MFE (pts) nos 5/15 min apos a entrada
};
DiagT diag[];
int diagN=0;
void DiagRegister(ulong pos,int dir,double req,double fill,double sl,double tp,const MqlTick &tk,double atr,int setup)
{
   ArrayResize(diag,diagN+1);
   DiagT d; ZeroMemory(d);
   d.pos=pos; d.tOpenMs=tk.time_msc; d.dir=dir; d.req=req; d.entry=fill; d.sl0=sl; d.tp0=tp;
   d.spread=(tk.ask-tk.bid)/_Point; d.atr=atr; d.setup=setup; d.finalSL=sl;
   diag[diagN++]=d;
}
void DiagUpdate(const MqlTick &tk)
{
   for(int i=0;i<diagN;i++)
   {
      if(diag[i].vres!=0 && diag[i].closed) continue;
      double q = diag[i].dir>0 ? tk.bid : tk.ask;
      double g = diag[i].dir*(q-diag[i].entry)/_Point;
      long age = tk.time_msc-diag[i].tOpenMs;
      if(age<=5*60000)  diag[i].mfe5 =MathMax(diag[i].mfe5,g);
      if(age<=15*60000) diag[i].mfe15=MathMax(diag[i].mfe15,g);
      if(!diag[i].closed)
      {
         if(PositionSelectByTicket(diag[i].pos))
         {
            diag[i].mfe=MathMax(diag[i].mfe,g); diag[i].mae=MathMin(diag[i].mae,g);
            diag[i].finalSL=PositionGetDouble(POSITION_SL);
         }
         else
         {
            diag[i].closed=true; diag[i].tCloseMs=tk.time_msc;
            if(HistorySelectByPosition(diag[i].pos))
            {
               int n=HistoryDealsTotal(); double net=0, cm=0;
               for(int k=0;k<n;k++)
               {
                  ulong dl=HistoryDealGetTicket(k);
                  net+=HistoryDealGetDouble(dl,DEAL_PROFIT)+HistoryDealGetDouble(dl,DEAL_SWAP)+HistoryDealGetDouble(dl,DEAL_COMMISSION);
                  cm+=HistoryDealGetDouble(dl,DEAL_COMMISSION);
                  long en=HistoryDealGetInteger(dl,DEAL_ENTRY);
                  if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_OUT_BY)
                  {
                     diag[i].exitPx=HistoryDealGetDouble(dl,DEAL_PRICE);
                     diag[i].exitReason=(int)HistoryDealGetInteger(dl,DEAL_REASON);
                     diag[i].tCloseMs=HistoryDealGetInteger(dl,DEAL_TIME_MSC);
                  }
                  if(en==DEAL_ENTRY_IN) diag[i].entry=HistoryDealGetDouble(dl,DEAL_PRICE);
               }
               diag[i].net=net; diag[i].comm=cm;
            }
         }
      }
      if(diag[i].vres==0)
      {
         diag[i].vmfe=MathMax(diag[i].vmfe,g); diag[i].vmae=MathMin(diag[i].vmae,g);
         bool hitSL = diag[i].dir>0 ? (tk.bid<=diag[i].sl0) : (tk.ask>=diag[i].sl0);
         bool hitTP = diag[i].tp0>0 && (diag[i].dir>0 ? (tk.bid>=diag[i].tp0) : (tk.ask<=diag[i].tp0));
         if(hitSL) {diag[i].vres=-1; diag[i].vresMs=tk.time_msc;}
         else if(hitTP) {diag[i].vres=1; diag[i].vresMs=tk.time_msc;}
         else if(age>DiagHorizonMinutes*60000) {diag[i].vres=2; diag[i].vresMs=tk.time_msc;}
      }
   }
}
void DiagWrite()
{
   int h=FileOpen("ALIEN_DIAG_"+_Symbol+".csv",FILE_WRITE|FILE_ANSI|FILE_TXT);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,"pos;open_ms;dir;setup;req;entry;sl0;tp0;spread_pts;atr_pts;sl_pts;tp_pts;mfe;mae;closed;close_ms;exit_px;exit_reason;final_sl;net;comm;vres;vres_ms;vmfe;vmae;mfe5;mfe15\n");
   for(int i=0;i<diagN;i++)
   {
      DiagT d=diag[i];
      FileWriteString(h,StringFormat("%I64u;%I64d;%d;%d;%.2f;%.2f;%.2f;%.2f;%.1f;%.1f;%.1f;%.1f;%.1f;%.1f;%d;%I64d;%.2f;%d;%.2f;%.2f;%.2f;%d;%I64d;%.1f;%.1f;%.1f;%.1f\n",
         d.pos,d.tOpenMs,d.dir,d.setup,d.req,d.entry,d.sl0,d.tp0,d.spread,d.atr,
         MathAbs(d.entry-d.sl0)/_Point,(d.tp0>0?MathAbs(d.tp0-d.entry)/_Point:0),d.mfe,d.mae,(int)d.closed,d.tCloseMs,d.exitPx,d.exitReason,d.finalSL,d.net,d.comm,d.vres,d.vresMs,d.vmfe,d.vmae,d.mfe5,d.mfe15));
   }
   FileClose(h);
}
//==================== FIM DIAG ====
