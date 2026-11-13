import hashlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'analyze_mt5_evidence.py'
sys.path.insert(0, str(SCRIPT.parent))
import analyze_mt5_evidence as mod


def fixture_html(net, panel_width=640):
    pairs = [('Expert Advisor (Robô):','ALIEN_V12_1_INSTITUTIONAL'),
             ('Ativo:','XAUUSD'), ('Período:','M1 (2026.10.21 - 2026.10.24)'),
             ('Depósito Inicial:','10 000.00'), ('Alavancagem:','1:100'),
             ('Qualidade do histórico:','100% de ticks reais'),
             ('Lucro Líquido Total:',str(net)),('Fator de Lucro:', '1.4'),
             ('Total de Negociações:','30'),
             ('Rebaixamento Máximo do Capital Líquido:', '100.55 (1.01%)')]
    rows=['<tr><td>Relatório do Testador de Estratégia</td></tr>',
          '<tr><td>RoboForex-ECN (Build 6230)</td></tr>']
    rows += [f'<tr><td>{a}</td><td><b>{b}</b></td></tr>' for a,b in pairs]
    rows += [f'<tr><td></td><td>TeacherPanelWidth={panel_width}</td></tr>',
             '<tr><td></td><td>MaxRiskPercentEquity=0.25</td></tr>']
    return ('<html><body><table>'+''.join(rows)+'</table></body></html>').encode()


def make_zip(path, tamper=False):
    payloads={
        'fontes/01_results/ALIEN_EXP018/ALIEN_EXP018.htm':fixture_html(69.32,640),
        'fontes/01_results/EXP_018_V12_1_VERIFIED/EXP_018_V12_1_VERIFIED.htm':fixture_html(-3.24,540),
        'fontes/02_EXPERIMENTOS.csv/EXPERIMENTOS.csv':b'ID;Lucro_USD;Fator_Lucro;Trades\nEXP-018;69.32;1.4;30\n',
        'fontes/13_Tester/ALIEN_CONFLUENCIA_OBSERVER.csv':b'opportunity_id;decision_time_server;symbol;strategy_version;bias_h1_h4;poi;signal;status;reason;spread_points_now;entry_indicative;sl_indicative;tp_indicative;orders_sent\nXAU1;2026.01.01 01:00;XAUUSD;0.1;NEUTRAL;N/A;NONE;ABSTER;Gatilho M1 ausente;6;0;0;0;NO\nAUD1;2026.01.01 01:00;AUDCAD;0.1;NEUTRAL;N/A;NONE;ABSTER;Gatilho M1 ausente;6;0;0;0;NO\n',
    }
    manifest={'schema':'alien-evidencia-v1','files':[{'arcname':k,'bytes':len(v),'sha256':hashlib.sha256(v).hexdigest()} for k,v in payloads.items()]}
    if tamper:
        payloads['fontes/02_EXPERIMENTOS.csv/EXPERIMENTOS.csv']=b'tampered'
    with zipfile.ZipFile(path,'w') as z:
        for n,v in payloads.items(): z.writestr(n,v)
        z.writestr('manifest.json',json.dumps(manifest))


class MT5AnalyzerTests(unittest.TestCase):
    def test_detects_identical_trade_inputs_and_different_results(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'data.zip';out=Path(t)/'out'; make_zip(p)
            mod.analyze(p,out)
            result=json.loads((out/'ALIEN_AUDITORIA.json').read_text(encoding='utf-8'))
            self.assertEqual(result['verified_files'],4)
            self.assertEqual(result['reports_count'],2)
            self.assertTrue(any(w['code']=='MESMAS_ENTRADAS_RESULTADOS_DIFERENTES' for w in result['warnings']))
            self.assertEqual(result['csv']['observers'][0]['xau_rows'],1)
            self.assertTrue((out/'ALIEN_COMPARATIVO.csv').is_file())
            self.assertTrue((out/'ALIEN_AUDITORIA.html').is_file())
            self.assertTrue((out/'ALIEN_AUDITORIA.md').is_file())
            self.assertNotIn('AUD1', (out/'ALIEN_AUDITORIA.md').read_text(encoding='utf-8'))

    def test_rejects_tampered_member(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'data.zip';make_zip(p,tamper=True)
            with self.assertRaisesRegex(ValueError,'SHA256'):
                mod.analyze(p,Path(t)/'out')

    def test_number_pt_and_en(self):
        self.assertEqual(mod.number('1.234,56'),1234.56)
        self.assertEqual(mod.number('-1,234.56'),-1234.56)
        self.assertIsNone(mod.number('N/D'))

    def test_same_experiment_but_different_brokers_is_reused_id_not_reproduction(self):
        x=mod.extract_report('EXP_020_A.htm',fixture_html(-10))
        y=mod.extract_report('EXP_020_B.htm',fixture_html(-20))
        y['broker']='RoboForex-Pro'
        warnings=mod.compare([x,y],{})
        self.assertTrue(any(w['code']=='ID_REUTILIZADO_CENARIOS_DISTINTOS' for w in warnings))
        self.assertFalse(any(w['code']=='MESMAS_ENTRADAS_RESULTADOS_DIFERENTES' for w in warnings))


if __name__=='__main__':unittest.main()
