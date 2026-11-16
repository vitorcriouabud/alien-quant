
//====================================================================
// CHAT TELEGRAM (duas vias) + PRÉ-AVISO DE NOTÍCIA + RESUMOS AGENDADOS
// Só aceita mensagens do chat InpTelegramChatId. Não roda no testador.
// Com o robô em vários gráficos, só UM lê as mensagens (trava por variável global).
long     g_tgOff=0;
datetime g_tgStartUtc=0;
string   g_tgHint="";        // chat id do /start (quando InpTelegramChatId está vazio)
string   g_alertados="|";    // notícias já pré-avisadas
string   g_resFeitos="|";    // resumos já enviados (data+nome)
double   g_inst=0;           // id desta instância (trava de quem lê o chat)
bool     g_tgMaster=false;
int      g_tgErrPrint=0;

bool TgMaster()
{
   string gi="APROF_TGM_ID", gt="APROF_TGM_T"; datetime now=TimeLocal();
   if(!GlobalVariableCheck(gi) || GlobalVariableGet(gi)==g_inst || now-(datetime)GlobalVariableGet(gt)>30)
   { GlobalVariableSet(gi,g_inst); GlobalVariableSet(gt,(double)now); return true; }
   return false;
}
void TgMasterSolta(){ if(GlobalVariableCheck("APROF_TGM_ID") && GlobalVariableGet("APROF_TGM_ID")==g_inst){ GlobalVariableDel("APROF_TGM_ID"); GlobalVariableDel("APROF_TGM_T"); } }

// lê string JSON a partir do índice da aspa de abertura (decodifica \n, \uXXXX...)
string JDecode(string r,int p)
{
   string out=""; int n=StringLen(r);
   for(int i=p+1;i<n;i++)
   {
      ushort c=StringGetCharacter(r,i);
      if(c=='\\' && i+1<n)
      {
         ushort d=StringGetCharacter(r,i+1); i++;
         if(d=='n') out+="\n"; else if(d=='t') out+=" "; else if(d=='r') {} 
         else if(d=='u' && i+4<n){ out+=ShortToString((ushort)StringToInteger("0x"+StringSubstr(r,i+1,4))); i+=4; }
         else out+=ShortToString(d);
         continue;
      }
      if(c=='"') break;
      out+=ShortToString(c);
   }
   return out;
}
string JStrKey(string r,string key){ int k=StringFind(r,"\""+key+"\":\""); if(k<0) return ""; return JDecode(r,k+StringLen(key)+3); }
string JNumKey(string r,string key,int from=0)
{
   int k=StringFind(r,"\""+key+"\":",from); if(k<0) return "";
   int i=k+StringLen(key)+3; string s=""; int n=StringLen(r);
   while(i<n){ ushort c=StringGetCharacter(r,i); if((c>='0'&&c<='9')||c=='-') s+=ShortToString(c); else if(s!="") break; else if(c!=' ') break; i++; }
   return s;
}

// --- contexto completo para a IA ---
string FVGJson(const FVGz &f[],int maxN)
{
   string s=""; int n=0;
   for(int i=ArraySize(f)-1;i>=0 && n<maxN;i--){ if(f[i].filled) continue; s+=(s==""?"":",")+StringFormat("{\"dir\":\"%s\",\"topo\":%s,\"fundo\":%s}",f[i].dir==1?"alta":"baixa",Fmt(f[i].top),Fmt(f[i].bot)); n++; }
   return "["+s+"]";
}
string PosJSON()
{
   string s="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      int dg=(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS);
      s+=(s==""?"":",")+StringFormat("{\"simbolo\":\"%s\",\"lado\":\"%s\",\"lote\":%.2f,\"preco\":%s,\"stop\":%s,\"alvo\":%s,\"lucro_usd\":%.2f,\"origem\":\"%s\"}",
         PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",PositionGetDouble(POSITION_VOLUME),
         DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),dg),DoubleToString(PositionGetDouble(POSITION_SL),dg),DoubleToString(PositionGetDouble(POSITION_TP),dg),
         PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?"robo":"manual");
   }
   return "["+s+"]";
}
string HoraUTC3(){ return TimeToString((datetime)(TimeGMT()-3*3600),TIME_DATE|TIME_MINUTES); }
// v12.4: "15/11 18:58" (data e hora de Brasília a partir de um horário do servidor)
string DataHoraBR(datetime srv){ MqlDateTime d; TimeToStruct(SrvParaBR(srv),d); return StringFormat("%02d/%02d %02d:%02d",d.day,d.mon,d.hour,d.min); }
// v12.4: mercado fechado = sem tick há mais de 5 min (fim de semana, feriado, pausa diária)
datetime UltTickSrv(string sym){ datetime t=(datetime)SymbolInfoInteger(sym,SYMBOL_TIME); if(t<=0) t=iTime(sym,PERIOD_M1,0); return t; }
bool MercadoFechado(string sym="")
{
   if(sym=="") sym=_Symbol;
   if(MQLInfoInteger(MQL_TESTER)) return false;
   datetime t=UltTickSrv(sym), now=TimeTradeServer(); if(t<=0 || now<=0) return false;
   return (long)(now-t)>5*60;
}
string MercadoTxt(string sym="")
{
   if(sym=="") sym=_Symbol;
   datetime t=UltTickSrv(sym);
   if(MercadoFechado(sym))
      return "mercado FECHADO desde "+DataHoraBR(t)+" (Brasília). Sem tick ao vivo: os preços são do último fechamento, nada está se mexendo agora";
   return "mercado ABERTO, último tick às "+(t>0?TimeToString(SrvParaBR(t),TIME_MINUTES):"?")+" (Brasília)";
}
// v12.4: regra de horário/mercado que vai em todo prompt de mercado
string RegraHoraMercado()
{
   return " Todo horário que você citar é de Brasília (use o bloco AGORA e hora_brasilia); nunca fale em 'horário do servidor'. "
          "Se o bloco AGORA ou o campo mercado disser FECHADO, avise logo no começo que o mercado está fechado desde aquela hora e que os números são do último fechamento; nunca diga que está vendo ao vivo, no feed ou em tempo real.";
}
string TfSnap(string sym,ENUM_TIMEFRAMES tf)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,tf,0,300,r);
   string nm=StringSubstr(EnumToString(tf),7);
   if(n<80) return "{\"tf\":\""+nm+"\",\"tendencia\":0,\"ema_inclinacao\":0,\"atr\":0,\"ok\":false}";
   double k=2.0/51.0, e=r[n-1].close, ea1=0, ea4=0;
   for(int i=n-1;i>=0;i--){ e=(i==n-1)?r[i].close:r[i].close*k+e*(1-k); if(i==1) ea1=e; if(i==4) ea4=e; }
   double atr=ATRof(r,14,1);
   int slope=0;
   if(atr>0){ if(ea1-ea4>0.05*atr) slope=1; else if(ea4-ea1>0.05*atr) slope=-1; }
   int dir=TrendTFs(sym,tf);
   return StringFormat("{\"tf\":\"%s\",\"tendencia\":%d,\"ema_inclinacao\":%d,\"ema50\":%s,\"atr\":%s,\"ok\":true}",
      nm,dir,slope,Fmt(ea1),Fmt(atr));
}
string VolJSON()
{
   int n=ArraySize(g_r);
   if(n<22) return "{\"ok\":false}";
   double sum=0; for(int k=1;k<=20 && k<n;k++) sum+=(double)g_r[k].tick_volume;
   double avg=sum/20.0, v=(double)g_r[0].tick_volume, raz=(avg>0?v/avg:0);
   return StringFormat("{\"atual\":%.0f,\"media20\":%.0f,\"razao\":%.2f,\"forte\":%s,\"ok\":true}",v,avg,raz,raz>=2.0?"true":"false");
}
string News2hJSON()
{
   if(!CalOn()) return "[]";
   LoadNews(); datetime now=TimeTradeServer(); string out=""; int c=0;
   for(int i=0;i<ArraySize(g_news) && c<12;i++)
   {
      int m=(int)((g_news[i].t-now)/60);
      if(m<-5 || m>120) continue;
      string nm=g_news[i].nome; StringReplace(nm,"\\",""); StringReplace(nm,"\"","'");
      out+=(out==""?"":",")+StringFormat("{\"hora_brasilia\":\"%s\",\"min\":%d,\"moeda\":\"%s\",\"impacto\":\"%s\",\"evento\":\"%s\"}",
         TimeToString(SrvParaBR(g_news[i].t),TIME_DATE|TIME_MINUTES),m,g_news[i].cur,ImpTxt(g_news[i].imp),nm);
      c++;
   }
   return "["+out+"]";
}
string NivelPorNome(string nome)
{
   for(int i=0;i<ArraySize(g_niv);i++)
      if(g_niv[i].nome==nome)
         return StringFormat("{\"nome\":\"%s\",\"preco\":%s,\"estado\":\"%s\"}",JEsc(g_niv[i].nome),Fmt(g_niv[i].preco),
            g_niv[i].estado==ST_VARRIDA?"varrida":(g_niv[i].estado==ST_ROMPIDO?"rompido":"intacto"));
   return "null";
}
string VarridasJSON()
{
   string out=""; int c=0;
   for(int i=0;i<ArraySize(g_niv) && c<8;i++)
   {
      if(g_niv[i].estado!=ST_VARRIDA) continue;
      out+=(out==""?"":",")+StringFormat("{\"nome\":\"%s\",\"preco\":%s,\"hora\":\"%s\"}",JEsc(g_niv[i].nome),Fmt(g_niv[i].preco),HHMM(g_niv[i].tSweep));
      c++;
   }
   return "["+out+"]";
}
string ChecklistJSON(const Plano &p)
{
   string nm[7]={"tendencia","varrida","bos","fvg","volume","horario","alvo2R"}; string z="";
   for(int i=0;i<7;i++) z+=(i?",":"")+"\""+nm[i]+"\":"+(p.pts[i]?"true":"false");
   return "{"+z+"}";
}
string MemJSON()
{
   MemLoad(); string out="";
   int n=ArraySize(g_mem), st=MathMax(0,n-16);
   for(int i=st;i<n;i++) out+=(out==""?"":",")+"\""+JEsc(g_mem[i])+"\"";
   return "["+out+"]";
}
bool ContextValido(string j)
{
   if(StringLen(j)<30) return false;
   int p=StringFind(j,"\"bid\":"); if(p<0) p=StringFind(j,"\"preco\":");
   if(p<0) return false;
   int k=StringFind(j,":",p); if(k<0) return false;
   double v=StringToDouble(StringSubstr(j,k+1,24));
   return v>0;
}
bool ParseCmd(string text,string &cmd,string &args)
{
   StringTrimLeft(text); StringTrimRight(text);
   cmd=""; args="";
   if(text=="") return false;
   int sp=StringFind(text," ");
   string head=sp>0?StringSubstr(text,0,sp):text;
   args=sp>0?StringSubstr(text,sp+1):"";
   StringTrimLeft(args); StringTrimRight(args);
   int at=StringFind(head,"@"); if(at>0) head=StringSubstr(head,0,at);
   cmd=head; StringToLower(cmd);
   return StringLen(cmd)>0 && StringGetCharacter(cmd,0)=='/';
}

