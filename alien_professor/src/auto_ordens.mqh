
//====================================================================
// v12.6 — ORDENS PELO TELEGRAM (só o Vitor, sempre com Confirmar) + MODO AUTÔNOMO NA DEMO
//  Ordens manuais: sem trava. Limites do dia e falta de stop viram AVISO; ele decide no Confirmar.
//  Únicos bloqueios: não é o dono, telegram_ordens (off / demo em conta real), confirmação vencida,
//  e preço médio (somar na MESMA direção de uma posição que está perdendo = martingale).
//  Autônomo: só em conta DEMO (checa toda vez), com as regras de risco do próprio robô.
//====================================================================
CTrade g_trTg;
struct OrdemPend { string id; int tipo; string sym; int dir; double lot; double sl; double tp; double frac; double novo; datetime t; string resumo; };
OrdemPend g_op;
string g_ordArq="ALIEN_ordens_telegram.csv";
string g_ordHdr="hora_brasilia;quem;tipo;simbolo;lado;lote;preco;stop;alvo;risco_usd;status;retcode;detalhe";
#define ORD_SEG 60

bool ContaDemo(){ return AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO; }
// ---------------- regras puras (espelhadas em teste/check_mocks.py) ----------------
string OrdensPermitidas(string modo,bool contaDemo,bool dono)
{
   if(!dono) return "Só o Vitor pode mandar ordem.";
   string m=modo; StringToLower(m);
   if(m=="off" || m=="0" || m=="nao") return "Ordens pelo Telegram estão desligadas (telegram_ordens=off no ALIEN_config.txt).";
   if(m=="real") return "";
   if(!contaDemo) return "Essa conta é REAL e o ALIEN_config.txt está com telegram_ordens=demo. Se quiser mesmo na real, troque pra telegram_ordens=real (decisão sua).";
   return "";
}
// bloqueios duros (poucos): lote, lado do stop/alvo, teto de lote opcional, preço médio
string OrdemBloqueio(int dir,double preco,double sl,double tp,double lot,double loteMax,bool somaNaPerdedora)
{
   if(dir!=1 && dir!=-1) return "Não entendi se é compra ou venda.";
   if(lot<=0) return "Lote inválido.";
   if(loteMax>0 && lot>loteMax+1e-9) return StringFormat("Lote %.2f passa do teto que você pôs (ordem_lote_max=%.2f).",lot,loteMax);
   if(sl>0 && ((dir==1 && sl>=preco) || (dir==-1 && sl<=preco))) return "O stop tá do lado errado do preço (compra: stop abaixo; venda: stop acima).";
   if(tp>0 && ((dir==1 && tp<=preco) || (dir==-1 && tp>=preco))) return "O alvo tá do lado errado do preço.";
   if(somaNaPerdedora) return "Você já tem posição nessa direção perdendo. Somar mais seria preço médio (martingale) — isso eu não faço. Feche ou espere.";
   return "";
}
// avisos (não bloqueiam): uma linha cada
string OrdemAvisos(double sl,double riskUSD,double saldo,double riscoPctAviso,int stopsHoje,int maxStops,double netHoje,double perdaMax,double rr,string regra)
{
   string a="";
   if(sl<=0) a+="⚠️ Sem stop: se o preço disparar contra, a perda não tem limite.\n";
   if(saldo>0 && riskUSD>0 && riscoPctAviso>0 && riskUSD>riscoPctAviso/100.0*saldo) a+=StringFormat("⚠️ Risco de %.1f%% da conta (acima de %.1f%%).\n",100.0*riskUSD/saldo,riscoPctAviso);
   if(maxStops>0 && stopsHoje>=maxStops) a+=StringFormat("⚠️ Já foram %d stops hoje (seu limite: %d).\n",stopsHoje,maxStops);
   else if(stopsHoje>=2) a+=StringFormat("⚠️ Já foram %d stops hoje.\n",stopsHoje);
   if(perdaMax>0 && netHoje-riskUSD<-perdaMax) a+=StringFormat("⚠️ Se der stop, o dia passa da sua perda máxima ($%.0f).\n",perdaMax);
   if(rr>0 && rr<1.5) a+=StringFormat("⚠️ Alvo pequeno: %.1fx o risco (o robô usa no mínimo 1,5x).\n",rr);
   if(regra!="") a+="⚠️ Sua regra: "+regra+"\n";
   return a;
}
bool OrdemConfirmavel(string id,string idPend,datetime tPend,datetime now,bool dono)
{
   return dono && idPend!="" && id==idPend && tPend>0 && now-tPend<=ORD_SEG && now>=tPend;
}
bool AutonomoPermitido(bool cfgLigado,bool contaDemo){ return cfgLigado && contaDemo; }
// adaptação: só SOBE a nota mínima ou desliga o balde. Nunca mexe em risco/lote. Nunca desce da base.
int AdaptaLimiar(int base,int n,double mediaR,int minN,bool &desliga)
{
   desliga=false;
   if(n<minN) return base;
   if(mediaR<0){ desliga=true; return base; }
   if(mediaR<0.10) return (int)MathMin(base+1,10);
   return base;
}
// ---------------- texto -> pedido de ordem ----------------
string NumLimpo(string t)
{
   string o=""; int n=StringLen(t);
   for(int i=0;i<n;i++)
   {
      ushort c=StringGetCharacter(t,i);
      if(c==',' && i>0 && i<n-1){ ushort a=StringGetCharacter(t,i-1), b=StringGetCharacter(t,i+1); if(a>='0'&&a<='9'&&b>='0'&&b<='9'){ o+="."; continue; } o+=" "; continue; }
      o+=ShortToString(c);
   }
   return o;
}
bool EhNum(string w){ if(w=="") return false; int pts=0; for(int i=0;i<StringLen(w);i++){ ushort c=StringGetCharacter(w,i); if(c=='.') { pts++; continue; } if(c<'0'||c>'9') return false; } return pts<=1 && w!="."; }
double NumApos(const string &w[],int n,string k1,string k2="",string k3="")
{
   for(int i=0;i<n-1;i++) if(w[i]==k1 || (k2!="" && w[i]==k2) || (k3!="" && w[i]==k3))
   {
      for(int j=i+1;j<n && j<=i+3;j++){ if(EhNum(w[j])) return StringToDouble(w[j]); if(w[j]=="zero"||w[j]=="be"||w[j]=="breakeven"||w[j]=="entrada") return -1; }
   }
   return 0;
}
// reconhece: compra/vende [lote] [stop X] [alvo Y] [símbolo]; fecha tudo/metade/[símbolo]; stop no zero / stop para X; alvo para X
bool OrdemDeTexto(string text,OrdemPend &o)
{
   string u=Baixo(NumLimpo(text)); if(StringFind(u,"?")>=0 || StringFind(u," ou ")>=0 || StringLen(u)>120) return false;
   string pn[]={"!",";",":","(",")","\""}; for(int i=0;i<ArraySize(pn);i++) StringReplace(u,pn[i]," ");
   StringTrimLeft(u); StringTrimRight(u);
   string w[]; int n=StringSplit(u,' ',w); string ww[]; int m=0; for(int i=0;i<n;i++) if(w[i]!=""){ ArrayResize(ww,m+1); ww[m++]=w[i]; }
   if(m==0) return false;
   o.id=""; o.tipo=0; o.sym=_Symbol; o.dir=0; o.lot=0; o.sl=0; o.tp=0; o.frac=1; o.novo=0; o.t=0; o.resumo="";
   string w0=ww[0], w1=m>1?ww[1]:"";
   if(w0=="abre"||w0=="abrir"||w0=="manda"||w0=="faz"){ w0=w1; }
   bool compra=(w0=="compra"||w0=="compre"||w0=="comprar"||w0=="buy"), venda=(w0=="vende"||w0=="venda"||w0=="vender"||w0=="sell"||w0=="vend");
   for(int i=0;i<m;i++){ string s=SimboloDe(ww[i],false); if(s!=""){ o.sym=s; break; } }
   if(compra||venda)
   {
      o.tipo=1; o.dir=compra?1:-1;
      o.sl=NumApos(ww,m,"stop","sl","stoploss"); if(o.sl<0) o.sl=0;
      o.tp=NumApos(ww,m,"alvo","tp","take");  if(o.tp<0) o.tp=0;
      o.lot=NumApos(ww,m,"lote","lotes","lot");
      if(o.lot<=0){ for(int i=1;i<m;i++){ if(i>0 && (ww[i-1]=="stop"||ww[i-1]=="sl"||ww[i-1]=="alvo"||ww[i-1]=="tp"||ww[i-1]=="em"||ww[i-1]=="no"||ww[i-1]=="para")) continue; if(EhNum(ww[i])){ double v=StringToDouble(ww[i]); if(v>0 && v<=100){ o.lot=v; break; } } } }
      return true;
   }
   bool fecha=(w0=="fecha"||w0=="fechar"||w0=="feche"||w0=="zera"||w0=="zerar"||w0=="encerra");
   if(fecha)
   {
      o.tipo=2; o.frac=(StringFind(u,"metade")>=0||StringFind(u,"meia")>=0||StringFind(u,"50%")>=0)?0.5:1.0;
      bool achouSym=false; for(int i=1;i<m;i++) if(SimboloDe(ww[i],false)!="") achouSym=true;
      if(!achouSym && (StringFind(u,"tudo")>=0||StringFind(u,"todas")>=0||StringFind(u,"todos")>=0||w0=="zera"||w0=="zerar")) o.sym="";
      if(StringFind(u,"compra")>=0) o.dir=1; else if(StringFind(u,"venda")>=0) o.dir=-1;
      return true;
   }
   bool temStop=(StringFind(u,"stop")>=0), temAlvo=(StringFind(u,"alvo")>=0);
   bool verbo=(w0=="move"||w0=="mover"||w0=="muda"||w0=="mudar"||w0=="coloca"||w0=="poe"||w0=="bota"||w0=="stop"||w0=="alvo"||w0=="sobe"||w0=="desce"||w0=="leva");
   if(verbo && temStop)
   {
      o.tipo=3; double v=NumApos(ww,m,"para","pra","em"); if(v==0) v=NumApos(ww,m,"stop","no","pro");
      if(StringFind(u,"zero")>=0||StringFind(u,"breakeven")>=0||StringFind(u,"empate")>=0||StringFind(u," be")>=0||StringFind(u,"entrada")>=0) v=-1;
      if(v==0) return false; o.novo=v; return true;
   }
   if(verbo && temAlvo)
   {
      o.tipo=4; double v=NumApos(ww,m,"para","pra","em"); if(v==0) v=NumApos(ww,m,"alvo"); if(v<=0) return false; o.novo=v; return true;
   }
   return false;
}
// ---------------- risco, posições ----------------
double RiscoUSD(string sym,int dir,double lot,double preco,double sl)
{
   if(sl<=0 || lot<=0) return 0; double pr=0;
   if(OrderCalcProfit(dir==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL,sym,lot,preco,sl,pr)) return MathAbs(pr);
   double tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE); if(ts<=0) return 0;
   return MathAbs(preco-sl)/ts*tv*lot;
}
double LoteNorm(string sym,double lot)
{
   double st=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP), mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   if(st<=0) st=0.01; lot=MathFloor(lot/st+1e-9)*st; if(lot<mn) lot=0; if(mx>0 && lot>mx) lot=mx;
   return NormalizeDouble(lot,2);
}
bool SomaNaPerdedora(string sym,int dir)
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(t==0 || PositionGetString(POSITION_SYMBOL)!=sym) continue;
      int d=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1; if(d==dir && PositionGetDouble(POSITION_PROFIT)<0) return true; }
   return false;
}
string RetcodeTxt(uint rc)
{
   switch(rc)
   {
      case 10008: case 10009: return "feito";
      case 10010: return "feito só em parte";
      case 10004: return "o preço mudou (requote); tenta de novo";
      case 10006: return "a corretora recusou";
      case 10007: return "cancelado";
      case 10013: return "pedido inválido";
      case 10014: return "lote inválido pra esse ativo";
      case 10015: return "preço inválido";
      case 10016: return "stop ou alvo perto demais do preço (ou do lado errado)";
      case 10017: return "negociação desligada nesse ativo";
      case 10018: return "mercado fechado";
      case 10019: return "sem margem suficiente na conta";
      case 10020: return "o preço mudou; tenta de novo";
      case 10021: return "sem cotação agora";
      case 10024: return "pedidos demais seguidos; espera uns segundos";
      case 10026: return "a corretora desligou robôs nessa conta";
      case 10027: return "o botão Algo Trading do MT5 tá desligado (liga lá em cima no MT5)";
      case 10030: return "tipo de preenchimento não aceito pela corretora";
      case 10031: return "sem conexão com a corretora";
      case 10040: return "limite de posições da conta";
      case 10044: return "esse ativo só deixa fechar posição";
   }
   return "código "+IntegerToString((int)rc);
}
void OrdemLog(string tipo,string sym,int dir,double lot,double preco,double sl,double tp,double risco,string status,uint rc,string det)
{
   CsvAppend(g_ordArq,g_ordHdr,StringFormat("%s;%s;%s;%s;%s;%.2f;%s;%s;%s;%.2f;%s;%u;%s",TimeToString(AgoraBR(),TIME_DATE|TIME_SECONDS),CsvLimpo(g_tgQuem),tipo,sym,dir==1?"compra":(dir==-1?"venda":"-"),lot,
      sym!=""?FmtS(sym,preco):"-",sl>0&&sym!=""?FmtS(sym,sl):"-",tp>0&&sym!=""?FmtS(sym,tp):"-",risco,status,rc,CsvLimpo(det)));
}
// ---------------- montar o resumo + botões ----------------
void OrdemPropoe(OrdemPend &o)
{
   string pm=OrdensPermitidas(g_cfgTgOrdens,ContaDemo(),TgDono());
   if(pm!=""){ OrdemLog("pedido",o.sym,o.dir,o.lot,0,o.sl,o.tp,0,"recusado",0,pm); SendMsg("🚫 "+pm); return; }
   if(MQLInfoInteger(MQL_TESTER)) return;
   string sym=o.sym; double saldo=AccountInfoDouble(ACCOUNT_BALANCE);
   string txt="", aviso="";
   if(o.tipo==1)
   {
      if(!TemCotacao(sym)){ SendMsg("Sem cotação de "+sym+" agora."); return; }
      double preco=o.dir==1?SymbolInfoDouble(sym,SYMBOL_ASK):SymbolInfoDouble(sym,SYMBOL_BID);
      string sug="";
      if(o.sl<=0 && sym==_Symbol){ Plano p=(o.dir==1?g_pb:g_ps); if(PlanoValido(p) && ((o.dir==1 && p.stop<preco)||(o.dir==-1 && p.stop>preco))){ o.sl=p.stop; if(o.tp<=0) o.tp=p.target; sug=" (stop"+(o.tp==p.target?" e alvo":"")+" sugeridos pelo painel — pode trocar)"; } }
      if(o.lot<=0)
      {
         double rUnit=RiscoUSD(sym,o.dir,1.0,preco,o.sl);
         o.lot= rUnit>0 ? LoteNorm(sym,InpRiskUSD/rUnit) : SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
         if(o.lot<=0) o.lot=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
         sug+=StringFormat(" (lote calculado pro risco de $%.0f)",InpRiskUSD);
      }
      o.lot=LoteNorm(sym,o.lot); if(o.lot<=0){ SendMsg("Esse lote fica abaixo do mínimo do "+sym+"."); return; }
      string bl=OrdemBloqueio(o.dir,preco,o.sl,o.tp,o.lot,g_cfgOrdLoteMax,SomaNaPerdedora(sym,o.dir));
      if(bl!=""){ OrdemLog("abrir",sym,o.dir,o.lot,preco,o.sl,o.tp,0,"recusado",0,bl); SendMsg("🚫 "+bl); return; }
      double risco=RiscoUSD(sym,o.dir,o.lot,preco,o.sl);
      double rr=(o.sl>0 && o.tp>0)?MathAbs(o.tp-preco)/MathAbs(preco-o.sl):0;
      aviso=OrdemAvisos(o.sl,risco,saldo,g_cfgOrdRiscoPct,g_stopsHoje,g_cfgMaxStopsDia,g_netHoje,g_cfgPerdaMaxDia,rr,RegraQuebrada(o.lot));
      txt=StringFormat("📝 Confere a ordem:\n%s %s %.2f lote a mercado (~%s)\n🛑 Stop: %s\n🎯 Alvo: %s\n💵 Risco: %s%s\n⚖️ R:R: %s%s\nConta %s.",
         o.dir==1?"🟢 COMPRA":"🔴 VENDA",sym,o.lot,FmtS(sym,preco),o.sl>0?FmtS(sym,o.sl):"SEM STOP",o.tp>0?FmtS(sym,o.tp):"sem alvo",
         o.sl>0?StringFormat("$%.2f",risco):"sem limite",o.sl>0&&saldo>0?StringFormat(" (%.2f%% do saldo)",100.0*risco/saldo):"",rr>0?StringFormat("%.1f",rr):"-",sug,ContaDemo()?"DEMO":"REAL");
   }
   else if(o.tipo==2)
   {
      int np=0; string ls="";
      for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(t==0) continue; string s=PositionGetString(POSITION_SYMBOL); int d=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
         if(o.sym!="" && s!=o.sym) continue; if(o.dir!=0 && d!=o.dir) continue; np++; ls+=StringFormat("  %s %s %.2f  P/L $%+.2f\n",d==1?"compra":"venda",s,PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PROFIT)); }
      if(np==0){ SendMsg("Não tem posição aberta"+(o.sym!=""?" no "+o.sym:"")+" pra fechar."); return; }
      txt=StringFormat("📝 Confere: fechar %s de %d posição(ões):\n%s",o.frac<1?"METADE":"TUDO",np,ls);
   }
   else
   {
      int np=0; string ls="";
      for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(t==0 || PositionGetString(POSITION_SYMBOL)!=o.sym) continue; np++;
         double op=PositionGetDouble(POSITION_PRICE_OPEN); double nv=(o.tipo==3 && o.novo<0)?op:o.novo;
         ls+=StringFormat("  %s %.2f: %s %s -> %s\n",PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",PositionGetDouble(POSITION_VOLUME),o.tipo==3?"stop":"alvo",
             FmtS(o.sym,o.tipo==3?PositionGetDouble(POSITION_SL):PositionGetDouble(POSITION_TP)),FmtS(o.sym,nv)); }
      if(np==0){ SendMsg("Não tem posição aberta no "+o.sym+"."); return; }
      txt="📝 Confere: mudar "+(o.tipo==3?(o.novo<0?"o stop pro zero (preço de entrada)":"o stop"):"o alvo")+" no "+o.sym+":\n"+ls;
   }
   MathSrand((uint)GetTickCount()); o.id=IntegerToString(100000+MathRand()%900000); o.t=TimeLocal(); o.resumo=txt;
   g_op=o;
   OrdemLog(o.tipo==1?"abrir":(o.tipo==2?"fechar":(o.tipo==3?"stop":"alvo")),o.sym,o.dir,o.lot,0,o.sl,o.tp,0,"proposto",0,"id "+o.id);
   SendMsgMarkup(txt+(aviso!=""?"\n\n"+aviso:"\n")+StringFormat("\nVale por %d s.",ORD_SEG),TgKbSimNao("✅ Confirmar","/ordem_ok "+o.id,"❌ Cancelar","/ordem_nao "+o.id));
}
// etiqueta da IA -> mesmo caminho (sempre pede Confirmar)
string OrdemDeAcao(string nome,string params)
{
   OrdemPend o; o.id=""; o.tipo=0; o.sym=_Symbol; o.dir=0; o.lot=0; o.sl=0; o.tp=0; o.frac=1; o.novo=0; o.t=0; o.resumo="";
   if(nome=="ordem"){ string l=Baixo(AcaoP(params,0)); o.tipo=1; o.dir=(StringFind(l,"compr")>=0||l=="buy")?1:((StringFind(l,"vend")>=0||l=="sell")?-1:0); o.lot=NumDe(AcaoP(params,1)); o.sl=NumDe(AcaoP(params,2)); o.tp=NumDe(AcaoP(params,3)); if(o.dir==0) return "Não entendi se é compra ou venda."; }
   else if(nome=="fechar"){ string a=Baixo(AcaoP(params,0)); o.tipo=2; o.frac=(StringFind(a,"metade")>=0)?0.5:1; if(a=="tudo"||a==""||a=="metade") o.sym=""; else { string s=SimboloDe(a,true); if(s!="") o.sym=s; } }
   else if(nome=="stop"){ string a=Baixo(AcaoP(params,0)); o.tipo=3; o.novo=(a=="zero"||a=="be"||a=="breakeven"||a=="entrada")?-1:NumDe(a); if(o.novo==0) return "Faltou o preço do stop."; }
   else if(nome=="alvo"){ o.tipo=4; o.novo=NumDe(AcaoP(params,0)); if(o.novo<=0) return "Faltou o preço do alvo."; }
   OrdemPropoe(o); return "";
}
// ---------------- executar (só pelo botão Confirmar) ----------------
void OrdemConfirma(string id)
{
   if(!OrdemConfirmavel(id,g_op.id,g_op.t,TimeLocal(),TgDono()))
   {
      string why=!TgDono()?"Só o Vitor pode confirmar.":(id!=g_op.id||g_op.id==""?"Essa ordem não vale mais (já foi usada ou foi trocada).":"Passou de 60 s, cancelei por segurança. Manda de novo.");
      OrdemLog("confirmar",g_op.sym,g_op.dir,g_op.lot,0,g_op.sl,g_op.tp,0,"recusado",0,why); SendMsg("⌛ "+why); if(TgDono() && id==g_op.id) g_op.id=""; return;
   }
   string pm=OrdensPermitidas(g_cfgTgOrdens,ContaDemo(),TgDono()); if(pm!=""){ g_op.id=""; SendMsg("🚫 "+pm); return; }
   OrdemPend o=g_op; g_op.id="";
   SendMsg(OrdemExecuta(o));
}
void OrdemCancela(string id){ if(id==g_op.id && TgDono()){ OrdemLog("cancelar",g_op.sym,g_op.dir,g_op.lot,0,g_op.sl,g_op.tp,0,"cancelado",0,""); g_op.id=""; } SendMsg("Beleza, não fiz nada."); }
string OrdemExecuta(OrdemPend &o)
{
   g_trTg.SetExpertMagicNumber(InpMagic+1); g_trTg.SetDeviationInPoints(50);
   if(o.tipo==1)
   {
      g_trTg.SetTypeFillingBySymbol(o.sym);
      double preco=o.dir==1?SymbolInfoDouble(o.sym,SYMBOL_ASK):SymbolInfoDouble(o.sym,SYMBOL_BID);
      string bl=OrdemBloqueio(o.dir,preco,o.sl,o.tp,o.lot,g_cfgOrdLoteMax,SomaNaPerdedora(o.sym,o.dir));
      if(bl!=""){ OrdemLog("abrir",o.sym,o.dir,o.lot,preco,o.sl,o.tp,0,"recusado",0,bl); return "🚫 O preço andou e "+bl; }
      double risco=RiscoUSD(o.sym,o.dir,o.lot,preco,o.sl);
      bool ok=o.dir==1?g_trTg.Buy(o.lot,o.sym,0,o.sl,o.tp,"ALIEN telegram"):g_trTg.Sell(o.lot,o.sym,0,o.sl,o.tp,"ALIEN telegram");
      uint rc=g_trTg.ResultRetcode(); double px=g_trTg.ResultPrice();
      ok=ok && (rc==10008||rc==10009||rc==10010);
      OrdemLog("abrir",o.sym,o.dir,o.lot,px>0?px:preco,o.sl,o.tp,risco,ok?"executado":"recusado",rc,g_trTg.ResultRetcodeDescription());
      if(!ok) return "❌ Não entrou: "+RetcodeTxt(rc)+".";
      ObsSet(StringFormat("Você mandou %s %.2f pelo Telegram em %s.",o.dir==1?"compra":"venda",o.lot,FmtS(o.sym,px)),"💼");
      return StringFormat("✅ Entrou: %s %s %.2f lote em %s. Stop %s, alvo %s.",o.dir==1?"🟢 compra":"🔴 venda",o.sym,o.lot,FmtS(o.sym,px>0?px:preco),o.sl>0?FmtS(o.sym,o.sl):"SEM STOP",o.tp>0?FmtS(o.sym,o.tp):"sem alvo");
   }
   string res=""; int okN=0, errN=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue; string s=PositionGetString(POSITION_SYMBOL); int d=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      if(o.tipo==2){ if(o.sym!="" && s!=o.sym) continue; if(o.dir!=0 && d!=o.dir) continue; }
      else if(s!=o.sym) continue;
      g_trTg.SetTypeFillingBySymbol(s);
      double vol=PositionGetDouble(POSITION_VOLUME), op=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
      bool ok=false; string tipo="";
      if(o.tipo==2)
      {
         tipo="fechar";
         if(o.frac<1){ double v=LoteNorm(s,vol*o.frac); if(v<=0||v>=vol){ ok=g_trTg.PositionClose(t); res+="(metade ficava abaixo do lote mínimo, fechei tudo) "; } else ok=g_trTg.PositionClosePartial(t,v); }
         else ok=g_trTg.PositionClose(t);
      }
      else if(o.tipo==3)
      {
         tipo="stop"; double nv=(o.novo<0?op:o.novo); double bid=SymbolInfoDouble(s,SYMBOL_BID), ask=SymbolInfoDouble(s,SYMBOL_ASK);
         if((d==1 && nv>=bid) || (d==-1 && nv<=ask)){ res+="Stop "+FmtS(s,nv)+" ficaria do outro lado do preço agora; não mexi. "; errN++; continue; }
         ok=g_trTg.PositionModify(t,nv,tp);
      }
      else
      {
         tipo="alvo"; double bid=SymbolInfoDouble(s,SYMBOL_BID), ask=SymbolInfoDouble(s,SYMBOL_ASK);
         if((d==1 && o.novo<=ask) || (d==-1 && o.novo>=bid)){ res+="Alvo "+FmtS(s,o.novo)+" ficaria do lado errado; não mexi. "; errN++; continue; }
         ok=g_trTg.PositionModify(t,sl,o.novo);
      }
      uint rc=g_trTg.ResultRetcode(); ok=ok && (rc==10008||rc==10009||rc==10010);
      OrdemLog(tipo,s,d,vol,op,sl,tp,0,ok?"executado":"recusado",rc,g_trTg.ResultRetcodeDescription());
      if(ok) okN++; else { errN++; res+=s+": "+RetcodeTxt(rc)+". "; }
   }
   if(okN==0 && errN==0) return "Não achei posição pra mexer.";
   return (okN>0?StringFormat("✅ Feito em %d posição(ões). ",okN):"")+(errN>0?"❌ "+res:res);
}
// ---------------- MODO AUTÔNOMO (DEMO) ----------------
datetime g_adaptReset=0;
bool AutonomoAtivo(){ return !g_tradePausa && AutonomoPermitido(g_cfgAutonomo,ContaDemo()); }
bool PorAutonomo(){ return AutonomoAtivo() && !(InpTradeEnabled && !g_cfgAssistente); }
int AdaptMinN(){ return (int)MathMax(20,InpAprenderMinN); }
void AdaptLoad(){ string s=ArqLe("ALIEN_adapt_reset.txt"); g_adaptReset=(datetime)StringToInteger(s); }
void AdaptStat(int dir,string sess,int &n,double &win,double &avg)
{
   LoadHist(); n=0; double w=0,s=0;
   for(int i=0;i<ArraySize(g_hist);i++)
   {
      if(g_hist[i].sym!=_Symbol || g_hist[i].dir!=dir || g_hist[i].sess!=sess) continue;
      if(g_adaptReset>0 && g_hist[i].t<g_adaptReset) continue;
      n++; s+=g_hist[i].R; if(g_hist[i].R>0) w++;
   }
   win=n>0?100.0*w/n:0; avg=n>0?s/n:0;
}
int AutonomoLimiar(int dir,string sess,bool &desliga)
{
   int n; double w,a; AdaptStat(dir,sess,n,w,a);
   return AdaptaLimiar(MathMax(InpScoreTrade,NotaAlertaMin()),n,a,AdaptMinN(),desliga);
}
// filtros extras do autônomo (além de Bloqueio, RR >= 1,5, 1 posição, stop obrigatório)
string AutonomoFiltro(const Plano &b)
{
   if(!ContaDemo()) return "conta não é DEMO";
   if(b.stop<=0) return "sem stop";
   if(g_mtf[2]!=b.dir) return "H1 não está a favor";
   string st; int sN=SessaoNota(TimeCurrent(),st);
   bool kz=(g_engKZ!="" && StringFind(g_engKZ,"fora")<0);
   if(sN!=1 && !kz) return "fora do horário bom/killzone";
   bool des=false; int lim=AutonomoLimiar(b.dir,SessNome(TimeCurrent()),des);
   if(des) return "aprendizado desligou "+(b.dir==1?"compra":"venda")+" em "+SessNome(TimeCurrent())+" (média negativa)";
   if(b.score<lim) return StringFormat("nota %d abaixo do mínimo aprendido (%d)",b.score,lim);
   return "";
}
string g_sessNomes[4]={"Ásia","Londres","Nova York","fim de NY / madrugada"};
string AdaptAssinatura()
{
   string s="";
   for(int d=0;d<2;d++) for(int q=0;q<4;q++){ bool des; int lim=AutonomoLimiar(d==0?1:-1,g_sessNomes[q],des); s+=StringFormat("%d%d:%s;",d,q,des?"off":IntegerToString(lim)); }
   return s;
}
string AdaptTabelaTxt()
{
   string s=StringFormat("🧠 Aprendizado do autônomo (%s, amostra mínima %d por balde%s):\n",_Symbol,AdaptMinN(),g_adaptReset>0?", contando desde "+TimeToString(g_adaptReset,TIME_DATE):"");
   int base=MathMax(InpScoreTrade,NotaAlertaMin());
   for(int d=0;d<2;d++) for(int q=0;q<4;q++)
   {
      int dir=d==0?1:-1; int n; double w,a; AdaptStat(dir,g_sessNomes[q],n,w,a); bool des; int lim=AdaptaLimiar(base,n,a,AdaptMinN(),des);
      s+=StringFormat("• %s %s: %d trades, acerto %.0f%%, média %+.2fR → %s\n",dir==1?"compra":"venda",g_sessNomes[q],n,w,a,n<AdaptMinN()?StringFormat("pouco dado, nota mín. %d",lim):(des?"DESLIGADO":StringFormat("nota mín. %d",lim)));
   }
   s+="Regra: só sobe a nota ou desliga; nunca aumenta lote ou risco. /reset_aprendizado zera a contagem (não apaga os dados).";
   return s;
}
string AdaptCompactoIA()
{
   int nT=0; double sT=0; LoadHist();
   for(int i=0;i<ArraySize(g_hist);i++){ if(g_hist[i].sym!=_Symbol) continue; if(g_adaptReset>0 && g_hist[i].t<g_adaptReset) continue; nT++; sT+=g_hist[i].R; }
   string s=StringFormat("APRENDIZADO AO VIVO (%s): autônomo %s; %d trades do robô registrados, média %+.2fR.",_Symbol,AutonomoAtivo()?"LIGADO na demo":"desligado",nT,nT>0?sT/nT:0);
   for(int d=0;d<2;d++) for(int q=0;q<4;q++){ int n; double w,a; AdaptStat(d==0?1:-1,g_sessNomes[q],n,w,a); if(n>0) s+=StringFormat(" %s/%s n=%d %+.2fR;",d==0?"compra":"venda",g_sessNomes[q],n,a); }
   return s+"\n";
}
void AdaptChecaMudou()
{
   string novo=AdaptAssinatura(), velho=ArqLe("ALIEN_adapt_estado.txt"); StringTrimRight(velho);
   if(novo==velho) return;
   ArqGrava("ALIEN_adapt_estado.txt",novo);
   if(velho!="" && TgOk()) SendMsg("🧠 Aprendi algo e ajustei o autônomo (só ficou mais exigente, risco igual):\n"+AdaptTabelaTxt());
}
void DecisaoLog(const Plano &b,string acao)
{
   string st; SessaoNota(TimeCurrent(),st); double spr=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID);
   string pts=""; for(int i=0;i<7;i++) pts+=(b.pts[i]?"1":"0");
   bool des=false; int lim=AutonomoLimiar(b.dir,SessNome(TimeCurrent()),des);
   CsvAppend("ALIEN_decisoes.csv","hora_servidor;hora_brasilia;simbolo;modo;lado;nota;limiar;balde_desligado;sessao;killzone;D1;H4;H1;M15;M5;M1;criterios;entrada;stop;alvo;rr;spread;lote;risco_usd;acao",
      StringFormat("%s;%s;%s;%s;%s;%d;%d;%s;%s;%s;%d;%d;%d;%d;%d;%d;'%s;%s;%s;%s;%.2f;%s;%.2f;%.2f;%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),TimeToString(SrvParaBR(TimeCurrent()),TIME_DATE|TIME_MINUTES),_Symbol,
      PorAutonomo()?"autonomo":(TradeAtivo()?"auto":"assistente"),b.dir==1?"compra":"venda",b.score,lim,des?"sim":"nao",CsvLimpo(st),CsvLimpo(g_engKZ),g_mtf[0],g_mtf[1],g_mtf[2],g_mtf[3],g_mtf[4],g_mtf[5],pts,
      Fmt(b.entry),Fmt(b.stop),b.target>0?Fmt(b.target):"-",b.rr,Fmt(spr),b.lot,b.riskUSD,CsvLimpo(acao)));
}
bool OrdensCmd(string cmd,string args)
{
   if(cmd=="/ordem_ok"){ OrdemConfirma(args); return true; }
   if(cmd=="/ordem_nao"){ OrdemCancela(args); return true; }
   if(cmd=="/ordem"){ OrdemPend o; if(OrdemDeTexto(args,o) && o.tipo>0) OrdemPropoe(o); else SendMsg("Manda assim: compra 0.05 stop 3880 alvo 3900  |  vende 0.02  |  fecha tudo  |  fecha metade  |  stop no zero  |  muda stop para 3885"); return true; }
   if(cmd=="/autonomo"||cmd=="/autônomo")
   {
      string a=Baixo(args);
      if(a=="on"||a=="liga"||a=="ligar"||a=="demo")
      {
         if(!TgDono()){ SendMsg(NaoDono()); return true; }
         if(!ContaDemo()){ SendMsg("🚫 Essa conta é REAL. O modo autônomo só roda em conta DEMO."); return true; }
         CfgSalva("autonomo","demo"); g_cfgAutonomo=true;
         SendMsg("🤖 Autônomo LIGADO na demo. Eu decido sozinho com as regras do robô: nota mínima, H1 a favor, horário bom, alvo 1,5x, stop sempre, limites do dia, 1 posição, sem martingale. Te aviso cada entrada e saída. /autonomo off desliga.");
         return true;
      }
      if(a=="off"||a=="desliga"||a=="desligar")
      {
         if(!TgDono()){ SendMsg(NaoDono()); return true; }
         CfgSalva("autonomo","off"); g_cfgAutonomo=false;
         SendMsg("Autônomo DESLIGADO. Posição aberta (se tiver) continua com stop e alvo; eu não abro mais nada sozinho.");
         return true;
      }
      SendMsg("🤖 Autônomo: "+(AutonomoAtivo()?"LIGADO (demo)":(g_cfgAutonomo&&!ContaDemo()?"bloqueado: conta REAL":(g_cfgAutonomo&&g_tradePausa?"pausado (/retoma)":"desligado")))+".\n/autonomo on | /autonomo off\n\n"+AdaptTabelaTxt());
      return true;
   }
   if(cmd=="/reset_aprendizado")
   {
      if(!TgDono()){ SendMsg(NaoDono()); return true; }
      if(Baixo(args)=="desfaz"){ ArqGrava("ALIEN_adapt_reset.txt",""); g_adaptReset=0; SendMsg("Voltei a contar o histórico todo.\n"+AdaptTabelaTxt()); return true; }
      g_adaptReset=TimeCurrent(); ArqGrava("ALIEN_adapt_reset.txt",IntegerToString((long)g_adaptReset)); ArqGrava("ALIEN_adapt_estado.txt",AdaptAssinatura());
      SendMsg("🧠 Zerei a contagem do aprendizado a partir de agora (os dados antigos continuam salvos). Pra desfazer: /reset_aprendizado desfaz");
      return true;
   }
   return false;
}
