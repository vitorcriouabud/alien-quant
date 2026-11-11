"""Execute the actual pure MQL detector through a minimal C++ compatibility shim.
This checks pattern mechanics, not MetaEditor compilation or profitability.
Run: python tests/test_scalp_hypotheses.py (requires g++).
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'MQL5/Include/AlienProfessor/ScalpHypotheses.mqh'
EA = ROOT / 'MQL5/Experts/ALIEN_V12_2_SCALP_LAB.mq5'

class ScalpTests(unittest.TestCase):
    def test_detector_fixtures(self):
        module = MODULE.read_text().replace('const MqlRates &r[]', 'const std::vector<MqlRates> &r')
        shim = r'''
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>
#include <cassert>
using string=std::string;
using datetime=long long;
struct MqlRates { datetime time; double open, high, low, close; };
template<class T> int ArraySize(const std::vector<T>& v) { return (int)v.size(); }
double MathMax(double a,double b) { return std::max(a,b); }
double MathMin(double a,double b) { return std::min(a,b); }
double MathAbs(double a) { return std::abs(a); }
bool MathIsValidNumber(double a) { return std::isfinite(a); }
'''
        harness = r'''
void set(std::vector<MqlRates>& r,int i,double o,double h,double l,double c)
{ r[i]={1200-i*60,o,h,l,c}; }
std::vector<MqlRates> fixture(int id)
{
 std::vector<MqlRates> r(12);
 for(int i=0;i<12;i++) set(r,i,100,102,98,100);
 if(id==6) { set(r,2,100,102.2,99.8,102); set(r,1,102,102.1,101.2,101.5); set(r,0,101.6,102.6,101.4,102.5); }
 if(id==7) { for(int i=1;i<12;i++) set(r,i,100,100.5,99.5,100); set(r,0,100,101.3,99.9,101.2); }
 if(id==8) { set(r,1,98,98.2,96.8,97); set(r,0,97,99.2,96.9,99); }
 if(id==9) set(r,0,98.1,99,97.9,98.8);
 if(id==10) { set(r,3,99,100.2,98.8,100); set(r,2,100,102.2,99.9,102); set(r,1,102,102.4,101.8,102.2); set(r,0,101.5,102.2,101.2,102); }
 if(id==11) { set(r,3,100.5,100.7,99.8,100); set(r,2,100,102.2,99.9,102); set(r,1,102,102.3,101.8,102.1); set(r,0,100.5,101.4,100.4,101.2); }
 return r;
}
int main()
{
 AlienScalpSignal s;
 for(int id=6;id<=11;id++)
 {
  auto r=fixture(id);
  assert(AlienScalpDetect(r,12,id,1,2,0.01,s));
  assert(s.id==id && s.direction==1 && s.time==r[0].time && s.invalidation<r[0].close);
  auto mirror=r;
  for(auto &b:mirror) { double oldH=b.high; b.open=200-b.open; b.close=200-b.close; b.high=200-b.low; b.low=200-oldH; }
  assert(AlienScalpDetect(mirror,12,id,-1,2,0.01,s));
  assert(s.direction==-1 && s.invalidation>mirror[0].close);
  auto neutral=r; neutral[0].close=neutral[0].open;
  assert(!AlienScalpDetect(neutral,12,id,1,2,0.01,s));
  assert(!AlienScalpDetect(r,11,id,1,2,0.01,s));
  assert(!AlienScalpDetect(r,12,id,1,0,0.01,s));
  assert(!AlienScalpDetect(r,12,id,0,2,0.01,s));
  r[0].time=r[1].time;
  assert(!AlienScalpDetect(r,12,id,1,2,0.01,s));
 }
}
'''
        with tempfile.TemporaryDirectory() as td:
            cpp, binary = Path(td)/'test.cpp', Path(td)/'test'
            cpp.write_text(shim + module + harness)
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)

    def test_ea_integration(self):
        s = EA.read_text()
        self.assertIn('CopyRates(_Symbol,PERIOD_M1,1,12,closed)', s)
        self.assertIn('scalpLabTradedTime[signalSetup]=scalpLabSignalTime', s)
        self.assertIn('double expectedLoss=MathMax(0.0,-simulatedPnl)+RoundTurnCommissionPerLot*volume', s)
        self.assertIn('if(expectedLoss > chosenRisk+0.000001 || expectedLoss > equityRiskCap+0.000001)', s)
        self.assertIn('ScalpHypothesisMode=0', s)
        for array in ('setupCount', 'setupWins', 'setupNet', 'setupSignals'):
            self.assertIn(array+'[12]', s)
        self.assertLess(s.index('if(lastSetup>=6) setupClaro=SetupName(lastSetup)'), s.index('panels[7] ='))

if __name__ == '__main__':
    unittest.main()