string AlvosLadoJSON(int dir,const Plano &p)
{
   string alvos="["; int na=0;
   double risk=MathAbs(p.entry-p.stop), minRR=RRMinAlvo();
   for(int v=0;v<ArraySize(g_niv);v++)
   {
      if(g_niv[v].estado==ST_ROMPIDO) continue;
      double lv=g_niv[v].preco;
      bool ladoOk=(dir==1 && lv>p.entry) || (dir==-1 && lv<p.entry && p.entry>0) || (p.entry<=0 && ((dir==1 && g_niv[v].lado==NV_ABOVE)||(dir==-1 && g_niv[v].lado==NV_BELOW)));
      if(!ladoOk) continue;
      if(p.entry>0 && risk>0 && MathAbs(lv-p.entry)/risk+1e-12<minRR) continue;
      alvos+=(na?",":"")+StringFormat("{\"nome\":\"%s\",\"preco\":%s,\"estado\":%d}",JEsc(g_niv[v].nome),Fmt(lv),g_niv[v].estado);
      na++; if(na>=6) break;
   }
   alvos+="]";
   if(!PlanoValido(p))
      return StringFormat("{\"valido\":false,\"motivo\":\"%s\",\"alvos_liquidez\":%s}",JEsc(PlanoSemSetup(dir)),alvos);
   return StringFormat("{\"valido\":true,\"entrada\":%s,\"entrada_poi\":\"%s\",\"stop\":%s,\"alvo\":%s,\"alvo_nome\":\"%s\",\"rr\":%.2f,\"alvos_liquidez\":%s}",
      Fmt(p.entry),JEsc(p.entNome),Fmt(p.stop),Fmt(p.target),JEsc(p.alvoNome),p.rr,alvos);
}
string AlvosLocaisJSON()
{
   return "{\"aviso\":\"niveis locais, alvo minimo 1.5R\",\"compra\":"+AlvosLadoJSON(1,g_pb)+",\"venda\":"+AlvosLadoJSON(-1,g_ps)+"}";
}
string PlanoCtxJSON(const Plano &p)
{
   if(!PlanoValido(p))
      return StringFormat("{\"valido\":false,\"motivo\":\"%s\",\"entrada\":null,\"stop\":null,\"alvo\":null,\"rr\":0}",JEsc(PlanoSemSetup(p.dir)));
   return StringFormat("{\"valido\":true,\"entrada\":%s,\"stop\":%s,\"alvo\":%s,\"alvo_nome\":\"%s\",\"poi\":\"%s\",\"lote\":%.2f,\"risco_usd\":%.2f,\"rr\":%.2f}",
      Fmt(p.entry),Fmt(p.stop),Fmt(p.target),JEsc(p.alvoNome),JEsc(p.entNome),p.lot,p.riskUSD,p.rr);
}
string ContextJSON()
{
   Plano b=MelhorPlano();
   string j=StateJSON(b);
   j=StringSubstr(j,0,StringLen(j)-1);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0 || ask<=0) return "";
   string st; SessaoNota(TimeTradeServer(),st); if(MercadoFechado()) st="mercado fechado";
   j+=StringFormat(",\"bid\":%s,\"ask\":%s,\"preco\":%s,\"spread\":%s",Fmt(bid),Fmt(ask),Fmt(bid),Fmt(ask-bid));
   j+=",\"hora_brasilia\":\""+DiaHoraBR(AgoraBR(),true)+"\",\"mercado\":\""+JEsc(MercadoTxt())+"\"";
   j+=StringFormat(",\"sessao\":\"%s\",\"vies_dia\":\"%s\",\"tendencia_txt\":\"%s\"",JEsc(st),JEsc(g_biasTxt),JEsc(g_trendTxt));
   j+=",\"tendencias_detalhe\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+TfSnap(_Symbol,g_mtfTF[i]);
   j+="}";
   j+=",\"liquidez\":{\"PDH\":"+NivelPorNome("Máxima de ontem")+",\"PDL\":"+NivelPorNome("Mínima de ontem")+",\"asia_max\":"+NivelPorNome("Máxima da Ásia")+",\"asia_min\":"+NivelPorNome("Mínima da Ásia")+",\"londres_max\":"+NivelPorNome("Máxima de Londres")+",\"londres_min\":"+NivelPorNome("Mínima de Londres")+"}";
   j+=",\"varridas_recentes\":"+VarridasJSON();
   j+=StringFormat(",\"nota_compra\":%d,\"nota_venda\":%d,\"checklist_compra\":%s,\"checklist_venda\":%s",g_pb.score,g_ps.score,ChecklistJSON(g_pb),ChecklistJSON(g_ps));
   j+=",\"plano_compra\":"+PlanoCtxJSON(g_pb);
   j+=",\"plano_venda\":"+PlanoCtxJSON(g_ps);
   j+=",\"alvos_locais\":"+AlvosLocaisJSON();
   j+=",\"fvg_"+StringSubstr(EnumToString(InpTFExec),7)+"\":"+FVGJson(g_fvg,4)+",\"fvg_M15\":"+FVGJson(g_fvgM15,3)+",\"fvg_H1\":"+FVGJson(g_fvgH1,3);
   j+=",\"volume\":"+VolJSON();
   j+=",\"noticias_2h\":"+News2hJSON()+",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\"";
   j+=",\"posicoes_abertas\":"+PosJSON();
   j+=",\"conversa_recente\":"+MemJSON()+",\"fatos_do_vitor\":"+(g_tgEmGrupo?"[]":FatosJSON());
   j+=",\"historico_veredictos\":"+VereditoStatsJSON();
   j+=",\"motor\":"+EngineJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"},\"robo\":{\"opera\":%s,\"status\":\"%s\",\"pausa_dd\":%s,\"pausa_tg\":%s}}",
        g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare),TradeAtivo()?"true":"false",JEsc(g_status),g_ddPause?"true":"false",g_tradePausa?"true":"false");
   return j;
}
bool EhPedidoAnalise(string t)
{
   string u=t; StringToLower(u); u=AISemAcento(u);
   if(StringFind(u,"analis")>=0) return true;
   if(StringFind(u,"/plano")>=0) return true;
   if(StringFind(u,"qual o plano")>=0 || StringFind(u,"cade o plano")>=0 || StringFind(u,"me da o plano")>=0 || StringFind(u,"mostra o plano")>=0 || StringFind(u,"ver o plano")>=0) return true;
   { int pe=StringFind(u,"entro"); if(pe>=0 && (pe==0 || StringGetCharacter(u,pe-1)!='d')) return true; }
   if(StringFind(u,"entrar")>=0 || StringFind(u,"vale compr")>=0 || StringFind(u,"vale vend")>=0) return true;
   if(StringFind(u,"posso compr")>=0 || StringFind(u,"posso vend")>=0 || StringFind(u,"posso entr")>=0) return true;
   return false;
}
bool EhReclamaRepete(string t)
{
   string u=t; StringToLower(u); u=AISemAcento(u);
   if(StringFind(u,"repet")>=0) return true;
   if(StringFind(u,"mesmo bloco")>=0 || StringFind(u,"mesmo texto")>=0 || StringFind(u,"de novo o mesmo")>=0) return true;
   return false;
}
bool EhSoNoticia(string t)
{
   if(EhPedidoAnalise(t)) return false;
   string u=t; StringToLower(u); u=AISemAcento(u);
   return StringFind(u,"notic")>=0;
}
datetime g_edgeAvisado=0;
string AvisoEdgeLinha(){ return "No teste 2016-2025 os sinais automáticos nota>=7 não tiveram edge."; }
string SemAvisoEdge(string t)
{
   string ls[]; int n=StringSplit(t,'\n',ls); string o="";
   for(int i=0;i<n;i++)
   {
      string u=ls[i]; StringToLower(u); u=AISemAcento(u);
      if(StringFind(u,"2016-2025")>=0) continue;
      if(StringFind(u,"nao tiveram edge")>=0) continue;
      o+=(o==""?"":"\n")+ls[i];
   }
   return o;
}
string EdgeSePreciso(string t)
{
   t=SemAvisoEdge(t);
   if(g_edgeAvisado>0 && TimeCurrent()-g_edgeAvisado<3600) return t;
   g_edgeAvisado=TimeCurrent();
   return t+"\n\n"+AvisoEdgeLinha();
}
string SemCamposCrus(string t)
{
   StringReplace(t,"plano_compra:","Se for comprar:");
   StringReplace(t,"plano_venda:","Se for vender:");
   StringReplace(t,"alvos_locais:","Alvos no gráfico:");
   StringReplace(t,"plano_compra","plano de compra");
   StringReplace(t,"plano_venda","plano de venda");
   StringReplace(t,"alvos_locais","alvos no gráfico");
   return t;
}
bool TemBlocoRobo(string t)
{
   string u=t; StringToLower(u); u=AISemAcento(u);
   int hits=0;
   if(StringFind(u,"plano de compra")>=0 || StringFind(u,"se for comprar")>=0) hits++;
   if(StringFind(u,"plano de venda")>=0 || StringFind(u,"se for vender")>=0) hits++;
   if(StringFind(u,"o que fazer agora")>=0) hits++;
   if(StringFind(u,"alvos no grafico")>=0) hits++;
   return hits>=2;
}
bool LinhaDePlano(string linha)
{
   string u=linha; StringToLower(u); u=AISemAcento(u); StringToLower(u); StringTrimLeft(u);
   // tira emoji/marcadores do começo
   while(StringLen(u)>0){ ushort c=StringGetCharacter(u,0); if((c>='a'&&c<='z')||(c>='0'&&c<='9')) break; u=StringSubstr(u,1); }
   string k[]={"se for comprar","se for vender","plano de compra","plano de venda","o que fazer agora","alvos no grafico","cenario compra","cenario venda","compra:","venda:"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])==0) return true;
   return false;
}
// posição (no texto minúsculo) onde começa o bloco de plano; 0 = a resposta já começa com o plano
int CorteBloco(const string u)
{
   string k[]={"se for comprar","se for vender","plano de compra","plano de venda","o que fazer agora","alvos no grafico","macro ta "};
   int best=-1;
   for(int i=0;i<ArraySize(k);i++)
   {
      int p=StringFind(u,"\n"+k[i]);
      if(StringFind(u,k[i])==0) p=0;
      if(p>=0 && (best<0 || p<best)) best=p;
   }
   return best;
}
string SoRespostaCurta(string t,string pergunta="")
{
   t=SemAvisoEdge(t);
   t=SemCamposCrus(t);
   t=AISemVeredito(t);
   StringTrimLeft(t); StringTrimRight(t);
   bool soNot=EhSoNoticia(pergunta), rep=EhReclamaRepete(pergunta);
   bool cortar=TemBlocoRobo(t) || soNot || rep;
   if(!cortar) return t;
   // mantém as linhas de conversa; pula o plano do começo e para no primeiro bloco de plano depois
   string ls[]; int n=StringSplit(t,'\n',ls); string o=""; bool conteudo=false;
   for(int i=0;i<n;i++)
   {
      string x=ls[i]; string xt=x; StringTrimLeft(xt); StringTrimRight(xt);
      if(xt=="") continue;
      string ux=xt; StringToLower(ux); ux=AISemAcento(ux); StringToLower(ux);
      bool plano=LinhaDePlano(xt) || ((soNot||rep) && StringFind(ux,"macro")==0);
      if(plano){ if(conteudo) break; else continue; }
      o+=(o==""?"":"\n")+xt; conteudo=true;
   }
   if(o=="") o="Sem novidade além do plano. Se quiser ver, toca em 🧭 Plano.";
   return o;
}
string SysChatLivre()
{
   return "Você é o Alier, um colega de trading no Telegram. Português do Brasil, informal, frases curtas, gíria leve sem forçar. "
          "Responda SOMENTE o que foi perguntado, em 1 a 4 frases. Poucos emoji, só se couber. Sem markdown. "
          "Não monte plano, não liste compra e venda, não cite entrada/stop/alvo se não pediram, não feche com VEREDITO, não use cabeçalho. "
          "Nunca escreva nomes crus de campo (plano_compra, plano_venda, alvos_locais). Se um dia citar um setup, fale assim: 'Se for comprar: entra em X, stop Y, alvo Z (vale 2.2x o risco)'. "
          "Use SÓ os números do CONTEXTO; nunca invente preço, stop, alvo ou horário. Horários sempre em Brasília (bloco AGORA e hora_brasilia das notícias). "
          "A conversa recente já está no contexto: não repita o que você já disse. Se o Vitor reclamar de repetição, não peça desculpa e cole o mesmo bloco — mude o comportamento e responda só o que falta, de outro jeito, bem curto. "
          "Varie a abertura. Não comece com 'Fala mano' nem com 'ALIEN PROFESSOR:'. "
          "Nunca mencione o teste 2016-2025 nem diga que os sinais não tiveram edge neste tipo de resposta. "
          "Nunca prometa lucro."+RegraHoraMercado()+RegraContextoIA(true);
}
string SysChatAnalise()
{
   return "Você é o Alier, um colega de trading brasileiro (SMC/liquidez). Fale informal, frases curtas, gíria leve (mano, bora, segura a mão, preço tá esticado) sem forçar. Português do Brasil. "
          "Use SÓ os números do CONTEXTO; nunca invente preço, stop, alvo ou horário. Horários sempre em Brasília (bloco AGORA / hora_brasilia). Sem markdown. No máximo 900 caracteres. "
          "Não use rótulos robóticos nem nomes crus de campo (plano_compra, plano_venda, alvos_locais). "
          "Fale natural, tipo: 'Macro tá vendido (D1/H4/H1 pra baixo), M1 tentando subir.' "
          "Em seguida, em poucas linhas: se tem setup de compra, escreva 'Se for comprar: entra em X, stop Y, alvo Z (vale 2.2x o risco)'; se tem de venda, o mesmo; o que fazer agora; um risco (notícia, horário, spread). "
          "Alvo só vale com no mínimo 1,5R e do lado certo (compra: stop < entrada < alvo; venda: alvo < entrada < stop). Use os planos e alvos do contexto (campos internos, não imprima os nomes). Se não tiver alvo válido, diga que não tem setup naquele lado. "
          "Feche com uma linha VEREDITO: COMPRA ou VENDA ou ESPERAR (pode usar 🟢 🔴 🟡 junto, mas as palavras COMPRA/VENDA/ESPERAR têm que aparecer). Pode usar emoji úteis: 🟢 compra, 🔴 venda, 🟡 esperar, 💧 liquidez, ⚡ volume forte, 🎯 alvo, 🛑 stop, 📰 notícia. "
          "Varie a abertura. Não comece sempre com 'Fala mano'. Não repita a conversa recente. "
          "Nunca prometa lucro. Se faltar dado, ESPERAR. Não mencione o teste 2016-2025; isso é acrescentado à parte."+RegraHoraMercado()+RegraContextoIA(false);
}
string SysChat(){ return SysChatAnalise(); }
// ---- memória da conversa (últimas 10 mensagens) em MQL5\Files\ALIEN_chat_memoria.txt ----
string g_mem[];
// v12.4: memória separada por chat (privado do Vitor x grupo)
string MemArq(){ return g_tgEmGrupo?"ALIEN_chat_memoria_grupo.txt":"ALIEN_chat_memoria.txt"; }
void MemLoad()
{
   ArrayResize(g_mem,0);
   int h=FileOpen(MemArq(),FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ); if(h==INVALID_HANDLE) return;
   while(!FileIsEnding(h)){ string l=FileReadString(h); if(l=="") continue; int k=ArraySize(g_mem); ArrayResize(g_mem,k+1); g_mem[k]=l; }
   FileClose(h);
}
void MemAdd(string quem,string txt)
{
   MemLoad();
   StringReplace(txt,"\r",""); StringReplace(txt,"\n"," / "); if(StringLen(txt)>700) txt=StringSubstr(txt,0,700)+"...";
   int k=ArraySize(g_mem); ArrayResize(g_mem,k+1); g_mem[k]=TimeToString(AgoraBR(),TIME_DATE|TIME_MINUTES)+" "+quem+": "+txt;
   int st=MathMax(0,ArraySize(g_mem)-16);
   int h=FileOpen(MemArq(),FILE_WRITE|FILE_TXT|FILE_UNICODE); if(h==INVALID_HANDLE) return;
   for(int i=st;i<ArraySize(g_mem);i++) FileWriteString(h,g_mem[i]+"\r\n");
   FileClose(h);
}
// no grupo: sem os fatos pessoais do Vitor, e avisa quem está falando
string QuemMsg(){ return g_tgEmGrupo?"MENSAGEM DE "+g_tgQuem+" (no grupo do Telegram do Vitor)":"MENSAGEM DO VITOR"; }
string GrupoNota(){ return g_tgEmGrupo?" Você está no grupo do Telegram do Vitor; quem escreveu agora foi "+g_tgQuem+". Responda pra essa pessoa, curto. No grupo: não faça pergunta pessoal (trabalho, barbearia, família, vida) e não puxe assunto fora do tema; fique no que a pessoa perguntou, a não ser que ela mesma mude de assunto.":""; }
string MemTxt(){ MemLoad(); string fz=g_tgEmGrupo?"":FatosTxt(); if(ArraySize(g_mem)==0) return fz; string s=fz+"CONVERSA RECENTE (mais antiga primeiro):\n"; for(int i=0;i<ArraySize(g_mem);i++) s+=g_mem[i]+"\n"; return s+"\n"; }

