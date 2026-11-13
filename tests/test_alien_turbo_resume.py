"""Resume the frozen A-G tester ZIP with H/I only; static safeguards."""
import re
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
PS=ROOT/"tools/RETOMAR_ALIEN_TURBO_H_I.ps1"
AUDIT=ROOT/"tools/audit_alien_turbo.py"

class ResumeSafety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ps=PS.read_text(encoding="utf-8")
        cls.audit=AUDIT.read_text(encoding="utf-8")

    def test_resume_only_h_i_and_never_rerun_a_g(self):
        self.assertIn('$plans=@("H_RR3","I_RISKSIZED")',self.ps)
        self.assertIn('$required=@("A_BASE","B_FREQUENCY","C_ALLDAY","D_MULTI5","E_H1M15","F_M5SWEEP","G_M15FVG")',self.ps)
        self.assertIn('if(@($m.experiments).Count -ne 9)',self.ps)
        self.assertIn('SkipCompile=$true',self.ps)
        self.assertIn('Model=4;',self.ps)
        self.assertIn('Deposit=5000;',self.ps)
        self.assertIn('Period="M1"',self.ps)
        self.assertNotIn('$plans=@("A_BASE"',self.ps)

    def test_ex5_must_be_identical_to_original_and_all_seven_hashes_checked(self):
        for part in (
            'Get-FileHash -LiteralPath $archivedEX5 -Algorithm SHA256',
            'Get-FileHash -LiteralPath $archivedSource -Algorithm SHA256',
            'Get-FileHash -LiteralPath $file -Algorithm SHA256',
            '$ex.ex5_sha256 -ne $m.compiled_sha256',
            '$m.compiled_sha256',
            'Copy-Item -LiteralPath $archivedEX5 -Destination $compiled -Force',
            'FONTE_ATUAL_ANTES_RESTAURACAO.mq5',
            'EX5_ATUAL_ANTES_RESTAURACAO.ex5',
        ):
            self.assertIn(part,self.ps)

    def test_isolated_terminal_only_path_and_graceful_retry(self):
        self.assertIn('function Wait-OnlyIsolatedMT5',self.ps)
        self.assertIn('GetFullPath($_.ExecutablePath) -ieq $expected',self.ps)
        self.assertIn('GetFullPath($current.ExecutablePath) -ieq $expected',self.ps)
        self.assertIn('Stop-Process -Id $thePid -Force',self.ps)
        self.assertIn('$cycle -lt 25',self.ps)
        self.assertIn('RoboForex nao foi tocado',self.ps)
        self.assertNotIn('Stop-Process -Name terminal64',self.ps)
        self.assertNotIn('C:\\Program Files\\RoboForex MT5 Terminal\\terminal64.exe',self.ps)

    def test_risk_inputs_must_be_preserved(self):
        for needle in (
            '$inputs.RiskLimitPct -ne "0.25"',
            '$inputs.RiskMaxUsd -ne "12.50"',
            '$inputs.FloatingSafetyUsd -ne "35.0"',
            '$inputs.EnableTesterOrders -ne "true"',
            '$inputs.InitialDepositUsd -ne "5000.0"',
            '$inputs.MaxLot -ne "0.02"',
            '$inputs.MaxLot -ne "0.05"',
            '$inputs.RewardRisk -ne "3.0"',
            '$inputs.RewardRisk -ne "2.0"',
        ):
            self.assertIn(needle,self.ps)

    def test_keeps_primary_reports_and_marks_resume(self):
        for needle in (
            '$m|Add-Member -NotePropertyName run_name',
            '$m|Add-Member -NotePropertyName original_zip',
            '$m.original_name', # intentionally absent? only run_name exists
        ):
            if needle == '$m.original_name':
                self.assertNotIn(needle,self.ps)
            else:
                self.assertIn(needle,self.ps)
        self.assertIn('Compress-Archive',self.ps)
        self.assertIn('_RETOMADO_',self.ps)
        self.assertIn('$m.experiments+=@($entry)',self.ps)
        self.assertIn('original_run=str(manifest.get("run_name")',self.audit)

    def test_no_unsafe_broker_api(self):
        self.assertNotIn('MetaTrader5.initialize(',self.ps)
        self.assertNotIn('New-Object -ComObject',self.ps)
        self.assertIn('MQL5\\Experts\\ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5',self.ps)

if __name__=="__main__":
    unittest.main()
