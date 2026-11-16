
//====================================================================
// v12.6 — Alier que EXPLICA e que FAZ (lista fechada de ações seguras)
//  /explica  /aula <tema>  /guia  /podes  /trades  /alertas  /linha  /limpo  /painel
//  /regra  /lembrete  /mudo  /som  /nota  /simbolo  /print
//  A IA pode pedir uma ação com a etiqueta [ACAO:nome|param|param]. Só roda o que está na lista.
//  Mudar algo = só o Vitor (privado, ou o from.id dele no grupo). Ordem = sempre com Confirmar.
//====================================================================
string g_prefArq="ALIEN_prefs.txt", g_regrasArq="ALIEN_regras.txt", g_lembArq="ALIEN_lembretes.txt", g_linhasArq="ALIEN_linhas.txt";
string g_mudos="|";                   // tipos de aviso silenciados: |varrida|bos|...
int    g_notaAlerta=0;                // 0 = padrão (InpScoreTrade)
string g_simFoco="";                  // símbolo padrão do /analise

bool TgDono(){ if(!g_tgEmGrupo) return true; return g_tgFromId!="" && g_tgFromId==g_cfgTgChat; }
string Baixo(string t){ string u=AISemAcento(t); StringToLower(u); return u; }
string NaoDono(){ return "Isso muda coisa no robô, então só o Vitor pode pedir 🙏 Mas pode perguntar o que quiser."; }

