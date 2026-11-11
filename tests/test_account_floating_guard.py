"""Exercise actual MQL guard with a mocked terminal in C++ (not an MT5 compile)."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class GuardTests(unittest.TestCase):
 def test_guard_runtime_and_policy(self):
  code=(ROOT/'MQL5/Include/AlienProfessor/AccountFloatingGuard.mqh').read_text()
  code=code.replace('#include <Trade/Trade.mqh>','')
  code=re.sub(r'^input group .*\n','',code,flags=re.M).replace('input ','')
  code=code.replace('ulong tickets[]; double pnl[];','std::vector<ulong> tickets; std::vector<double> pnl;')
  shim=r'''
#include <string>
#include <vector>
#include <map>
#include <cmath>
#include <cstdio>
#include <cassert>
#include <algorithm>
using string=std::string;
using datetime=long;
const int MQL_TRADE_ALLOWED=17,TERMINAL_CONNECTED=18,TERMINAL_TRADE_ALLOWED=19,ACCOUNT_TRADE_EXPERT=20;
const int MQL_TESTER=1,ACCOUNT_SERVER=2,ACCOUNT_LOGIN=3,ACCOUNT_CURRENCY=4,ACCOUNT_BALANCE=5,ACCOUNT_EQUITY=6;
const int POSITION_PROFIT=10,POSITION_SWAP=11,POSITION_SYMBOL=12,POSITION_SL=13,POSITION_TYPE=14,POSITION_VOLUME=15,POSITION_PRICE_OPEN=16;
const int FILE_READ=1,FILE_WRITE=2,FILE_CSV=4,FILE_ANSI=8,FILE_SHARE_READ=16,INVALID_HANDLE=-1,TIME_DATE=1,TIME_SECONDS=2;
const int TRADE_RETCODE_DONE=10009,POSITION_TYPE_BUY=0;
enum ENUM_ORDER_TYPE {ORDER_TYPE_BUY,ORDER_TYPE_SELL};
string _Symbol="XAUUSD";
struct Pos {ulong id;string symbol;double pnl;double sl;bool open;};
std::vector<Pos> positions;std::vector<ulong> orders,closedTickets;
int selected=-1,closeFailures=0,deleteFailures=0;ulong clockMs=100;bool tester=false;
std::map<string,double> globals;
template<class... T>void Print(T...){ }
template<class... T>void Alert(T...){ }
const char* cv(const string&s){return s.c_str();}
template<class T>T cv(T v){return v;}
template<class... T>string StringFormat(const char*fmt,T...args){char b[2048];snprintf(b,sizeof(b),fmt,cv(args)...);return b;}
string IntegerToString(long n){return std::to_string(n);}
string DoubleToString(double n,int d){char b[100];snprintf(b,sizeof(b),"%.*f",d,n);return b;}
int StringLen(string s){return s.size();} uint StringGetCharacter(string s,int i){return (unsigned char)s[i];}
bool MathIsValidNumber(double n){return std::isfinite(n);}double MathMax(double a,double b){return std::max(a,b);}
double MathMin(double a,double b){return std::min(a,b);}
long MQLInfoInteger(int f){return f==MQL_TESTER?tester:1;}
long TerminalInfoInteger(int){return 1;}
string AccountInfoString(int f){return f==ACCOUNT_CURRENCY?"USD":"TestBroker";}
long AccountInfoInteger(int){return 123;}
int PositionsTotal(){return std::count_if(positions.begin(),positions.end(),[](auto&p){return p.open;});}
ulong PositionGetTicket(int idx){for(size_t i=0;i<positions.size();i++)if(positions[i].open&&idx--==0){selected=i;return positions[i].id;}return 0;}
bool PositionSelectByTicket(ulong id){for(size_t i=0;i<positions.size();i++)if(positions[i].id==id&&positions[i].open){selected=i;return true;}return false;}
double PositionGetDouble(int f){auto&p=positions[selected];if(f==POSITION_PROFIT)return p.pnl;if(f==POSITION_SL)return p.sl;if(f==POSITION_VOLUME)return .01;if(f==POSITION_PRICE_OPEN)return 100;return 0;}
long PositionGetInteger(int){return POSITION_TYPE_BUY;}
string PositionGetString(int){return positions[selected].symbol;}
double AccountInfoDouble(int f){double b=5000;if(f==ACCOUNT_BALANCE)return b;for(auto&p:positions)if(p.open)b+=p.pnl;return b;}
int OrdersTotal(){return orders.size();}ulong OrderGetTicket(int i){return i<(int)orders.size()?orders[i]:0;}
bool GlobalVariableCheck(string k){return globals.count(k);}
double GlobalVariableGet(string k){return globals[k];}
datetime GlobalVariableSet(string k,double v){globals[k]=v;return 1;}void GlobalVariablesFlush(){}
ulong GetTickCount64(){return clockMs;}
int FileOpen(string,int,char){return INVALID_HANDLE;}int FileSize(int){return 0;}
template<class...T>void FileWrite(T...){ }void FileSeek(int,int,int){}void FileFlush(int){}void FileClose(int){}
long TimeCurrent(){return 1;}string TimeToString(long,int){return "time";}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
bool OrderCalcProfit(ENUM_ORDER_TYPE side,string,double vol,double price,double sl,double &pnl){pnl=(sl-price)*(side==ORDER_TYPE_BUY?1:-1)*vol*100;return true;}
class CTrade{
 uint rc=TRADE_RETCODE_DONE;
 public:
 void SetAsyncMode(bool){}void SetDeviationInPoints(int){}void SetTypeFillingBySymbol(string){}
 uint ResultRetcode(){return rc;}string ResultRetcodeDescription(){return "mock";}
 bool OrderDelete(ulong id){if(deleteFailures-->0){rc=1;return false;}orders.erase(std::remove(orders.begin(),orders.end(),id),orders.end());rc=TRADE_RETCODE_DONE;return true;}
 bool PositionClose(ulong id){if(closeFailures-->0){rc=1;return false;}for(auto&p:positions)if(p.id==id)p.open=false;closedTickets.push_back(id);rc=TRADE_RETCODE_DONE;return true;}
};
'''
  harness=r'''
void reset(){positions.clear();orders.clear();globals.clear();closedTickets.clear();selected=-1;closeFailures=deleteFailures=0;agLatched=false;agBusy=false;agLastAction=agLastWarning=agLastError=0;clockMs=100;tester=false;AGEnable=true;AGInitialBalance=5000;AGFloatingLimitPercent=1;AGSafetyBufferMoney=20;AGWarningMoney=20;}
int main(){
 assert(AGDecision(5000,1,20,20,19.99,0,false)==0);
 assert(AGDecision(5000,1,20,20,20,0,false)==1);
 assert(AGDecision(5000,1,20,20,29.99,0,false)==1);
 assert(AGDecision(5000,1,20,20,30,0,false)==2);
 assert(AGDecision(5000,1,20,20,79.69,79.69,false)==2);
 assert(AGDecision(5000,1,20,20,0,0,true)==2);
 assert(AGDecision(5000,1,50,20,0,0,false)==-1);
 assert(AGDecision(NAN,1,20,20,0,0,false)==-1);
 // All symbols/magics: 3 losers total -79.69, one winner cannot mask them.
 reset();positions={{1,"XAUUSD",-30,90,true},{2,"EURUSD",-25,90,true},{3,"BTCUSD",-24.69,90,true},{4,"USDJPY",100,90,true}};orders={99};assert(AGInit());assert(AGCheck());
 assert(PositionsTotal()==0&&OrdersTotal()==0);assert(closedTickets.front()==1);assert(globals[agKey]==1);
 // Restart preserves lock. Newly opened manual trades are closed again.
 agLatched=false;assert(AGInit());assert(agLatched);positions.push_back({5,"EURUSD",0,90,true});clockMs+=300;assert(AGCheck());assert(PositionsTotal()==0);
 // Failures must not clear the latch; next pass retries both pending and position.
 reset();positions={{7,"XAUUSD",-35,90,true}};orders={44};closeFailures=1;deleteFailures=1;assert(AGInit());assert(AGCheck());assert(PositionsTotal()==1&&OrdersTotal()==1);
 clockMs+=300;assert(AGCheck());assert(PositionsTotal()==0&&OrdersTotal()==0);
 // No closure below trigger; conservative loss ignores profitable positions.
 reset();positions={{1,"XAUUSD",-21,90,true},{2,"EURUSD",50,90,true}};assert(AGInit());assert(!AGCheck());assert(agLoss==21);assert(PositionsTotal()==2);
 // EA risk gate rejects unprotected manual exposure, projected basket and pendings.
 reset();positions={{1,"XAUUSD",-2,0,true}};assert(AGInit());string reason;
 assert(!AGCanOpen(ORDER_TYPE_BUY,.01,100,95,0,reason));
 positions[0].sl=75;assert(!AGCanOpen(ORDER_TYPE_BUY,.01,100,95,0,reason));
 positions[0].sl=90;assert(AGCanOpen(ORDER_TYPE_BUY,.01,100,95,0,reason));
 orders={10};assert(!AGCanOpen(ORDER_TYPE_BUY,.01,100,95,0,reason));
 // Backtest never consumes/changes live lock.
 reset();assert(AGInit());globals[agKey]=1;tester=true;assert(AGInit());assert(!agLatched);assert(!AGCheck());
}
'''
  with tempfile.TemporaryDirectory() as d:
   src=Path(d)/'test.cpp';exe=Path(d)/'test';src.write_text(shim+code+harness)
   subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(src),'-o',str(exe)],check=True)
   subprocess.run([str(exe)],check=True)
 def test_integration(self):
  s=(ROOT/'MQL5/Experts/ALIEN_V12_3_SCALP_SUPERVISOR.mq5').read_text()
  for start,end in [('void OnTick()','MqlTick tick;'),('void OnTimer()','RefreshDailyEquityBaseline();')]:
   part=s[s.index(start):];self.assertLess(part.index('AGCheck()'),part.index(end))
  self.assertIn('AGCanOpen(side,volume,price,stop',s)
  self.assertIn('EventSetMillisecondTimer(250)',s)
  supervisor=(ROOT/'MQL5/Experts/ALIEN_SUPERVISOR_5K.mq5').read_text()
  self.assertNotIn('trade.Buy',supervisor);self.assertNotIn('trade.Sell',supervisor)
if __name__=='__main__':unittest.main()