// ---- /analise em qualquer símbolo e tempo gráfico ----
ENUM_TIMEFRAMES TfDe(string t)
{
   StringToUpper(t);
   if(t=="M1") return PERIOD_M1; if(t=="M5") return PERIOD_M5; if(t=="M15") return PERIOD_M15; if(t=="M30") return PERIOD_M30;
   if(t=="H1") return PERIOD_H1; if(t=="H4") return PERIOD_H4; if(t=="D1"||t=="DIARIO"||t=="DIÁRIO") return PERIOD_D1; if(t=="W1"||t=="SEMANAL") return PERIOD_W1;
   return PERIOD_CURRENT;
}
ENUM_TIMEFRAMES TfMaior(ENUM_TIMEFRAMES tf)
{
   switch(tf){ case PERIOD_M1: return PERIOD_M15; case PERIOD_M5: return PERIOD_H1; case PERIOD_M15: return PERIOD_H4; case PERIOD_M30: return PERIOD_H4;
               case PERIOD_H1: return PERIOD_D1; case PERIOD_H4: return PERIOD_D1; case PERIOD_D1: return PERIOD_W1; default: return PERIOD_MN1; }
}
string TfNome(ENUM_TIMEFRAMES tf){ return StringSubstr(EnumToString(tf),7); }
bool SymOk(string s){ bool cu=false; return s!="" && SymbolExist(s,cu); }
// no texto livre, não aceitar palavra comum (ex.: "vale comprar") só porque existe um ticker homônimo
bool PareceTicker(string u)
{
   int n=StringLen(u); if(n<3) return false;
   for(int i=0;i<n;i++){ ushort c=StringGetCharacter(u,i); if(c>='0' && c<='9') return true; }
   if(n>=6) return true;
   return StringFind(u,"USD")>=0 || StringFind(u,"EUR")>=0 || StringFind(u,"GBP")>=0 || StringFind(u,"JPY")>=0
       || StringFind(u,"XAU")>=0 || StringFind(u,"XAG")>=0 || StringFind(u,"BTC")>=0 || StringFind(u,"CASH")>=0;
}
bool TemCotacao(string sym)
{
   if(!SymOk(sym)) return false;
   SymbolSelect(sym,true);
   double bid=SymbolInfoDouble(sym,SYMBOL_BID);
   for(int i=0;i<8 && bid<=0;i++){ Sleep(100); bid=SymbolInfoDouble(sym,SYMBOL_BID); }
   if(bid<=0) return false;
   MqlRates r[]; return CopyRates(sym,PERIOD_D1,0,1,r)==1 || CopyRates(sym,PERIOD_M1,0,1,r)==1;
}
string SimboloDe(string t,bool busca)
{
   string u=t; StringToUpper(u); if(StringLen(u)<3) return "";
   bool alias=false;
   if(u=="OURO"||u=="GOLD"||u=="XAU") { u="XAUUSD"; alias=true; }
   if(u=="NASDAQ"||u=="NAS"||u=="NAS100"||u=="US100"||u=="USTEC") { u="USTECH"; alias=true; }
   if(u=="SP500"||u=="SP"||u=="S&P"||u=="SPX") { u="US500"; alias=true; }
   if(u=="DAX"||u=="GER40"||u=="ALEMANHA") { u="DE40"; alias=true; }
   if(!busca && !alias && !PareceTicker(u)) return "";
   string c[3]; c[0]=u; c[1]="."+u+"Cash"; c[2]=u+"Cash";
   for(int i=0;i<3;i++) if(SymOk(c[i])) return c[i];
   if(!busca || StringLen(u)<4) return "";
   for(int i=0;i<SymbolsTotal(false);i++){ string n=SymbolName(i,false), nu=n; StringToUpper(nu); if(StringFind(nu,u)>=0) return n; }
   return "";
}
// procura símbolo/TF no texto. busca=true só no /analise (procura parcial na lista)
bool ParseAlvo(string text,bool busca,string &sym,ENUM_TIMEFRAMES &tf)
{
   sym=""; tf=PERIOD_CURRENT;
   string t=text; string pn[]={"?","!",",",".",";",":","(",")","\"","'"}; for(int i=0;i<ArraySize(pn);i++) StringReplace(t,pn[i]," ");
   string w[]; int n=StringSplit(t,' ',w);
   for(int i=0;i<n;i++)
   {
      if(w[i]=="" || StringGetCharacter(w[i],0)=='/') continue;
      ENUM_TIMEFRAMES f=TfDe(w[i]); if(f!=PERIOD_CURRENT){ tf=f; continue; }
      if(sym==""){ string s=SimboloDe(w[i],busca); if(s!="") sym=s; }
   }
   return (sym!="" || tf!=PERIOD_CURRENT);
}
string FmtS(string sym,double p){ return DoubleToString(p,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)); }
// resumo de um TF: tendência, topos/fundos, BOS, FVGs abertos
string TfResumo(string sym,ENUM_TIMEFRAMES tf,double &sh0,double &sl0,FVGz &fv[])
{
   MqlRates r[]; ArraySetAsSeries(r,true); sh0=0; sl0=0; ArrayResize(fv,0);
   int n=CopyRates(sym,tf,0,300,r); if(n<60) return "{\"tf\":\""+TfNome(tf)+"\",\"erro\":\"sem dados\"}";
   double sh[2]={0,0}, sl[2]={0,0}; int a=0,b=0;
   for(int j=3;j<n-3 && (a<2||b<2);j++){ if(a<2&&IsSH(r,j,2)) sh[a++]=r[j].high; if(b<2&&IsSL(r,j,2)) sl[b++]=r[j].low; }
   sh0=sh[0]; sl0=sl[0];
   string bos="nenhum"; if(sh[0]>0 && r[1].close>sh[0]) bos="rompeu o topo "+FmtS(sym,sh[0])+" (alta)"; else if(sl[0]>0 && r[1].close<sl[0]) bos="rompeu o fundo "+FmtS(sym,sl[0])+" (baixa)";
   ScanFVG(r,tf,150,fv);
   string fs=""; int k=0;
   for(int i=ArraySize(fv)-1;i>=0 && k<4;i--){ if(fv[i].filled) continue; fs+=(fs==""?"":",")+StringFormat("{\"dir\":\"%s\",\"topo\":%s,\"fundo\":%s}",fv[i].dir==1?"alta":"baixa",FmtS(sym,fv[i].top),FmtS(sym,fv[i].bot)); k++; }
   string vel=""; for(int i=3;i>=1;i--) vel+=(i<3?",":"")+StringFormat("[%s,%s,%s,%s]",FmtS(sym,r[i].open),FmtS(sym,r[i].high),FmtS(sym,r[i].low),FmtS(sym,r[i].close));
   int tr=TrendTFs(sym,tf);
   return StringFormat("{\"tf\":\"%s\",\"tendencia\":%d,\"atr\":%s,\"topos\":[%s,%s],\"fundos\":[%s,%s],\"bos\":\"%s\",\"fvg_abertos\":[%s],\"ultimas_3_velas_OHLC\":[%s]}",
      TfNome(tf),tr,FmtS(sym,ATRof(r,14,1)),FmtS(sym,sh[0]),FmtS(sym,sh[1]),FmtS(sym,sl[0]),FmtS(sym,sl[1]),bos,fs,vel);
}
double g_fHi=0,g_fLo=0; FVGz g_fFvg[];
string TFContextJSON(string sym,ENUM_TIMEFRAMES tf)
{
   SymbolSelect(sym,true);
   double bid=SymbolInfoDouble(sym,SYMBOL_BID), ask=SymbolInfoDouble(sym,SYMBOL_ASK);
   string j="{\"simbolo\":\""+sym+"\",\"tf_foco\":\""+TfNome(tf)+"\",\"hora_brasilia\":\""+DiaHoraBR(AgoraBR(),true)+"\",\"mercado\":\""+JEsc(MercadoTxt(sym))+"\",\"preco\":"+FmtS(sym,bid)+",\"spread\":"+FmtS(sym,ask-bid)+",\"tendencias\":{";
   for(int i=0;i<6;i++) j+=(i?",":"")+"\""+g_mtfNm[i]+"\":"+IntegerToString(TrendTFs(sym,g_mtfTF[i]));
   double h2,l2; FVGz f2[];
   j+="},\"foco\":"+TfResumo(sym,tf,g_fHi,g_fLo,g_fFvg)+",\"tf_maior\":"+TfResumo(sym,TfMaior(tf),h2,l2,f2);
   double pdh=iHigh(sym,PERIOD_D1,1), pdl=iLow(sym,PERIOD_D1,1), pwh=iHigh(sym,PERIOD_W1,1), pwl=iLow(sym,PERIOD_W1,1);
   j+=",\"PDH\":"+FmtS(sym,pdh)+",\"PDL\":"+FmtS(sym,pdl)+",\"semana_passada_max\":"+FmtS(sym,pwh)+",\"semana_passada_min\":"+FmtS(sym,pwl);
   j+=",\"bloqueio_noticia\":\""+JEsc(NoticiaAviso(TimeTradeServer()))+"\",\"posicoes_abertas\":"+PosJSON();
   j+=StringFormat(",\"hoje\":{\"trades\":%d,\"stops\":%d,\"resultado_usd\":%.2f,\"pare\":\"%s\"}",g_tradesHoje,g_stopsHoje,g_netHoje,JEsc(g_pare));
   if(sym==_Symbol) j+=",\"professor_do_grafico\":"+ContextJSON();
   return j+"}";
}
// print de qualquer símbolo/TF: abre um gráfico temporário, desenha níveis e FVGs, tira o print e fecha
bool FotoTF(string sym,ENUM_TIMEFRAMES tf,string caption)
{
   if(!InpTgFoto || !TgOk()) return false;
   SymbolSelect(sym,true);
   long id=ChartOpen(sym,tf); if(id==0){ Print("Telegram: não abri gráfico ",sym," ",TfNome(tf)); return false; }
   ChartSetInteger(id,CHART_COLOR_BACKGROUND,clrBlack); ChartSetInteger(id,CHART_COLOR_FOREGROUND,clrGold); ChartSetInteger(id,CHART_SHOW_GRID,false);
   ChartSetInteger(id,CHART_COLOR_CANDLE_BULL,clrGold); ChartSetInteger(id,CHART_COLOR_CHART_UP,clrGold); ChartSetInteger(id,CHART_COLOR_CANDLE_BEAR,C'60,60,60');
   ChartSetInteger(id,CHART_COLOR_CHART_DOWN,clrSilver); ChartSetInteger(id,CHART_MODE,CHART_CANDLES); ChartSetInteger(id,CHART_SHIFT,true); ChartSetInteger(id,CHART_AUTOSCROLL,true); ChartSetInteger(id,CHART_SCALE,3);
   for(int i=0;i<25 && Bars(sym,tf)<100;i++) Sleep(200);
   datetime t0=iTime(sym,tf,120), t1=iTime(sym,tf,0)+PeriodSeconds(tf)*10;
   double lv[4]; string ln[4]={"PDH","PDL","topo","fundo"}; color lc[4]={clrDodgerBlue,clrDodgerBlue,clrGold,clrGold};
   lv[0]=iHigh(sym,PERIOD_D1,1); lv[1]=iLow(sym,PERIOD_D1,1); lv[2]=g_fHi; lv[3]=g_fLo;
   for(int i=0;i<4;i++){ if(lv[i]<=0) continue; string o="AP_T_L"+IntegerToString(i); ObjectCreate(id,o,OBJ_TREND,0,t0,lv[i],t1,lv[i]); ObjectSetInteger(id,o,OBJPROP_COLOR,lc[i]); ObjectSetInteger(id,o,OBJPROP_STYLE,STYLE_DASH); ObjectSetString(id,o,OBJPROP_TEXT,ln[i]);
      string ot="AP_T_T"+IntegerToString(i); ObjectCreate(id,ot,OBJ_TEXT,0,t1,lv[i]); ObjectSetString(id,ot,OBJPROP_TEXT,ln[i]+" "+FmtS(sym,lv[i])); ObjectSetInteger(id,ot,OBJPROP_COLOR,lc[i]); ObjectSetInteger(id,ot,OBJPROP_FONTSIZE,9); }
   int k=0;
   for(int i=ArraySize(g_fFvg)-1;i>=0 && k<4;i--){ if(g_fFvg[i].filled) continue; string o="AP_T_F"+IntegerToString(k++); ObjectCreate(id,o,OBJ_RECTANGLE,0,g_fFvg[i].t0,g_fFvg[i].top,t1,g_fFvg[i].bot); ObjectSetInteger(id,o,OBJPROP_COLOR,g_fFvg[i].dir==1?C'0,90,60':C'110,30,30'); ObjectSetInteger(id,o,OBJPROP_FILL,true); ObjectSetInteger(id,o,OBJPROP_BACK,true); }
   string tt="AP_T_TIT"; ObjectCreate(id,tt,OBJ_LABEL,0,0,0); ObjectSetInteger(id,tt,OBJPROP_XDISTANCE,10); ObjectSetInteger(id,tt,OBJPROP_YDISTANCE,10); ObjectSetString(id,tt,OBJPROP_TEXT,"ALIEN PROFESSOR  "+sym+"  "+TfNome(tf)); ObjectSetInteger(id,tt,OBJPROP_COLOR,clrGold); ObjectSetInteger(id,tt,OBJPROP_FONTSIZE,14);
   ChartRedraw(id); Sleep(1500); ChartRedraw(id);
   string f="APROF_tf_"+IntegerToString(GetTickCount())+".png";
   bool ok=ChartScreenShot(id,f,1600,900,ALIGN_RIGHT);
   ChartClose(id);
   if(!ok){ Print("Telegram: print do ",sym," ",TfNome(tf)," falhou"); return false; }
   ok=SendPhoto(f,caption); FileDelete(f); return ok;
}
bool EhMercado(string t)
{
   string u=t; StringToLower(u);
   string k[]={"compr","vend","entr","oper","trade","mercado","ouro","gold","xau","nasdaq","us500","dax","índice","indice","liquidez","fvg","bos","stop","alvo","tendên","tendenc","sinal","long","short","sell","buy","gráfico","grafico","preço","preco","notícia","noticia","analis","análise","agora","topo","fundo","varr","abertura","reabr","fechament","gap","agenda","calend","payroll","fomc","juros","dolar","dólar","dxy","killzone","sessão","sessao","spread","vwap","posição","posicao","saldo"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true;
   return false;
}
// v12.4: pediu gráfico/print? (com mercado fechado só mando print se pedir)
bool PedeGrafico(string t)
{
   string u=AISemAcento(t); StringToLower(u);
   string k[]={"grafico","print","foto","imagem","chart","tela","screenshot","mostra o"};
   for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true;
   return false;
}
bool FotoDepoisDaResposta(string pergunta,bool explicito,string sym)
{
   if(!MercadoFechado(sym)) return true;
   return explicito || PedeGrafico(pergunta);
}
bool TgFoto(string caption)
{
   if(!InpTgFoto || !TgOk()) return false;
   string f="APROF_chat_"+_Symbol+".png"; ChartRedraw(0);
   if(!ChartScreenShot(0,f,1600,900,ALIGN_RIGHT)){ Print("Telegram: não consegui tirar o print"); return false; }
   return SendPhoto(f,caption);
}
void ChatIA(string pergunta,string titulo,string sym="",ENUM_TIMEFRAMES tf=PERIOD_CURRENT,bool exigirAlvo=false,bool forcarPlano=false)
{
   bool plano = forcarPlano || EhPedidoAnalise(pergunta);
   bool mercado = (plano || sym!="" || tf!=PERIOD_CURRENT || EhMercado(pergunta));
   bool soNoticia=EhSoNoticia(pergunta);
   // assunto que não é mercado: conversa geral (qualquer tema), sem o contexto do gráfico
   if(!mercado && AIOn()){ ChatGeral(pergunta); return; }
   if(sym=="" && tf!=PERIOD_CURRENT) sym=_Symbol;
   if(sym!="" && tf==PERIOD_CURRENT) tf=InpTFExec;
   // texto livre: sempre o contexto cheio do gráfico. só troca/acrescenta foco se o alvo tiver cotação.
   string ctx=ContextJSON();
   bool fotoAlvo=false;
   if(sym!="")
   {
      if(!TemCotacao(sym))
      {
         Print("Telegram: sem cotação de ",sym," - uso o contexto de ",_Symbol);
         if(exigirAlvo){ SendMsg("Não achei cotação de "+sym+" "+TfNome(tf)+". Confere o nome no Market Watch e tenta de novo."); return; }
         sym=""; tf=PERIOD_CURRENT;
      }
      else
      {
         string foco=TFContextJSON(sym,tf);
         if(sym==_Symbol) ctx=foco;             // já inclui professor_do_grafico
         else ctx="{\"professor_do_grafico\":"+ctx+",\"foco\":"+foco+"}";
         fotoAlvo=true;
      }
   }
   if(!ContextValido(ctx))
   {
      SendMsg("Agora não veio cotação do gráfico. Abre o "+_Symbol+" e manda de novo.");
      return;
   }
   if(!AIOn())
   {
      if(!plano)
      {
         if(soNoticia){ SendMsg(NoticiasTxt()); return; }
         SendMsg("A IA tá desligada agora (falta chave ou WebRequest). Se quiser a leitura do gráfico, manda /analise ou /plano. Notícias: /noticias.");
         return;
      }
      Plano b=MelhorPlano();
      SendMsg("A IA tá desligada agora (falta chave ou WebRequest). Segue a leitura do gráfico:\n"+EdgeSePreciso(Narrativa(b,g_pare!=""||NoticiaAviso(TimeTradeServer())!="",NoticiaAviso(TimeTradeServer()))));
      if(FotoDepoisDaResposta(pergunta,forcarPlano,sym)){ if(fotoAlvo) FotoTF(sym,tf,sym+" "+TfNome(tf)); else TgFoto(FotoLegenda()); }
      return;
   }
   int w=AIEsperaSeg(); if(w>0){ SendMsg(StringFormat("Calma, a IA tá no limite. Tenta de novo em %d s.",w)); return; }
   string sys=(plano?SysChatAnalise():SysChatLivre()+AcoesSysTxt())+GrupoNota();
   if(EhReclamaRepete(pergunta)) sys+=" O Vitor reclamou que você está repetindo. NÃO peça desculpa e cole o mesmo texto. Responda só o que falta, de outro jeito, bem curto.";
   bool abert=EhPerguntaAbertura(pergunta) || MercadoFechado();
   int tok=plano?600:(EhPerguntaAbertura(pergunta)?480:350);
   double temp=plano?0.2:0.6;
   string r=AIAskEx(sys,MemTxt()+CtxIA(pergunta,true,abert)+"CONTEXTO DO MERCADO (JSON):\n"+ctx+"\n\n"+QuemMsg()+":\n"+pergunta,tok,false,plano,temp);
   if(r==""){ SendMsg(AIFalhaTxt()); return; }
   r=SemCamposCrus(r);
   string acNm[],acPr[],acLimpo; bool temAcao=false;
   if(plano){ AcoesExtrai(r,acNm,acPr,acLimpo); r=EdgeSePreciso(acLimpo); }
   else { temAcao=(StringFind(r,"[ACAO:")>=0); if(temAcao){ r=AcoesProcessa(r); } else r=SoRespostaCurta(r,pergunta); }
   if(plano && StringLen(r)>900)
   {
      string tail="";
      int pv=StringFind(r,"VEREDITO"); if(pv>=0) tail=StringSubstr(r,pv);
      int keep=900-StringLen(tail)-5; if(keep<350) keep=350;
      r=StringSubstr(r,0,keep)+"\n...\n"+tail;
   }
   if(plano) VereditoLog("chat");
   if(!g_tgEmGrupo) FatoTalvez(pergunta);
   MemAdd(g_tgQuem,pergunta); MemAdd("Alier",r);
   if((sym=="" || sym==_Symbol) && plano) AIPanelSet(r);
   if((sym=="" || sym==_Symbol) && (plano || (mercado && !soNoticia))) ObsSet(r,plano?"🎯":"💬");
   string msg=r;
   if(titulo!="") msg=titulo+"\n"+r;
   if(plano) msg+="\n\n(opinião — quem decide é você)";
   SendMsg(msg);
   if((plano || (mercado && !soNoticia && !EhReclamaRepete(pergunta))) && FotoDepoisDaResposta(pergunta,forcarPlano,sym))
   {
      if(sym!="") FotoTF(sym,tf,sym+" "+TfNome(tf)+" às "+TimeToString(AgoraBR(),TIME_MINUTES)+" (Brasília)");
      else TgFoto(FotoLegenda());
   }
}
#ifndef APROF_VER
#define APROF_VER "1.00"
#endif
string RoboIdent()
{
   string tf=StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7);
   string nome=MQLInfoString(MQL_PROGRAM_NAME);
   if(nome=="") nome="ALIEN_PROFESSOR_AUTO";
   return StringFormat("%s v%s | %s %s | magic %I64d",nome,APROF_VER,_Symbol,tf,InpMagic);
}
string StatusTxt()
{
   string s="👽 Alier versão "+APROF_VER+", ligado às "+g_ligadoBR+" (Brasília).\n"+StringFormat("Status do %s.\nTá %s, conta %s.\nRobô: %s\n",_Symbol,TradeAtivo()?"operando":(g_tradePausa?"pausado (/pausa)":"no modo assistente (não opera)"),
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"DEMO":"REAL",RoboIdent());
   s+=StringFormat("Saldo $%.2f, equity $%.2f.\n",AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   s+=StringFormat("Hoje: %d trades, %d stops (máx %d), resultado $%+.2f (meta $%.0f / perda máx $%.0f).\n",g_tradesHoje,g_stopsHoje,InpMaxStopsDia,g_netHoje,InpMetaDiaUSD,InpPerdaMaxDiaUSD);
   s+="Disciplina: "+(g_pare!=""?g_pare:"tranquilo, pode operar")+(g_ddPause?" | pausei pelo DD":"")+"\n";
   string nw=NoticiaAviso(TimeTradeServer()); if(nw!="") s+=nw+"\n";
   int np=0; string ps="";
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue; np++;
      ps+=StringFormat("  %s %s %.2f lote @%s  P/L $%+.2f%s\n",PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"compra":"venda",
          PositionGetDouble(POSITION_VOLUME),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),(int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL),SYMBOL_DIGITS)),
          PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP),PositionGetInteger(POSITION_MAGIC)==InpMagic?" (robô)":" (manual)");
   }
   s+=(np==0?"Nenhuma posição aberta.\n":("Posição aberta:\n"+ps));
   Plano b=MelhorPlano();
   s+=StringFormat("Nota do momento: %s %d/10 (do outro lado %d/10).\n",b.dir==1?"🟢 COMPRA":"🔴 VENDA",b.score,b.dir==1?g_ps.score:g_pb.score);
   LoadHist(); int n; double w,a; HStat("",0,"",n,w,a);
   s+=StringFormat("No histórico (%s): %d trades, acerto %.0f%%, R médio %+.2f.\n",_Symbol,n,w,a);
   string fx[4]={"0-4","5-6","7-8","9-10"};
   for(int f=0;f<4;f++){ int nn; double ww,aa; HStat(fx[f],0,"",nn,ww,aa); if(nn>0) s+=StringFormat("  nota %s: %d trades, acerto %.0f%%, R %+.2f\n",fx[f],nn,ww,aa); }
   s+="Trava do histórico: "+(InpAprenderDesativar?"ligada":"desligada")+".";
   s+="\nAutônomo: "+(AutonomoAtivo()?"LIGADO (demo)":(g_cfgAutonomo&&!ContaDemo()?"bloqueado (conta REAL)":"desligado"))+". Ordens pelo Telegram: "+g_cfgTgOrdens+(g_modoLimpo?". Modo limpo ligado":"")+".";
   return s;
}
string NoticiasTxt()
{
   LoadNews(true);
   string sem=""; if(CalOn()){ AgendaCarrega(); if(g_agIA!="") sem="\n\n🗓️ Próximos 7 dias (as mais importantes):\n"+g_agIA; StringTrimRight(sem); }
   return "📰 Notícias na frente ("+InpCalMoedas+", horário de Brasília; 🔴 forte, 🟡 média):\n"+NewsListaBR(10,"\n")+sem+
          (InpCalBloquearForte?StringFormat("\n\nEm notícia forte eu não entro %d min antes e depois.",InpNoticiaMin):"");
}
string AjudaTxt()
{
   return "Oi! Eu sou o Alier 👽 (versão "+APROF_VER+", "+_Symbol+").\n"
          "Os botões aqui embaixo fazem o principal. Também entendo:\n"
          "/analise [símbolo] [tempo] - eu olho o gráfico com a IA e mando o print\n"
          "/plano - compra e venda como estão agora\n"
          "/niveis - máxima e mínima de ontem, Ásia, Londres e varridas\n"
          "/diario - o que rolou hoje, em português\n"
          "/aprendizado - como as leituras e a sua disciplina estão indo\n"
          "/alerta <preço> - te aviso quando o preço passar\n"
          "/pausa e /retoma - paro ou volto a mandar ordem (eu confirmo antes)\n"
          "/risco - limites de agora (eu não mudo nada sozinho)\n"
          "/status - versão, posição, resultado do dia\n"
          "/noticias - próximas notícias (Brasília)  |  /agenda - só as de hoje\n"
          "/foto - print com uma explicação curtinha\n"
          "/memoria - o que eu lembro de você  |  /esquece - apago\n"
          "/grupo - (no grupo, só o Vitor) libera o grupo pra falar comigo\n"
          "🆕 /explica - o que é cada linha do gráfico | /aula fvg | /guia - legenda\n"
          "🆕 /trades - seus trades de hoje e o porquê | /podes - tudo que eu sei fazer\n"
          "🆕 Me dá ordens com suas palavras: \"me avisa em 3900\", \"modo limpo\", \"não me deixa operar na Ásia\", \"me lembra 10:30\"\n"
          "🆕 Ordem (só você, com Confirmar): \"compra 0.05 stop 3880 alvo 3900\", \"fecha metade\", \"stop no zero\"\n"
          "🆕 /autonomo on|off - eu opero sozinho na DEMO e aprendo | /aprendizado | /reset_aprendizado\n"
          "Pode escrever sobre qualquer assunto, mandar áudio 🎤 ou foto 📷 (até print de gráfico de outro lugar). Eu também te aviso sozinho quando varrer liquidez, mudar a estrutura ou chegar num bloco importante.";
}
void TgHandle(string chat,string text)
{
   StringTrimLeft(text); StringTrimRight(text); if(text=="") return;
   string cmd,args; bool iscmd=ParseCmd(text,cmd,args);
   if(g_cfgTgChat=="")
   {
      if(cmd=="/start" && !g_tgEmGrupo)
      {
         // grava o chat id sozinho no ALIEN_config.txt: não precisa configurar nada
         CfgSalva("telegram_chat_id",chat); g_cfgTgChat=chat; g_tgHint="";
         Print("ALIEN: chat id salvo em MQL5\\Files\\ALIEN_config.txt");
         SendMsgKb("Pronto, te conectei 👽 Agora eu só respondo este chat. Manda /ajuda ou usa os botões.");
      }
      return;
   }
   if(!ChatAutorizado(chat)){ Print("Telegram: ignorei mensagem de um chat não autorizado (",chat,")"); return; }
   if(!iscmd){ string bc=BotaoCmd(text); if(bc!=""){ cmd=bc; args=""; iscmd=true; } }
   Print("Telegram: comando ",cmd!=""?cmd:"(texto livre)",g_tgEmGrupo?" (grupo)":"");
   if(!iscmd && !g_tgEmGrupo && DisciplinaMotivo(text)) return;
   // v12.6: o que muda estado no robô = só o dono (privado ou o from.id do Vitor no grupo)
   if(!TgDono() && (cmd=="/pausa"||cmd=="/retoma"||cmd=="/pausa_ok"||cmd=="/retoma_ok"||cmd=="/esquece"||(cmd=="/alerta" && args!="")||cmd=="/linha"||cmd=="/limpo"||cmd=="/painel"||cmd=="/regra"||cmd=="/lembrete"||cmd=="/mudo"||cmd=="/som"||cmd=="/nota"||cmd=="/simbolo"||cmd=="/símbolo"||cmd=="/disc"))
   { SendMsg(NaoDono()); return; }
   if(iscmd && OrdensCmd(cmd,args)) return;
   if(iscmd && AcoesCmd(cmd,args)) return;
   if(cmd=="/grupo"){ SendMsg(g_tgEmGrupo?"Este grupo já tá liberado ✅ Me chama com /comando, marcando @"+BotUser()+" ou respondendo uma mensagem minha.":"Pra liberar um grupo: me adiciona nele e manda /grupo lá dentro (só você, Vitor)."); return; }
   if(cmd=="/start" || cmd=="/ajuda" || cmd=="/help"){ SendMsgKb(AjudaTxt()); return; }
   if(cmd=="/status"){ SendMsg(StatusTxt()); return; }
   if(cmd=="/noticias" || cmd=="/notícias"){ SendMsg(NoticiasTxt()); return; }
   if(cmd=="/foto"){ if(!TgFoto(FotoLegenda())) SendMsg("Não rolou o print agora."); return; }
   if(cmd=="/agenda"){ SendMsg(AgendaTxt()); return; }
   if(cmd=="/memoria" || cmd=="/memória"){ SendMsg(MemoriaTxt()); return; }
   if(cmd=="/esquece"){ MemoriaApaga(); SendMsg("Pronto, apaguei o que eu lembrava. Começo do zero 🙂"); return; }
   if(cmd=="/disc"){ DisciplinaResposta(args); return; }
   if(cmd=="/cancela"){ SendMsg("Beleza, deixei como estava."); return; }
   if(cmd=="/plano"){ SendMsg(EdgeSePreciso(PlanoTxt())); return; }
   if(cmd=="/niveis" || cmd=="/níveis"){ SendMsg(NiveisTxt()); return; }
   if(cmd=="/diario" || cmd=="/diário"){ SendMsg(DiarioTxt()); return; }
   if(cmd=="/aprendizado"){ SendMsg(AprendizadoTxt()+"\n\n"+AdaptTabelaTxt()); return; }
   if(cmd=="/risco"){ SendMsg(RiscoTxt()); return; }
   if(cmd=="/pausa"){ PedeConfirmaPausa(true); return; }
   if(cmd=="/retoma"){ PedeConfirmaPausa(false); return; }
   if(cmd=="/pausa_ok"){ g_tradePausa=true; PausaSave(); SendMsg("Pausei as ordens. Os avisos continuam aqui. Quando quiser voltar, manda /retoma."); return; }
   if(cmd=="/retoma_ok"){ g_tradePausa=false; PausaSave(); SendMsg(InpTradeEnabled?"Fechei a pausa. Tô operando de novo, dentro dos limites.":"O InpTradeEnabled tá false (modo assistente). /retoma não liga a operação sozinho — muda isso no MT5 se quiser que eu opere."); return; }
   if(cmd=="/alerta")
   {
      double px=StringToDouble(args);
      if(px<=0) SendMsg("Manda assim: /alerta 3870  (preço maior que zero). Alertas ativos: "+AlertaLista());
      else { AlertaAdd(px); UsuarioDesenha(); SendMsg("Beleza, alerta em "+Fmt(px)+" salvo. Ativos: "+AlertaLista()); }
      return;
   }
   if(cmd=="/analise" || cmd=="/análise")
   {
      string asy; ENUM_TIMEFRAMES atf;
      if(args!="" && ParseAlvo(args,true,asy,atf))
      {
         if(asy=="") asy=_Symbol; if(atf==PERIOD_CURRENT) atf=InpTFExec;
         SendMsg("Deixa eu olhar o "+asy+" "+TfNome(atf)+"...");
         ChatIA("Olha o "+asy+" no "+TfNome(atf)+" com os números do contexto, no seu estilo informal, e fecha com VEREDITO.","ANÁLISE "+asy+" "+TfNome(atf),asy,atf,true,true);
         return;
      }
      if(args!=""){ SendMsg("Não achei esse símbolo/tempo. Exemplos: /analise H4  |  /analise XAUUSD M15  |  /analise US500 H1"); return; }
      if(g_simFoco!="" && TemCotacao(g_simFoco)){ SendMsg("Deixa eu olhar o "+g_simFoco+"..."); ChatIA("Olha o "+g_simFoco+" no "+TfNome(InpTFExec)+" com os números do contexto, no seu estilo informal, e fecha com VEREDITO.","ANÁLISE "+g_simFoco,g_simFoco,InpTFExec,true,true); return; }
      SendMsg("Deixa eu olhar o "+_Symbol+"..."); ChatIA("Olha o gráfico de agora com os números do contexto, no seu estilo informal, e fecha com VEREDITO.","ANÁLISE "+_Symbol,"",PERIOD_CURRENT,false,true); return;
   }
   if(iscmd){ SendMsg("Não peguei esse comando.\n\n"+AjudaTxt()); return; }
   // v12.6: pedidos em texto livre que o robô resolve sem IA
   if(EhPedidoExplica(text)){ MemAdd(g_tgQuem,text); ExplicaEnvia(); return; }
   if(EhPedidoTrades(text)){ MemAdd(g_tgQuem,text); TradesEnvia(true); return; }
   if(EhPedidoPodes(text)){ MemAdd(g_tgQuem,text); SendMsg(PodesTxt()); return; }
   { OrdemPend op; if(OrdemDeTexto(text,op) && op.tipo>0){ MemAdd(g_tgQuem,text); if(!TgDono()){ SendMsg("Ordem só o Vitor pode mandar 🙏"); return; } OrdemPropoe(op); return; } }
   if(EhSoNoticia(text)){ MemAdd(g_tgQuem,text); SendMsg(NoticiasTxt()); return; }
   string fsy; ENUM_TIMEFRAMES ftf;
   if(ParseAlvo(text,false,fsy,ftf)) ChatIA(text,"",fsy,ftf);
   else ChatIA(text,"");
}
// ---- v12.4: grupo do Telegram ----
bool ChatAutorizado(string chat){ return chat!="" && (chat==g_cfgTgChat || (g_cfgGrupo!="" && chat==g_cfgGrupo)); }
string g_botUser=""; datetime g_botUserTent=0;
string BotId(){ int k=StringFind(g_cfgTgToken,":"); return k>0?StringSubstr(g_cfgTgToken,0,k):""; }
string BotUser()
{
   if(g_botUser!="") return g_botUser;
   if(TgTokenOk() && TimeLocal()-g_botUserTent>600)
   {
      g_botUserTent=TimeLocal();
      char data[],res[]; string rh;
      int code=WebRequest("GET","https://api.telegram.org/bot"+g_cfgTgToken+"/getMe","",5000,data,res,rh);
      if(code==200){ string u=JStrKey(CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8),"username"); if(u!="") g_botUser=u; }
   }
   if(g_botUser=="") return "Alierprofessorbot";
   return g_botUser;
}
// tira um objeto JSON "chave":{...} do texto (ex.: reply_to_message), devolve o objeto em obj
string JCorta(string r,string key,string &obj)
{
   obj=""; int k=StringFind(r,"\""+key+"\":{"); if(k<0) return r;
   int a=StringFind(r,"{",k); int n=StringLen(r), dep=0; bool str=false; int e=-1;
   for(int i=a;i<n;i++)
   {
      ushort c=StringGetCharacter(r,i);
      if(str){ if(c=='\\') i++; else if(c=='"') str=false; continue; }
      if(c=='"') str=true; else if(c=='{') dep++; else if(c=='}'){ dep--; if(dep==0){ e=i; break; } }
   }
   if(e<0) return r;
   obj=StringSubstr(r,a,e-a+1);
   return StringSubstr(r,0,k)+StringSubstr(r,e+1);
}
// tira a menção @bot do texto (sem ligar pra maiúscula)
string SemMencao(string t,string user)
{
   string tl=t, at="@"+user; StringToLower(tl); StringToLower(at);
   int k=StringFind(tl,at); if(k<0) return t;
   string o=StringSubstr(t,0,k)+StringSubstr(t,k+StringLen(at)); StringTrimLeft(o); StringTrimRight(o);
   return o;
}
bool TemMencao(string t,string user){ string tl=t, at="@"+user; StringToLower(tl); StringToLower(at); return StringFind(tl,at)>=0; }
// comando de grupo endereçado a OUTRO bot (/status@OutroBot) -> não é pra mim
bool CmdDeOutroBot(string t,string user)
{
   if(StringLen(t)<2 || StringGetCharacter(t,0)!='/') return false;
   int sp=StringFind(t," "); string head=sp>0?StringSubstr(t,0,sp):t;
   int at=StringFind(head,"@"); if(at<0) return false;
   string suf=StringSubstr(head,at+1), u=user; StringToLower(suf); StringToLower(u);
   return suf!=u;
}
void TgContexto(string chat,bool grupo,string quem,string fromId=""){ g_tgReply=chat; g_tgEmGrupo=grupo; g_tgFromId=fromId; g_tgQuem=grupo?(quem!=""?quem:"alguém do grupo"):"Vitor"; }
void TgContextoLimpa(){ g_tgReply=""; g_tgEmGrupo=false; g_tgFromId=""; g_tgQuem="Vitor"; }
// renova a trava de quem lê o chat durante respostas demoradas (IA), pra outro gráfico não pegar a vez
void TgMasterRenova(){ if(g_tgMaster && GlobalVariableCheck("APROF_TGM_ID") && GlobalVariableGet("APROF_TGM_ID")==g_inst) GlobalVariableSet("APROF_TGM_T",(double)TimeLocal()); }
// offset mais novo gravado por qualquer gráfico (evita responder duas vezes a mesma mensagem)
void TgOffSincroniza(){ string s=ArqLe(g_tgEstArq); if(s=="") return; string l[]; if(StringSplit(s,'\n',l)>0){ long o=StringToInteger(l[0]); if(o>g_tgOff) g_tgOff=o; } }
void TgPoll()
{
   if(!TgTokenOk() || !InpTgChat) return;
   g_tgMaster=TgMaster(); if(!g_tgMaster) return;
   TgOffSincroniza();
   string url="https://api.telegram.org/bot"+g_cfgTgToken+"/getUpdates?timeout=0&limit=20&offset="+IntegerToString(g_tgOff);
   char data[],res[]; string rh; ResetLastError();
   int code=WebRequest("GET",url,"",5000,data,res,rh);
   if(code==-1){ if(g_tgErrPrint++%60==0) Print("Telegram: WebRequest bloqueado (erro ",GetLastError(),"). Adicione https://api.telegram.org em Ferramentas > Opções > Expert Advisors."); return; }
   string r=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   if(code!=200){ if(g_tgErrPrint++%60==0) Print("Telegram getUpdates respondeu ",code,code==409?" (o bot tem webhook ou outro programa lendo - só um pode ler)":(code==401?" (token inválido - crie um novo no @BotFather)":""),": ",StringSubstr(r,0,200)); return; }
   int pos=0; bool mudou=false;
   while(true)
   {
      int k=StringFind(r,"\"update_id\":",pos); if(k<0) break;
      int nx=StringFind(r,"\"update_id\":",k+12);
      string seg= nx>0 ? StringSubstr(r,k,nx-k) : StringSubstr(r,k);
      long uid=StringToInteger(JNumKey(seg,"update_id"));
      pos= nx>0 ? nx : StringLen(r);
      if(uid<g_tgOff) continue;                               // já atendida (por este ou outro gráfico)
      g_tgOff=uid+1; mudou=true;
      // a mensagem respondida vem junto: tira pra não ler o texto/foto dela no lugar da nova
      string rep; seg=JCorta(seg,"reply_to_message",rep);
      int cpos=StringFind(seg,"\"chat\":"); if(cpos<0) continue;
      string chat=JNumKey(seg,"id",cpos);
      string tipo=JStrKey(StringSubstr(seg,cpos),"type");
      bool grupo=(tipo=="group" || tipo=="supergroup");
      int fpos=StringFind(seg,"\"from\":");
      string fromId= fpos>=0 ? JNumKey(seg,"id",fpos) : "";
      string quem= fpos>=0 ? JStrKey(StringSubstr(seg,fpos),"first_name") : "";
      int rf=StringFind(rep,"\"from\":");
      bool aoBot=(rf>=0 && BotId()!="" && JNumKey(rep,"id",rf)==BotId());
      // grupo virou supergrupo: o número muda
      if(grupo && g_cfgGrupo!="" && chat==g_cfgGrupo && StringFind(seg,"\"migrate_to_chat_id\":")>=0)
      {
         string nid=JNumKey(seg,"migrate_to_chat_id");
         if(nid!=""){ g_cfgGrupo=nid; CfgSalva("telegram_grupo_id",nid); Print("ALIEN: grupo migrou, número novo salvo"); }
         continue;
      }
      string text="";
      bool cb=StringFind(seg,"\"callback_query\"")>=0;
      if(cb)
      {
         // botão apertado: vale mesmo se a mensagem do botão for antiga
         text=JStrKey(seg,"data");
         TgAckCb(JStrKey(seg,"id"));
      }
      else
      {
         long dt=StringToInteger(JNumKey(seg,"date"));
         if(dt>0 && dt<(long)g_tgStartUtc-120) continue;     // mensagem velha (antes do robô ligar)
         if(grupo && !ChatAutorizado(chat))
         {
            // /grupo do Vitor (dono) libera este grupo
            string t0=JStrKey(seg,"text"); string c0,a0;
            if(ParseCmd(t0,c0,a0) && c0=="/grupo" && !CmdDeOutroBot(t0,BotUser()) && g_cfgTgChat!="" && fromId==g_cfgTgChat)
            {
               g_cfgGrupo=chat; CfgSalva("telegram_grupo_id",chat);
               Print("ALIEN: grupo liberado e salvo em MQL5\\Files\\ALIEN_config.txt");
               if(mudou) TgEstadoSave(); mudou=false;
               TgContexto(chat,true,quem,fromId);
               SendMsg("Pronto, liberei este grupo ✅ Aqui eu respondo comandos (/status, /analise...), quando me marcam (@"+BotUser()+") ou quando respondem uma mensagem minha. Os avisos automáticos continuam só no privado do Vitor.");
               TgContextoLimpa();
            }
            continue;
         }
         int fp=StringFind(seg,"\"photo\":[");
         int vp=StringFind(seg,"\"voice\":{");
         string cap=JStrKey(seg,"caption");
         if(grupo && (fp>=0 || vp>=0) && !aoBot && !TemMencao(cap,BotUser())) continue;   // foto/áudio do grupo só se for pra mim
         if(fp>=0)
         {
            // a última versão da foto é a maior
            string ph=StringSubstr(seg,fp); int fe=StringFind(ph,"]"); if(fe>0) ph=StringSubstr(ph,0,fe);
            string fid=""; int q=0; while(true){ int z=StringFind(ph,"\"file_id\":\"",q); if(z<0) break; fid=JDecode(ph,z+10); q=z+1; }
            if(ChatAutorizado(chat) && fid!=""){ if(mudou) TgEstadoSave(); mudou=false; TgContexto(chat,grupo,quem,fromId); FotoHandle(chat,fid,SemMencao(cap,BotUser())); TgContextoLimpa(); TgMasterRenova(); }
            continue;
         }
         if(vp>=0)
         {
            string fid=JStrKey(StringSubstr(seg,vp),"file_id");
            if(ChatAutorizado(chat) && fid!=""){ if(mudou) TgEstadoSave(); mudou=false; TgContexto(chat,grupo,quem,fromId); VozHandle(chat,fid); TgContextoLimpa(); TgMasterRenova(); }
            continue;
         }
         text=JStrKey(seg,"text");
         if(grupo)
         {
            // no grupo: só comando pra mim, menção @bot ou resposta a uma mensagem minha
            if(CmdDeOutroBot(text,BotUser())) continue;
            bool ehCmd=StringLen(text)>0 && StringGetCharacter(text,0)=='/';
            bool men=TemMencao(text,BotUser());
            if(!ehCmd && !men && !aoBot) continue;
            if(men) text=SemMencao(text,BotUser());
            if(text=="") text="oi";
         }
      }
      if(chat!="" && text!=""){ if(mudou) TgEstadoSave(); mudou=false; TgContexto(chat,grupo,quem,fromId); TgHandle(chat,text); TgContextoLimpa(); TgMasterRenova(); }
   }
   if(mudou) TgEstadoSave();
}
// pré-aviso de notícia FORTE (só a instância que lê o chat, pra não repetir)
void TgPreAlerta()
{
   if(!TgOk() || InpPreAlertaMin<=0 || !CalOn()) return;
   if(InpTgChat && !g_tgMaster) return;
   LoadNews(); datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_news);i++)
   {
      if(g_news[i].imp<3 || StringFind(InpPreAlertaMoedas,g_news[i].cur)<0 || AlertaMudo("noticia")) continue;
      long d=(long)(g_news[i].t-now); if(d<=0 || d>InpPreAlertaMin*60) continue;
      string key="|"+IntegerToString((long)g_news[i].id)+"|"; if(StringFind(g_alertados,key)>=0) continue;
      g_alertados+=IntegerToString((long)g_news[i].id)+"|"; TgEstadoSave();
      ObsSet(StringFormat("📰 Notícia forte de %s às %s (Brasília): %s. Cuidado com a volatilidade.",g_news[i].cur,HHMMBR(g_news[i].t),g_news[i].nome),"📰");
      SendMsg(StringFormat("📰 Atenção: notícia forte de %s daqui a %d min (às %s, Brasília): %s.%s",g_news[i].cur,(int)(d/60)+1,HHMMBR(g_news[i].t),g_news[i].nome,
              InpCalBloquearForte?StringFormat(" Eu não entro %d min antes/depois. Segura a mão nas posições.",InpNoticiaMin):""));
   }
}
// resumo automático na abertura de Londres / NY
int HHMMtoMin(string s){ string p[]; if(StringSplit(s,':',p)<2) return -1; return (int)StringToInteger(p[0])*60+(int)StringToInteger(p[1]); }
void TgResumos()
{
   if(!TgOk() || !InpResumos) return;
   datetime now=TimeTradeServer(); MqlDateTime d; TimeToStruct(now,d);
   if(d.day_of_week==0 || d.day_of_week==6) return;      // fim de semana
   string nomes[2]={"LONDRES","NOVA YORK"}; string hs[2]; hs[0]=InpResumoLondres; hs[1]=InpResumoNY;
   for(int i=0;i<2;i++)
   {
      int m=HHMMtoMin(hs[i]); if(m<0) continue;
      int dm=MinOfDay(now)-m; if(dm<0 || dm>10) continue;
      string key=TimeToString(now,TIME_DATE)+_Symbol+nomes[i]+"|"; if(StringFind(g_resFeitos,key)>=0) continue;
      g_resFeitos+=key; TgEstadoSave();
      Plano b=MelhorPlano();
      string r="";
      string ctx=ContextJSON();
      if(AIOn() && ContextValido(ctx)) r=AIAskEx(SysChatAnalise(),CtxIA("",true,false)+"CONTEXTO:\n"+ctx+"\n\nMENSAGEM: resumo informal da abertura de "+nomes[i]+", fecha com VEREDITO.",600,true,true,0.2);
      if(r=="") r=Narrativa(b,g_pare!="",NoticiaAviso(now))+"\nNotícias (Brasília): "+NewsListaBR(4," | ");
      else { r=SemAvisoEdge(SemCamposCrus(r)); AIPanelSet(r); ObsSet(r,"🕗"); VereditoLog("resumo"); }
      SendMsg("Abertura de "+nomes[i]+" no "+_Symbol+"\n"+r);
      TgFoto(FotoLegenda());
   }
}