// ---------------- política das ações (espelhada em teste/check_mocks.py) ----------------
// 0 = pode, 1 = não existe na lista, 2 = só o dono, 3 = ordem (só dono e sempre com Confirmar)
int AcaoPolitica(string nome,bool dono)
{
   string n=nome; StringToLower(n); StringTrimLeft(n); StringTrimRight(n);
   string ler[]={"alertas","regras","explica","aula","guia","trades","podes","print","lembretes","aprendizado"};
   string mud[]={"alerta","alerta_remove","linha","linha_remove","limpo","painel","nota_alerta","mudo","som","pausa","retoma","regra","regra_remove","lembrete","simbolo","balao"};
   string ord[]={"ordem","fechar","stop","alvo"};
   for(int i=0;i<ArraySize(ler);i++) if(n==ler[i]) return 0;
   for(int i=0;i<ArraySize(mud);i++) if(n==mud[i]) return dono?0:2;
   for(int i=0;i<ArraySize(ord);i++) if(n==ord[i]) return dono?3:2;
   return 1;
}
// tira as etiquetas [ACAO:...] do texto; devolve quantas achou (máx. 3)
int AcoesExtrai(string txt,string &nomes[],string &params[],string &limpo)
{
   ArrayResize(nomes,0); ArrayResize(params,0); limpo=txt;
   int n=0;
   while(true)
   {
      int a=StringFind(limpo,"[ACAO:"); if(a<0) a=StringFind(limpo,"[AÇÃO:"); if(a<0) break;
      int pre=(StringSubstr(limpo,a,6)=="[ACAO:")?6:6;
      int b=StringFind(limpo,"]",a); if(b<0){ limpo=StringSubstr(limpo,0,a); break; }
      string corpo=StringSubstr(limpo,a+pre,b-a-pre);
      limpo=StringSubstr(limpo,0,a)+StringSubstr(limpo,b+1);
      if(n>=3) continue;
      string nm=corpo, pr=""; int k=StringFind(corpo,"|"); if(k>=0){ nm=StringSubstr(corpo,0,k); pr=StringSubstr(corpo,k+1); }
      StringTrimLeft(nm); StringTrimRight(nm); StringToLower(nm);
      ArrayResize(nomes,n+1); ArrayResize(params,n+1); nomes[n]=nm; params[n]=pr; n++;
   }
   StringTrimLeft(limpo); StringTrimRight(limpo);
   return n;
}
// executa as etiquetas da resposta da IA; devolve o texto limpo + o que foi feito
string AcoesProcessa(string r)
{
   string nm[],pr[],limpo; int n=AcoesExtrai(r,nm,pr,limpo);
   if(n==0) return r;
   string feito="";
   for(int i=0;i<n;i++)
   {
      string res=AcaoExecuta(nm[i],pr[i]);
      if(res!="") feito+=(feito==""?"":"\n")+res;
   }
   return limpo+(feito!=""?"\n\n"+feito:"");
}
string AcaoP(string params,int i){ string p[]; int n=StringSplit(params,'|',p); if(i>=n) return ""; string v=p[i]; StringTrimLeft(v); StringTrimRight(v); return v; }
double NumDe(string s){ StringReplace(s,",","."); StringTrimLeft(s); StringTrimRight(s); return StringToDouble(s); }
string AcaoExecuta(string nome,string params)
{
   int pol=AcaoPolitica(nome,TgDono());
   Print("ALIEN ação pedida: ",nome," -> ",pol==0?"ok":(pol==1?"recusada (fora da lista)":(pol==2?"recusada (não é o dono)":"ordem com confirmação")));
   CsvAppend("ALIEN_acoes_log.csv","hora_brasilia;quem;acao;params;resultado",StringFormat("%s;%s;%s;%s;%d",TimeToString(AgoraBR(),TIME_DATE|TIME_MINUTES),CsvLimpo(g_tgQuem),CsvLimpo(nome),CsvLimpo(params),pol));
   if(pol==1) return "🤷 Isso eu não sei fazer. Manda /podes pra ver a lista.";
   if(pol==2) return NaoDono();
   if(pol==3) return OrdemDeAcao(nome,params);
   if(nome=="alerta"){ double px=NumDe(AcaoP(params,0)); if(px<=0) return "Faltou o preço do alerta."; AlertaAdd(px); UsuarioDesenha(); return "🔔 Alerta em "+Fmt(px)+" salvo (te aviso aqui e marquei uma linha pontilhada)."; }
   if(nome=="alerta_remove"){ string a=AcaoP(params,0); int k=AlertaRemove(Baixo(a)=="todos"||a==""?0:NumDe(a)); UsuarioDesenha(); return k>0?StringFormat("🗑️ Tirei %d alerta(s).",k):"Não achei esse alerta. Ativos: "+AlertaLista(); }
   if(nome=="alertas") return "🔔 Alertas ativos: "+AlertaLista();
   if(nome=="linha"){ double px=NumDe(AcaoP(params,0)); if(px<=0) return "Faltou o preço da linha."; string t=AcaoP(params,1); LinhaAdd(px,t); UsuarioDesenha(); return "📏 Linha em "+Fmt(px)+(t!=""?" ("+t+")":"")+" desenhada."; }
   if(nome=="linha_remove"){ string a=AcaoP(params,0); int k=LinhaRemove(Baixo(a)=="todas"||a==""?0:NumDe(a)); UsuarioDesenha(); return k>0?StringFormat("🧽 Tirei %d linha(s).",k):"Não achei essa linha."; }
   if(nome=="limpo"){ string a=Baixo(AcaoP(params,0)); g_modoLimpo=!(a=="off"||a=="nao"||a=="desliga"||a=="0"); PrefSalva(); RotulosArruma(); ChartRedraw(0);
      return g_modoLimpo?"🧹 Modo limpo ligado: deixei só os níveis principais, o plano e as suas linhas.":"Modo limpo desligado: voltei todas as marcas."; }
   if(nome=="painel") return PainelBloco(AcaoP(params,0),AcaoP(params,1));
   if(nome=="balao"){ string a=Baixo(AcaoP(params,0)); bool on=!(a=="off"||a=="nao"||a=="desliga"||a=="0"); if(!on){ g_obsTxt=""; ObsApaga(); } return on?"O balão volta na próxima observação da IA.":"Tirei o balão da IA do gráfico."; }
   if(nome=="nota_alerta"){ int v=(int)NumDe(AcaoP(params,0)); if(v<0||v>10) return "A nota vai de 0 a 10."; g_notaAlerta=v; PrefSalva(); return v==0?"Voltei a nota dos avisos pro padrão ("+IntegerToString(MathMax(InpScoreTrade,NotaForte()))+").":StringFormat("Beleza: só te aviso de setup com nota %d ou mais.",v); }
   if(nome=="mudo" || nome=="som") return MudoMuda(AcaoP(params,0),nome=="mudo");
   if(nome=="pausa"){ PedeConfirmaPausa(true); return ""; }
   if(nome=="retoma"){ PedeConfirmaPausa(false); return ""; }
   if(nome=="regra"){ string t=AcaoP(params,0); if(StringLen(t)<4) return "Faltou a regra."; RegraAdd(t); return "📌 Regra anotada: \""+t+"\". Se você abrir trade contra ela, eu aviso na hora."; }
   if(nome=="regra_remove"){ string a=AcaoP(params,0); int k=RegraRemove(Baixo(a)=="todas"||a==""?0:(int)NumDe(a)); return k>0?StringFormat("Tirei %d regra(s).",k):"Não achei essa regra. "+RegrasTxt(); }
   if(nome=="regras") return RegrasTxt();
   if(nome=="lembrete") return LembreteAdd(AcaoP(params,0),AcaoP(params,1));
   if(nome=="lembretes") return LembretesTxt();
   if(nome=="simbolo"){ string s=SimboloDe(AcaoP(params,0),true); if(s==""||!TemCotacao(s)) return "Não achei cotação desse símbolo no seu MT5."; g_simFoco=(s==_Symbol?"":s); PrefSalva(); return "🔎 Pronto: o /analise agora olha o "+s+" por padrão."; }
   if(nome=="print"){ string s=AcaoP(params,0), t=AcaoP(params,1); string sy=s==""?_Symbol:SimboloDe(s,true); ENUM_TIMEFRAMES tf=TfDe(t); if(sy=="") sy=_Symbol; if(tf==PERIOD_CURRENT) tf=(ENUM_TIMEFRAMES)_Period;
      if(sy==_Symbol && tf==(ENUM_TIMEFRAMES)_Period){ TgFoto(FotoLegenda()); return ""; } if(!TemCotacao(sy)) return "Sem cotação de "+sy+"."; FotoTF(sy,tf,sy+" "+TfNome(tf)); return ""; }
   if(nome=="explica"){ ExplicaEnvia(); return ""; }
   if(nome=="aula") return AulaTxt(AcaoP(params,0));
   if(nome=="guia") return GuiaTxt();
   if(nome=="trades"){ TradesEnvia(false); return ""; }
   if(nome=="podes") return PodesTxt();
   if(nome=="aprendizado") return AdaptTabelaTxt();
   return "";
}
// texto que vai pra IA (só no privado ou pro dono): o que ela pode pedir
string AcoesSysTxt()
{
   if(!TgDono()) return " Quem escreveu não é o Vitor: não use etiquetas [ACAO:...] que mudam coisas; só explique.";
   return " AÇÕES: se a pessoa PEDIR pra você fazer algo, coloque no fim da resposta UMA etiqueta por ação, exatamente assim: [ACAO:nome|param|param]. "
          "Lista fechada (nada fora dela): alerta|preço ; alerta_remove|preço ou todos ; alertas ; linha|preço|texto ; linha_remove|preço ou todas ; limpo|on ou off ; "
          "painel|ia,niveis,confluencia,conta,tudo ou mini|on ou off ; balao|on ou off ; nota_alerta|0-10 ; mudo|varrida,bos,choch,bloco,vwap,setup,noticia ou todos ; som|tipo ; "
          "pausa ; retoma ; regra|texto da regra ; regra_remove|número ou todas ; regras ; lembrete|HH:MM|texto ; lembretes ; simbolo|SÍMBOLO ; print|SÍMBOLO|TF ; "
          "explica ; aula|tema ; guia ; trades ; podes ; aprendizado ; ordem|compra ou venda|lote|stop|alvo ; fechar|tudo, metade ou SÍMBOLO ; stop|zero ou preço ; alvo|preço. "
          "Ordem, fechar, stop e alvo NUNCA executam direto: o robô mostra um resumo e o Vitor aperta Confirmar. Use preço só do contexto ou o que ele falou. "
          "Diga em uma frase o que vai fazer. Se não estiver na lista, explique o que dá pra fazer.";
}
// ---------------- preferências persistidas ----------------
void PrefSalva()
{
   string s=StringFormat("limpo=%d\r\npn_ia=%d\r\npn_niv=%d\r\npn_conf=%d\r\npn_conta=%d\r\npn_oculto=%d\r\nnota_alerta=%d\r\nmudos=%s\r\nsimbolo=%s\r\n",
      g_modoLimpo,g_pnIA,g_pnNiv,g_pnConf,g_pnConta,g_pnOculto,g_notaAlerta,g_mudos,g_simFoco);
   ArqGrava(g_prefArq,s);
}
void PrefLoad()
{
   string s=ArqLe(g_prefArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l);
   for(int i=0;i<n;i++)
   {
      string x=l[i]; StringReplace(x,"\r",""); int e=StringFind(x,"="); if(e<=0) continue;
      string k=StringSubstr(x,0,e), v=StringSubstr(x,e+1); bool b=(v=="1"||v=="true");
      if(k=="limpo") g_modoLimpo=b; else if(k=="pn_ia") g_pnIA=b; else if(k=="pn_niv") g_pnNiv=b; else if(k=="pn_conf") g_pnConf=b;
      else if(k=="pn_conta") g_pnConta=b; else if(k=="pn_oculto") g_pnOculto=b; else if(k=="nota_alerta") g_notaAlerta=(int)StringToInteger(v);
      else if(k=="mudos") g_mudos=(v==""?"|":v); else if(k=="simbolo") g_simFoco=v;
   }
}
string PainelBloco(string bloco,string onoff)
{
   string b=Baixo(bloco), o=Baixo(onoff); bool on=!(o=="off"||o=="nao"||o=="esconde"||o=="0"||o=="desliga");
   if(b=="mini"){ g_painelMin=on; g_pnOculto=false; }
   else if(b=="tudo"||b=="painel"){ g_pnOculto=!on; if(on){ g_pnIA=g_pnNiv=g_pnConf=g_pnConta=true; g_painelMin=false; } }
   else if(StringFind(b,"ia")==0) g_pnIA=on;
   else if(StringFind(b,"niv")==0) g_pnNiv=on;
   else if(StringFind(b,"conf")==0) g_pnConf=on;
   else if(StringFind(b,"conta")==0||StringFind(b,"hoje")==0||StringFind(b,"disc")==0) g_pnConta=on;
   else return "Os blocos do painel são: ia, niveis, confluencia, conta, tudo ou mini.";
   PrefSalva(); Painel(); ChartRedraw(0);
   return "🧩 Painel: "+bloco+(on?" aparecendo.":" escondido.");
}
// ---------------- avisos silenciados ----------------
bool AlertaMudo(string tipo){ return StringFind(g_mudos,"|todos|")>=0 || StringFind(g_mudos,"|"+tipo+"|")>=0; }
string MudoMuda(string tipo,bool mudo)
{
   string t=Baixo(tipo); StringTrimLeft(t); StringTrimRight(t);
   if(t=="noticias"||t=="noticia") t="noticia"; if(t=="varridas") t="varrida"; if(t=="blocos") t="bloco";
   string ok[]={"varrida","bos","choch","bloco","vwap","setup","noticia","todos"}; bool val=false;
   for(int i=0;i<ArraySize(ok);i++) if(t==ok[i]) val=true;
   if(!val) return "Tipos de aviso: varrida, bos, choch, bloco, vwap, setup, noticia ou todos.";
   if(t=="todos" && !mudo) g_mudos="|";
   else if(mudo){ if(StringFind(g_mudos,"|"+t+"|")<0) g_mudos+=t+"|"; }
   else StringReplace(g_mudos,"|"+t+"|","|");
   PrefSalva();
   return mudo?"🔕 Silenciei os avisos de "+t+".":"🔔 Voltei os avisos de "+t+".";
}
int NotaAlertaMin(){ return g_notaAlerta>0?g_notaAlerta:MathMax(InpScoreTrade,NotaForte()); }   // v12.7: padrão 9 (você muda com /nota)
// ---------------- alertas: remover + linha no gráfico ----------------
int AlertaRemove(double preco)
{
   int h=FileOpen(g_alertaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ); if(h==INVALID_HANDLE) return 0;
   string keep="preco;ativo\r\n"; int k=0; if(!FileIsEnding(h)) FileReadString(h);
   while(!FileIsEnding(h))
   {
      string l=FileReadString(h); if(l=="") continue; string p[]; if(StringSplit(l,';',p)<2){ continue; }
      if(p[1]=="1" && (preco<=0 || MathAbs(StringToDouble(p[0])-preco)<MathMax(_Point,0.0001)*5)){ k++; continue; }
      keep+=l+"\r\n";
   }
   FileClose(h);
   int w=FileOpen(g_alertaArq,FILE_WRITE|FILE_TXT|FILE_ANSI); if(w!=INVALID_HANDLE){ FileWriteString(w,keep); FileClose(w); }
   return k;
}
void LinhaAdd(double px,string t){ CsvLimpo(t); ArqGrava(g_linhasArq,ArqLe(g_linhasArq)+_Symbol+";"+DoubleToString(px,_Digits)+";"+CsvLimpo(t)+"\n"); }
int LinhaRemove(double px)
{
   string s=ArqLe(g_linhasArq), l[], o=""; int n=StringSplit(s,'\n',l), k=0;
   for(int i=0;i<n;i++){ string p[]; if(StringSplit(l[i],';',p)<2) continue; if(p[0]==_Symbol && (px<=0 || MathAbs(StringToDouble(p[1])-px)<_Point*5)){ k++; continue; } o+=l[i]+"\n"; }
   ArqGrava(g_linhasArq,o); return k;
}
void UsuarioDesenha()
{
   DelPrefix("USR");
   if(g_noDraw) return;
   datetime tR=TimeCurrent()+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3;
   string s=ArqLe(g_linhasArq), l[]; int n=StringSplit(s,'\n',l), j=0;
   for(int i=0;i<n;i++)
   {
      string p[]; if(StringSplit(l[i],';',p)<2 || p[0]!=_Symbol) continue;
      double px=StringToDouble(p[1]); if(px<=0) continue; string t=ArraySize(p)>2?p[2]:"";
      ObjHLinha("USR_L"+IntegerToString(j),px,clrDeepSkyBlue,STYLE_SOLID,t);
      ObjTxtGraf("USR_Lt"+IntegerToString(j),tR,px,"📏 "+(t!=""?t+" ":"")+Fmt(px),clrDeepSkyBlue,8,ANCHOR_LEFT_LOWER); j++;
   }
   int h=FileOpen(g_alertaArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h!=INVALID_HANDLE)
   {
      if(!FileIsEnding(h)) FileReadString(h); int a=0;
      while(!FileIsEnding(h)){ string x=FileReadString(h); string p[]; if(StringSplit(x,';',p)<2 || p[1]!="1") continue; double px=StringToDouble(p[0]); if(px<=0) continue;
         ObjHLinha("USR_A"+IntegerToString(a),px,clrOrange,STYLE_DOT,"alerta"); ObjTxtGraf("USR_At"+IntegerToString(a),tR,px,"🔔 alerta "+Fmt(px),clrOrange,8,ANCHOR_LEFT_UPPER); a++; }
      FileClose(h);
   }
   ChartRedraw(0);
}
// ---------------- regras pessoais (disciplina) ----------------
void RegraAdd(string t){ ArqGrava(g_regrasArq,ArqLe(g_regrasArq)+CsvLimpo(t)+"\n"); }
void RegrasLe(string &r[]){ ArrayResize(r,0); string l[]; int n=StringSplit(ArqLe(g_regrasArq),'\n',l); for(int i=0;i<n;i++){ string x=l[i]; StringReplace(x,"\r",""); StringTrimLeft(x); StringTrimRight(x); if(x=="") continue; int k=ArraySize(r); ArrayResize(r,k+1); r[k]=x; } }
int RegraRemove(int idx){ string r[]; RegrasLe(r); int n=ArraySize(r); if(n==0) return 0; string o=""; int k=0; for(int i=0;i<n;i++){ if(idx<=0 || i==idx-1){ k++; continue; } o+=r[i]+"\n"; } ArqGrava(g_regrasArq,o); return k; }
string RegrasTxt(){ string r[]; RegrasLe(r); if(ArraySize(r)==0) return "Você ainda não me deu nenhuma regra. Ex.: \"não me deixa operar na Ásia\"."; string s="📌 Suas regras:\n"; for(int i=0;i<ArraySize(r);i++) s+=IntegerToString(i+1)+". "+r[i]+"\n"; return s; }
// devolve a regra quebrada agora (ou ""). volume = lote do trade (0 se não souber)
string RegraQuebrada(double volume)
{
   string r[]; RegrasLe(r); if(ArraySize(r)==0) return "";
   datetime now=TimeTradeServer(); if(now==0) now=TimeCurrent();
   int h=HourOf(now); MqlDateTime b; TimeToStruct(AgoraBR(),b);
   for(int i=0;i<ArraySize(r);i++)
   {
      string u=Baixo(r[i]);
      if(StringFind(u,"asia")>=0 && h>=InpAsiaIni && h<InpAsiaFim) return r[i]+" (agora é sessão da Ásia)";
      if(StringFind(u,"domingo")>=0 && b.day_of_week==0) return r[i]+" (hoje é domingo)";
      if(StringFind(u,"noticia")>=0 && NoticiaAviso(now)!="") return r[i]+" ("+NoticiaAviso(now)+")";
      if(StringFind(u,"stop")>=0){ int p=StringFind(u,"stop"); int nn=0; for(int q=p-1;q>=0 && q>=p-4;q--){ ushort c=StringGetCharacter(u,q); if(c>='1'&&c<='9'){ nn=c-'0'; break; } } if(nn>0 && g_stopsHoje>=nn) return r[i]+StringFormat(" (já são %d stops hoje)",g_stopsHoje); }
      int pa=StringFind(u,"antes das "); if(pa>=0){ int hh=(int)StringToInteger(StringSubstr(u,pa+10,2)); if(hh>0 && b.hour<hh) return r[i]+StringFormat(" (agora são %02d:%02d em Brasília)",b.hour,b.min); }
      int pd=StringFind(u,"depois das "); if(pd>=0){ int hh=(int)StringToInteger(StringSubstr(u,pd+11,2)); if(hh>0 && b.hour>=hh) return r[i]+StringFormat(" (agora são %02d:%02d em Brasília)",b.hour,b.min); }
      int pl=StringFind(u,"lote"); if(pl>=0 && volume>0){ string resto=StringSubstr(u,pl+4); StringReplace(resto,",","."); double mx=0; string w[]; int nw=StringSplit(resto,' ',w); for(int q=0;q<nw;q++){ double v=StringToDouble(w[q]); if(v>0){ mx=v; break; } } if(mx>0 && volume>mx+1e-9) return r[i]+StringFormat(" (lote %.2f)",volume); }
   }
   return "";
}
// ---------------- lembretes ----------------
string LembreteAdd(string hhmm,string txt)
{
   int m=HHMMtoMin(hhmm); if(m<0||m>=1440) return "Manda a hora assim: 14:30.";
   datetime br=AgoraBR(); datetime d0=br-(br%86400); datetime alvo=d0+m*60; if(alvo<=br) alvo+=86400;
   if(StringLen(txt)<2) txt="lembrete";
   ArqGrava(g_lembArq,ArqLe(g_lembArq)+IntegerToString((long)alvo)+";"+CsvLimpo(txt)+"\n");
   return "⏰ Fechado: te lembro "+DiaHoraBR(alvo,false,true)+" (Brasília): "+txt;
}
string LembretesTxt(){ string l[]; int n=StringSplit(ArqLe(g_lembArq),'\n',l); string s=""; for(int i=0;i<n;i++){ string p[]; if(StringSplit(l[i],';',p)<2) continue; s+="⏰ "+DiaHoraBR((datetime)StringToInteger(p[0]),false,true)+" - "+p[1]+"\n"; } return s==""?"Nenhum lembrete marcado.":s; }
void LembretesTimer()
{
   if(!TgOk() || (TgChatOn() && !g_tgMaster)) return;
   string s=ArqLe(g_lembArq); if(s=="") return;
   string l[]; int n=StringSplit(s,'\n',l); string o=""; datetime br=AgoraBR(); bool mudou=false;
   for(int i=0;i<n;i++)
   {
      string p[]; if(StringSplit(l[i],';',p)<2) continue;
      if((datetime)StringToInteger(p[0])<=br){ SendMsg("⏰ Lembrete: "+p[1]); mudou=true; continue; }
      o+=l[i]+"\n";
   }
   if(mudou) ArqGrava(g_lembArq,o);
}
// ---------------- texto comprido: quebra em mensagens ----------------
void SendLongo(string t)
{
   while(StringLen(t)>3500)
   {
      int cut=3500; while(cut>2000 && StringGetCharacter(t,cut)!='\n') cut--;
      SendMsg(StringSubstr(t,0,cut)); t=StringSubstr(t,cut+1);
   }
   if(t!="") SendMsg(t);
}
// ================= 1. ENSINAR =================
string DistTxt(double lv,double bid)
{
   if(bid<=0 || lv<=0) return "";
   double d=lv-bid; string p=TxtPts(lv,bid);
   return StringFormat("%s pts %s",p,d>=0?"acima do preço":"abaixo do preço");
}
string NivelExplica(string nome)
{
   string u=Baixo(nome);
   if(StringFind(u,"ontem")>=0) return StringFormat("o %s preço de ontem. Muita gente deixa stop ali, por isso o preço gosta de ir buscar.",StringFind(u,"max")>=0?"maior":"menor");
   if(StringFind(u,"semana")>=0) return "extremo da semana passada: nível forte, costuma segurar ou ser caçado.";
   if(StringFind(u,"asia")>=0) return "extremo da sessão da Ásia (madrugada). Londres costuma vir caçar esse ponto.";
   if(StringFind(u,"londres")>=0) return "extremo da sessão de Londres. Nova York gosta de testar.";
   if(StringFind(u,"nova york")>=0) return "extremo da última sessão de Nova York.";
   if(StringFind(u,"topos iguais")>=0) return "dois topos na mesma altura = stops acumulados em cima (liquidez). Ímã de preço.";
   if(StringFind(u,"fundos iguais")>=0) return "dois fundos na mesma altura = stops acumulados embaixo (liquidez). Ímã de preço.";
   return "nível de liquidez.";
}
string ExplicaTxt()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(bid<=0 && ArraySize(g_r)>0) bid=g_r[0].close;
   string s="🎓 O que tem no seu gráfico do "+_Symbol+" agora ("+DiaHoraBR(AgoraBR(),false,true)+", Brasília). Preço "+Fmt(bid)+".\n";
   if(MercadoFechado()) s+="(Mercado fechado: é o desenho do último fechamento.)\n";
   s+="\n📏 LINHAS DE LIQUIDEZ (amarela = acima, branca = abaixo; tracejada = já varrida)\n";
   int nl=0;
   for(int v=0;v<ArraySize(g_niv) && nl<12;v++)
   {
      if(g_niv[v].estado==ST_ROMPIDO) continue;
      string est=g_niv[v].estado==ST_VARRIDA?" Já foi VARRIDA às "+HoraBRde(g_niv[v].tSweep)+" (o pavio passou e voltou: armadilha de stop).":"";
      s+="• "+g_niv[v].nome+" "+Fmt(g_niv[v].preco)+" ("+DistTxt(g_niv[v].preco,bid)+"): "+NivelExplica(g_niv[v].nome)+est+"\n"; nl++;
   }
   if(nl==0) s+="• Nenhuma linha de liquidez intacta perto.\n";
   if(g_engVWAP>0) s+="• Linha pontilhada \"Preço médio da sessão\" (VWAP) "+Fmt(g_engVWAP)+" ("+DistTxt(g_engVWAP,bid)+"): o preço médio pago hoje. Acima dela os compradores mandam; abaixo, os vendedores.\n";
   double poc=(g_engPOC>0?g_engPOC:g_engPOCOntem); if(poc>0) s+="• Pontilhada prata \"Preço de maior volume\" "+Fmt(poc)+": onde mais negociaram. Funciona como ímã.\n";
   int nb=ArraySize(g_bos);
   if(nb>0)
   {
      s+="\n📐 ESTRUTURA (tracejado curto com texto)\n";
      for(int k=MathMax(0,nb-3);k<nb;k++)
         s+="• \""+RotuloBos(g_bos[k])+"\" em "+Fmt(g_bos[k].preco)+" às "+HoraBRde(g_bos[k].tBreak)+": "+(g_bos[k].choch?"o preço fechou do outro lado do último topo/fundo, CONTRA a direção que vinha (CHoCH). Pode ser virada; espera confirmar.":"o preço fechou além do último "+(g_bos[k].dir==1?"topo":"fundo")+" a favor da direção (BOS). A tendência curta seguiu.")+"\n";
   }
   string fv=""; int nf=0;
   for(int m=ArraySize(g_fvg)-1;m>=0 && nf<3;m--){ if(g_fvg[m].filled) continue; fv+="• Caixa \"Vazio de preço\" "+TfNome(InpTFExec)+" de "+Fmt(g_fvg[m].bot)+" a "+Fmt(g_fvg[m].top)+" ("+DistTxt((g_fvg[m].top+g_fvg[m].bot)/2,bid)+"): o preço andou rápido e deixou um buraco ("+(g_fvg[m].dir==1?"de alta":"de baixa")+"). Ele costuma voltar pra preencher.\n"; nf++; }
   int nh=0; for(int m=ArraySize(g_fvgH1)-1;m>=0 && nh<2;m--){ if(g_fvgH1[m].filled) continue; fv+="• Caixa grossa H1 de "+Fmt(g_fvgH1[m].bot)+" a "+Fmt(g_fvgH1[m].top)+": vazio de preço do H1 (mais forte que o do "+TfNome(InpTFExec)+").\n"; nh++; }
   if(fv!="") s+="\n🟨 CAIXAS DE VAZIO (FVG)\n"+fv;
   string ob=""; int no=0;
   for(int i=ArraySize(g_obs)-1;i>=0 && no<3;i--){ if(g_obs[i].brk) continue; ob+="• Caixa \"Bloco de ordens\" de "+Fmt(g_obs[i].lo)+" a "+Fmt(g_obs[i].hi)+" ("+(g_obs[i].dir==1?"de compra":"de venda")+"): última vela contrária antes de um movimento forte. Quando o preço volta, costuma reagir.\n"; no++; }
   if(ob!="") s+="\n🧱 BLOCOS DE ORDENS\n"+ob;
   Plano b=MelhorPlano();
   s+="\n🧭 PLANO (setas tracejadas e linhas do cenário)\n";
   if(PlanoValido(b))
      s+=StringFormat("• Melhor lado agora: %s, nota %d/10. Linha \"Entrada\" %s, linha vermelha STOP %s (se passar daí, a ideia morreu), linha verde ALVO %s (vale %.1fx o risco). As setas \"vem buscar liquidez\" e \"depois sobe/desce até aqui\" são CENÁRIO, não certeza.\n",
         b.dir==1?"compra":"venda",b.score,Fmt(b.entry),Fmt(b.stop),Fmt(b.target),b.rr);
   else s+="• Sem setup válido agora (alvo menor que 1,5x o risco). Sem plano = sem operação.\n";
   if(b.score<InpScoreAmarelo || g_pare!="") s+="  (As linhas de entrada/stop/alvo só aparecem com nota "+IntegerToString(InpScoreAmarelo)+"+ e sem trava do dia.)\n";
   string st; SessaoNota(TimeTradeServer()>0?TimeTradeServer():TimeCurrent(),st);
   s+="\n🕐 HORÁRIO: "+st+(g_engKZ!=""?" · "+g_engKZ:"")+". Killzone = janela com mais volume (abertura de Londres e de NY). Fora dela tem mais armadilha.\n";
   s+=StringFormat("\n📊 PAINEL: \"Tempos\" ▲ alta ▼ baixa ● de lado (D1 até M1). Quando o maior e o menor brigam, é melhor esperar. Barra de confluência: compra %d x venda %d (é uma lista de motivos, não previsão).\n",MathMax(g_efBuy,0),MathMax(g_efSell,0));
   string al=AlertaLista(); if(al!="(nenhum)") s+="🔔 Linhas laranja pontilhadas = seus alertas: "+al+"\n";
   if(ArqLe(g_linhasArq)!="") s+="📏 Linhas azuis = as que você pediu.\n";
   s+="💬 Balão preto e amarelo = a última observação da IA (não é certeza).\n";
   s+="\nQuer aprender um por um? /aula fvg, /aula liquidez, /aula bos, /aula bloco, /aula vwap, /aula killzone, /aula stop. Legenda curtinha: /guia";
   return s;
}
void ExplicaEnvia()
{
   if(TgFoto("🎓 Seu gráfico agora. Explico cada marca na mensagem abaixo.")) {}
   SendLongo(ExplicaTxt());
   ObsSet("Mandei no Telegram o que é cada linha do gráfico.","🎓");
}
string AulaTxt(string tema)
{
   string t=Baixo(tema); StringTrimLeft(t); StringTrimRight(t);
   if(t=="") return "Escolhe um tema: fvg, liquidez, varrida, bos, choch, bloco, vwap, killzone, stop, rr, sessoes, vela, disciplina.";
   if(StringFind(t,"fvg")>=0||StringFind(t,"vazio")>=0||StringFind(t,"gap")>=0)
      return "📚 FVG (vazio de preço)\nQuando 3 velas seguidas andam tão rápido que a 1ª e a 3ª não se tocam, sobra um buraco. O preço costuma voltar nele antes de seguir.\nNo painel: caixa com o texto \"Vazio de preço\" (fina = "+TfNome(InpTFExec)+", grossa = H1/M15). Amarela = de alta, prata = de baixa.\nComo usar: não compre no meio do nada; espere o preço voltar na caixa a favor da tendência maior e o M1 confirmar. Sozinho NÃO é sinal.";
   if(StringFind(t,"liquid")>=0)
      return "📚 Liquidez\nÉ onde tem muita ordem parada: máximas/mínimas de ontem, da Ásia, de Londres e topos/fundos iguais. Os grandes precisam dessas ordens, então o preço costuma ir buscar.\nNo painel: linhas amarelas (acima) e brancas (abaixo) com o nome.\nComo usar: alvo perto da liquidez do outro lado; cuidado em pôr stop exatamente atrás dela.";
   if(StringFind(t,"varr")>=0||StringFind(t,"sweep")>=0)
      return "📚 Varrida\nO pavio passa de um nível de liquidez e a vela FECHA de volta. Pegou os stops e voltou: muitas vezes é armadilha.\nNo painel: seta pequena + texto \"Varrida da máxima/mínima...\" e a linha fica tracejada.\nComo usar: depois de varrer embaixo, procure compra só se a estrutura virar (CHoCH). Nunca entre só porque varreu.";
   if(StringFind(t,"choch")>=0)
      return "📚 CHoCH (mudança de direção)\nO preço vinha caindo e fecha ACIMA do último topo (ou o contrário). É o primeiro sinal de que pode virar.\nNo painel: tracejado com \"Mudança de direção pra cima/baixo\".\nComo usar: é aviso, não entrada. Espere um reteste e o tempo maior concordar.";
   if(StringFind(t,"bos")>=0||StringFind(t,"rompimento")>=0||StringFind(t,"estrutura")>=0)
      return "📚 BOS (rompimento de estrutura)\nO preço fecha além do último topo (na alta) ou fundo (na baixa), na mesma direção que vinha. A tendência curta continua.\nNo painel: tracejado com \"Rompimento de estrutura pra cima/baixo\".\nComo usar: só vale com o CORPO da vela fechando além, não só o pavio. Não persiga: espere o reteste.";
   if(StringFind(t,"bloco")>=0||t=="ob"||StringFind(t,"order")>=0)
      return "📚 Bloco de ordens\nÉ a última vela contrária antes de um movimento forte. Ali ficaram ordens grandes; quando o preço volta, costuma reagir.\nNo painel: caixa com \"Bloco de ordens\". O Alier avisa quando o preço chega nela.\nComo usar: zona de interesse, não de entrada cega. Olhe a reação no M1.";
   if(StringFind(t,"vwap")>=0||StringFind(t,"medio")>=0)
      return "📚 VWAP (preço médio da sessão)\nÉ o preço médio que todo mundo pagou hoje, pesado pelo volume.\nNo painel: linha pontilhada \"Preço médio da sessão\".\nComo usar: acima dela o dia tá comprador, abaixo vendedor. Toques nela costumam segurar ou virar ímã.";
   if(StringFind(t,"kill")>=0||StringFind(t,"sess")>=0||StringFind(t,"horar")>=0)
      return "📚 Killzones e sessões\nOuro mexe de verdade na abertura de Londres e na abertura de NY (e na sobreposição das duas). A Ásia costuma andar de lado e armar armadilha.\nNo painel: a linha de cima mostra a sessão e se o horário é BOM, normal ou RUIM.\nComo usar: opere só nas janelas boas. Abertura de domingo: spread largo, espere 15-30 min.";
   if(StringFind(t,"stop")>=0)
      return "📚 Stop\nÉ onde a sua ideia está errada. Vai atrás da estrutura (do outro lado do fundo/topo ou da varrida), com folga pro spread.\nNo painel: linha vermelha STOP com quanto você perde em US$.\nRegra: stop definido ANTES de entrar e nunca afastar depois. Stop curto demais no ouro o spread come.";
   if(StringFind(t,"rr")>=0||StringFind(t,"risco")>=0||StringFind(t,"alvo")>=0)
      return "📚 R:R (risco x retorno)\nSe você arrisca 10 pra ganhar 20, o R:R é 2. O robô só aceita alvo de no mínimo 1,5x o risco.\nNo painel: a linha verde ALVO mostra o R:R.\nPor quê: com R:R 2 você pode errar 6 de 10 e ainda empatar. Acertar muito com alvo pequeno não paga.";
   if(StringFind(t,"vela")>=0||StringFind(t,"candle")>=0)
      return "📚 Velas\nEngolfo, martelo, estrela cadente e doji só valem como confirmação em TOPO ou FUNDO de um movimento, nunca no meio do M1.\nComando (do seu curso): primeira vela de um movimento novo, sem pavio do lado da abertura; marque abertura, 50% e fechamento.";
   if(StringFind(t,"discip")>=0||StringFind(t,"psico")>=0||StringFind(t,"zone")>=0)
      return "📚 Disciplina (Trading in the Zone)\nUm trade sozinho não precisa estar certo. O que paga é repetir um plano com risco definido, pensando em série de 20, 50 trades.\nStop decidido antes libera a cabeça. Depois de 2 stops, para. Proteger a conta também é lucro.";
   return "Ainda não tenho aula pronta sobre \""+tema+"\". Temas: fvg, liquidez, varrida, bos, choch, bloco, vwap, killzone, stop, rr, vela, disciplina. Ou me pergunta com suas palavras que eu explico.";
}
// legenda (igual ao GUIA_DO_GRAFICO.md do kit)
string GuiaTxt()
{
   return "🗺️ GUIA DO GRÁFICO (uma linha por marca)\n"
          "• Linha AMARELA com nome = liquidez ACIMA do preço (máxima de ontem, Ásia, Londres, topos iguais).\n"
          "• Linha BRANCA com nome = liquidez ABAIXO (mínimas, fundos iguais).\n"
          "• Linha TRACEJADA = esse nível já foi varrido.\n"
          "• Seta pequena + \"Varrida...\" = o pavio passou do nível e voltou (armadilha de stop).\n"
          "• Tracejado curto \"Rompimento de estrutura\" (BOS) = fechou além do último topo/fundo a favor.\n"
          "• Tracejado curto \"Mudança de direção\" (CHoCH) = rompeu contra a direção: possível virada.\n"
          "• Caixa \"Vazio de preço\" (FVG) = buraco que o preço costuma voltar pra preencher (amarela alta, prata baixa; grossa = H1/M15).\n"
          "• Caixa \"Bloco de ordens\" = zona onde ficaram ordens grandes; costuma reagir.\n"
          "• Pontilhada amarela \"Preço médio da sessão\" = VWAP. Pontilhada prata \"Preço de maior volume\" = POC.\n"
          "• Linha tracejada \"Entrada\", VERMELHA \"STOP\", VERDE \"ALVO\" = plano (só com nota 4+).\n"
          "• Setas tracejadas \"vem buscar liquidez\" / \"depois sobe/desce até aqui\" = cenário, não certeza.\n"
          "• Seta verde/vermelha grande = sinal nota 7+ (nos testes, seguir sozinha perdeu).\n"
          "• Linha AZUL = linha que você pediu. Laranja pontilhada = seu alerta.\n"
          "• Balão preto e amarelo = última observação da IA.\n"
          "• Painel: Tempos ▲▼● (D1 até M1), Níveis com distância em pontos, Confluência (lista, não previsão), Hoje na conta.\n"
          "Muito poluído? Peça \"modo limpo\" ou /limpo.";
}
string PodesTxt()
{
   return "👽 O que eu faço por você (pode pedir com suas palavras):\n"
          "🎓 Ensinar: \"me explica o gráfico\" (/explica), /aula fvg, /guia\n"
          "📒 Seus trades: \"meus trades hoje\" (/trades) com o porquê de cada stop\n"
          "🔔 Alertas: \"me avisa se passar de 3900\", \"tira o alerta\", /alertas\n"
          "📏 Linhas: \"desenha uma linha em 3880 suporte\", \"apaga as linhas\"\n"
          "🧹 Gráfico: \"modo limpo\", \"esconde o bloco da IA\", \"painel mini\"\n"
          "🔕 Avisos: \"para de avisar VWAP\", \"só me avisa nota 8+\"\n"
          "📌 Regras: \"não me deixa operar na Ásia\" (eu aviso se você abrir trade contra)\n"
          "⏰ Lembretes: \"me lembra 10:30 de olhar o payroll\"\n"
          "📸 Prints: \"manda o H1 do ouro\"; \"analisa o US500 por padrão\"\n"
          "💼 Ordens (só você, com botão Confirmar): \"compra 0.05 stop 3880 alvo 3900\", \"fecha metade\", \"stop no zero\", \"fecha tudo\"\n"
          "🤖 Autônomo na DEMO: /autonomo on|off, /aprendizado, /reset_aprendizado\n"
          "⏸️ Pausar/retomar (eu confirmo antes).";
}
// ================= 3. REVISÃO DOS TRADES =================
string g_tctxArq="ALIEN_trades_contexto.csv";
string g_tctxHdr="posicao;hora_servidor;hora_brasilia;simbolo;lado;lote;preco;nota_compra;nota_venda;melhor_lado;sessao;killzone;D1;H4;H1;M15;M5;M1;spread;plano_lado;plano_entrada;plano_stop;plano_alvo;trava;origem";
bool TradeCtxTem(long pos){ int h=FileOpen(g_tctxArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE); if(h==INVALID_HANDLE) return false; string k=IntegerToString(pos)+";"; bool a=false; while(!FileIsEnding(h)){ string l=FileReadString(h); if(StringFind(l,k)==0){ a=true; break; } } FileClose(h); return a; }
string TradeCtxLe(long pos){ int h=FileOpen(g_tctxArq,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE); if(h==INVALID_HANDLE) return ""; string k=IntegerToString(pos)+";", r=""; while(!FileIsEnding(h)){ string l=FileReadString(h); if(StringFind(l,k)==0){ r=l; break; } } FileClose(h); return r; }
// foto do painel na hora em que um trade abre (qualquer trade da conta)
void TradeCtxGrava(ulong deal)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   long en=HistoryDealGetInteger(deal,DEAL_ENTRY); if(en!=DEAL_ENTRY_IN) return;
   long pos=HistoryDealGetInteger(deal,DEAL_POSITION_ID); if(TradeCtxTem(pos)) return;
   string sym=HistoryDealGetString(deal,DEAL_SYMBOL); long tp=HistoryDealGetInteger(deal,DEAL_TYPE);
   datetime ts=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
   double vol=HistoryDealGetDouble(deal,DEAL_VOLUME), px=HistoryDealGetDouble(deal,DEAL_PRICE);
   bool aqui=(sym==_Symbol); string st; SessaoNota(ts,st);
   Plano b=MelhorPlano(); double spr=SymbolInfoDouble(sym,SYMBOL_ASK)-SymbolInfoDouble(sym,SYMBOL_BID);
   long mg=HistoryDealGetInteger(deal,DEAL_MAGIC);
   string org=(mg==InpMagic?"robo":(mg==InpMagic+1?"telegram":"manual"));
   CsvAppend(g_tctxArq,g_tctxHdr,StringFormat("%I64d;%s;%s;%s;%s;%.2f;%s;%d;%d;%s;%s;%s;%d;%d;%d;%d;%d;%d;%s;%s;%s;%s;%s;%s;%s",pos,TimeToString(ts,TIME_DATE|TIME_MINUTES),TimeToString(SrvParaBR(ts),TIME_DATE|TIME_MINUTES),
      sym,tp==DEAL_TYPE_BUY?"compra":"venda",vol,FmtS(sym,px),aqui?g_pb.score:-1,aqui?g_ps.score:-1,aqui?(b.dir==1?"compra":"venda"):"-",CsvLimpo(st),CsvLimpo(aqui?g_engKZ:""),
      g_mtf[0],g_mtf[1],g_mtf[2],g_mtf[3],g_mtf[4],g_mtf[5],FmtS(sym,spr),aqui&&PlanoValido(b)?(b.dir==1?"compra":"venda"):"-",aqui&&PlanoValido(b)?Fmt(b.entry):"-",aqui&&PlanoValido(b)?Fmt(b.stop):"-",aqui&&PlanoValido(b)?Fmt(b.target):"-",CsvLimpo(g_pare),org));
   string rq=RegraQuebrada(vol);
   if(rq!="" && TgOk() && (!TgChatOn() || TgMaster())) SendMsg("⚠️ Opa, você abriu "+(tp==DEAL_TYPE_BUY?"compra":"venda")+" de "+sym+", mas tem uma regra sua: "+rq+". Tá seguindo o plano? Se for o caso, fecha com calma.");
}
struct TradeLin { long pos; string sym; int dir; double vol; datetime t0; double p0; double sl; double tp; datetime t1; double p1; double net; string saida; bool aberta; };
string SaidaTxt(long reason)
{
   if(reason==DEAL_REASON_SL) return "bateu o stop";
   if(reason==DEAL_REASON_TP) return "bateu o alvo";
   if(reason==DEAL_REASON_SO) return "stop out da corretora";
   if(reason==DEAL_REASON_EXPERT) return "fechado pelo robô";
   if(reason==DEAL_REASON_CLIENT || reason==DEAL_REASON_MOBILE || reason==DEAL_REASON_WEB) return "fechado na mão";
   return "fechado";
}
int TradesHoje(TradeLin &t[])
{
   ArrayResize(t,0);
   datetime now=TimeTradeServer(); if(now==0) now=TimeCurrent();
   if(!HistorySelect(DayStart(now),now+60)) return 0;
   long ids[]; int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue; long ty=HistoryDealGetInteger(d,DEAL_TYPE); if(ty!=DEAL_TYPE_BUY && ty!=DEAL_TYPE_SELL) continue;
      long p=HistoryDealGetInteger(d,DEAL_POSITION_ID); bool tem=false; for(int k=0;k<ArraySize(ids);k++) if(ids[k]==p){ tem=true; break; }
      if(!tem){ int k=ArraySize(ids); ArrayResize(ids,k+1); ids[k]=p; }
   }
   for(int q=0;q<ArraySize(ids) && q<20;q++)
   {
      if(!HistorySelectByPosition(ids[q])) continue;
      TradeLin L; L.pos=ids[q]; L.sym=""; L.dir=0; L.vol=0; L.t0=0; L.p0=0; L.sl=0; L.tp=0; L.t1=0; L.p1=0; L.net=0; L.saida=""; L.aberta=true;
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong d=HistoryDealGetTicket(i); if(d==0) continue; long en=HistoryDealGetInteger(d,DEAL_ENTRY);
         L.net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);
         if(en==DEAL_ENTRY_IN && L.t0==0){ L.sym=HistoryDealGetString(d,DEAL_SYMBOL); L.dir=(HistoryDealGetInteger(d,DEAL_TYPE)==DEAL_TYPE_BUY?1:-1); L.vol=HistoryDealGetDouble(d,DEAL_VOLUME); L.t0=(datetime)HistoryDealGetInteger(d,DEAL_TIME); L.p0=HistoryDealGetDouble(d,DEAL_PRICE); L.sl=HistoryDealGetDouble(d,DEAL_SL); L.tp=HistoryDealGetDouble(d,DEAL_TP); }
         if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_OUT_BY){ L.t1=(datetime)HistoryDealGetInteger(d,DEAL_TIME); L.p1=HistoryDealGetDouble(d,DEAL_PRICE); L.saida=SaidaTxt(HistoryDealGetInteger(d,DEAL_REASON)); if(L.sl<=0) L.sl=HistoryDealGetDouble(d,DEAL_SL); if(L.tp<=0) L.tp=HistoryDealGetDouble(d,DEAL_TP); }
      }
      if(L.sym=="") continue;
      L.aberta=PositionSelectByTicket((ulong)L.pos);
      if(L.aberta){ L.net=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP); L.sl=PositionGetDouble(POSITION_SL); L.tp=PositionGetDouble(POSITION_TP); }
      int k=ArraySize(t); ArrayResize(t,k+1); t[k]=L;
   }
   return ArraySize(t);
}
// leitura simples do porquê (usa a foto do painel na entrada, se tiver)
string TradeLeitura(const TradeLin &L)
{
   string c=TradeCtxLe(L.pos); string s="";
   string st; int sN=SessaoNota(L.t0,st);
   if(sN==-1) s+="horário ruim ("+st+"); ";
   if(c=="") return s+"sem foto do painel na entrada (o robô começou a guardar na 12.6)";
   string p[]; int n=StringSplit(c,';',p); if(n<24) return s;
   int h1=(int)StringToInteger(p[14]), m15=(int)StringToInteger(p[15]);
   if(h1!=0 && h1!=L.dir) s+="contra o H1 ("+TendPalavra(h1)+"); ";
   if(m15!=0 && m15!=L.dir) s+="contra o M15; ";
   int nc=(int)StringToInteger(p[7]), nv=(int)StringToInteger(p[8]); int nota=(L.dir==1?nc:nv);
   if(nota>=0) s+=StringFormat("nota do lado era %d/10; ",nota);
   if(p[19]!="-" && p[19]!=(L.dir==1?"compra":"venda")) s+="o plano do painel era "+p[19]+"; ";
   double spr=StringToDouble(p[18]); if(L.sl>0 && spr>0 && spr>0.15*MathAbs(L.p0-L.sl)) s+=StringFormat("spread grande pro stop (%.0f%% da distância); ",100.0*spr/MathAbs(L.p0-L.sl));
   if(L.sl<=0) s+="entrou SEM stop; ";
   if(p[23]!="") s+="tinha trava do dia ("+p[23]+"); ";
   if(p[11]!="" && StringFind(Baixo(p[11]),"fora")<0) s+="dentro de "+p[11]+"; ";
   return s==""?"dentro do plano":s;
}
string TradesTxt(bool compacto)
{
   TradeLin t[]; int n=TradesHoje(t);
   if(n==0) return compacto?"TRADES HOJE: nenhum.":"📒 Hoje ainda não teve trade na conta.";
   string s=compacto?"TRADES HOJE (da conta, Brasília):\n":"📒 Seus trades de hoje (horário de Brasília):\n";
   double tot=0;
   for(int i=0;i<n;i++)
   {
      TradeLin L=t[i]; int dg=(int)SymbolInfoInteger(L.sym,SYMBOL_DIGITS); tot+=L.net;
      string sl=L.sl>0?DoubleToString(L.sl,dg):"sem", tp=L.tp>0?DoubleToString(L.tp,dg):"sem";
      if(compacto) s+=StringFormat("- %s %s %s %.2f entrada %s SL %s TP %s %s %s $%+.2f | %s\n",HoraBRde(L.t0),L.sym,L.dir==1?"compra":"venda",L.vol,DoubleToString(L.p0,dg),sl,tp,
            L.aberta?"ABERTA":"saída "+DoubleToString(L.p1,dg)+" às "+HoraBRde(L.t1),L.aberta?"":L.saida,L.net,TradeLeitura(L));
      else s+=StringFormat("\n%s %s %s %.2f lote às %s\n   entrada %s · stop %s · alvo %s\n   %s · resultado $%+.2f\n   👀 %s\n",L.net>=0?"✅":"🔻",L.dir==1?"🟢 compra":"🔴 venda",L.sym,L.vol,HoraBRde(L.t0),
            DoubleToString(L.p0,dg),sl,tp,L.aberta?"ainda aberta":"saiu em "+DoubleToString(L.p1,dg)+" às "+HoraBRde(L.t1)+" ("+L.saida+")",L.net,TradeLeitura(L));
   }
   s+=StringFormat(compacto?"Total do dia: $%+.2f\n":"\nTotal do dia: $%+.2f",tot);
   return s;
}
void TradesEnvia(bool comIA)
{
   string lista=TradesTxt(false);
   SendLongo(lista);
   if(!comIA || !AIOn() || StringFind(lista,"ainda não teve")>=0) return;
   int w=AIEsperaSeg(); if(w>0) return;
   string r=AIAskEx("Você é o Alier, colega de trading do Vitor (leigo). Português do Brasil, simples, até 6 frases, sem markdown. Explique por que os trades de hoje ganharam ou perderam, usando SÓ os dados (horário, sessão, H1/M15 contra, spread, nota, plano, saída). Dê 1 lição prática. Não invente números.",
                    CtxIA("",false,false)+TradesTxt(true),450,false,false,0.4);
   if(r!=""){ r=AISemVeredito(SemCamposCrus(r)); MemAdd("Alier",r); SendMsg("🧠 "+r); }
}
string TradesHojeIA(){ string s=TradesTxt(true); return StringLen(s)>1500?StringSubstr(s,0,1500)+"...\n":s; }
// ================= conhecimento do projeto (arquivo editável) =================
string g_conhec=""; datetime g_conhecT=0;
string ConhecimentoTxt()
{
   if(g_conhec!="" && TimeLocal()-g_conhecT<600) return g_conhec;
   g_conhecT=TimeLocal(); string s="";
   int h=FileOpen("ALIEN_conhecimento.txt",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
   if(h!=INVALID_HANDLE){ while(!FileIsEnding(h)){ string l=FileReadString(h); if(StringLen(l)>0 && StringGetCharacter(l,0)=='#') continue; s+=l+"\n"; } FileClose(h); }
   if(StringLen(s)<200) s=ConhecimentoPadrao();
   if(StringLen(s)>4500) s=StringSubstr(s,0,4500);
   g_conhec=s; return s;
}
string ConhecimentoPadrao()
{
   return "@@CONHECIMENTO@@";
}
// ================= detecção de pedidos em texto livre =================
bool TemAlgum(string u,const string &k[]){ for(int i=0;i<ArraySize(k);i++) if(StringFind(u,k[i])>=0) return true; return false; }
bool EhPedidoExplica(string t)
{
   string u=Baixo(t);
   string k[]={"explica o grafico","me explica o grafico","explique o grafico","o que e essa linha","o que sao essas linhas","que linha e essa","nao entendo as linha","nao to entendendo as linha","nao entendo o grafico","o que significa essa","o que e essa caixa","o que sao essas caixas","explica as linhas","explica essas linhas","o que e cada linha"};
   return TemAlgum(u,k);
}
bool EhPedidoAgora(string t)
{
   string u=Baixo(t);
   if(u=="agora" || u=="agora?" || u=="e agora" || u=="e agora?" || u=="e ai" || u=="e ai?") return true;
   string k[]={"e agora","oq eu faco","o que eu faco","que que eu faco","compro ou vendo","compra ou vende","compra ou venda","devo comprar","devo vender","entro ou nao","entro agora","da pra entrar","posso entrar","to perdido","nao to entendendo nada","nao entendo nada","o que ta acontecendo","oq ta acontecendo","que ta acontecendo","me ajuda com o mercado","como ta o mercado","como ta o ouro"};
   return TemAlgum(u,k);
}
bool EhPedidoTrades(string t)
{
   string u=Baixo(t);
   string k[]={"meus trades","minhas operac","meus stops","trades de hoje","trades hoje","operacoes de hoje","por que eu perdi","porque eu perdi","por que tomei","porque tomei","por que perdi","os stops de hoje","meu historico de hoje"};
   return TemAlgum(u,k);
}
bool EhPedidoPodes(string t)
{
   string u=Baixo(t);
   string k[]={"o que voce pode fazer","o que vc pode fazer","o que voce consegue fazer","o que vc consegue","quais seus comandos","o que voce faz","o que vc faz","suas funcoes","como te dar instruc","como te dar ordem"};
   return TemAlgum(u,k);
}
// ================= comandos novos (chamado pelo TgHandle) =================
bool AcoesCmd(string cmd,string args)
{
   if(cmd=="/agora"){ SendMsg(AgoraTexto()); return true; }
   if(cmd=="/explica"){ ExplicaEnvia(); return true; }
   if(cmd=="/aula"){ SendMsg(AulaTxt(args)); return true; }
   if(cmd=="/guia"){ SendMsg(GuiaTxt()); return true; }
   if(cmd=="/podes"||cmd=="/acoes"||cmd=="/ações"){ SendMsg(PodesTxt()); return true; }
   if(cmd=="/trades"){ TradesEnvia(true); return true; }
   if(cmd=="/alertas"){ string a=Baixo(args); if(StringFind(a,"limpa")>=0||StringFind(a,"tira")>=0||StringFind(a,"apaga")>=0){ SendMsg(AcaoExecuta("alerta_remove","todos")); } else SendMsg("🔔 Alertas ativos: "+AlertaLista()+"\nPra criar: /alerta 3900 ou \"me avisa se passar de 3900\". Pra tirar: /alertas limpa"); return true; }
   if(cmd=="/regras"){ SendMsg(RegrasTxt()); return true; }
   if(cmd=="/lembretes"){ SendMsg(LembretesTxt()); return true; }
   if(cmd=="/regra"){ SendMsg(args==""?RegrasTxt():AcaoExecuta("regra",args)); return true; }
   if(cmd=="/linha"){ string p[]; int n=StringSplit(args,' ',p); string t=""; for(int i=1;i<n;i++) t+=(t==""?"":" ")+p[i]; SendMsg(AcaoExecuta("linha",(n>0?p[0]:"")+"|"+t)); return true; }
   if(cmd=="/limpo"){ SendMsg(AcaoExecuta("limpo",args==""?(g_modoLimpo?"off":"on"):args)); return true; }
   if(cmd=="/painel"){ string p[]; int n=StringSplit(args,' ',p); SendMsg(AcaoExecuta("painel",(n>0?p[0]:"")+"|"+(n>1?p[1]:"on"))); return true; }
   if(cmd=="/mudo"){ SendMsg(AcaoExecuta("mudo",args)); return true; }
   if(cmd=="/som"){ SendMsg(AcaoExecuta("som",args)); return true; }
   if(cmd=="/nota"){ SendMsg(AcaoExecuta("nota_alerta",args)); return true; }
   if(cmd=="/simbolo"||cmd=="/símbolo"){ SendMsg(AcaoExecuta("simbolo",args)); return true; }
   if(cmd=="/lembrete"){ int sp=StringFind(args," "); SendMsg(AcaoExecuta("lembrete",(sp>0?StringSubstr(args,0,sp)+"|"+StringSubstr(args,sp+1):args+"|"))); return true; }
   if(cmd=="/print"){ string p[]; int n=StringSplit(args,' ',p); string r=AcaoExecuta("print",(n>0?p[0]:"")+"|"+(n>1?p[1]:"")); if(r!="") SendMsg(r); return true; }
   return false;
}
