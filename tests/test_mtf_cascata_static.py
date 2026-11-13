#!/usr/bin/env python3
"""Guarda ESTATICA basica: nao compila e nao comprova performance MT5."""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "MQL5" / "Experts" / "ALIEN_MTF_CASCATA_OBSERVADOR_V1.mq5"

class MTFObserverStaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_sem_envio_de_ordens(self):
        self.assertNotIn("OrderSend(", self.source)
        self.assertNotIn("trade.Buy(", self.source)
        self.assertNotIn("trade.Sell(", self.source)

    def test_series_somente_candles_fechados(self):
        self.assertIn("CopyRates(_Symbol,timeframe,1,count,bars)", self.source)
        self.assertIn("m1[0].time<g_armedAt", self.source)

    def test_causalidade_fvg(self):
        self.assertIn("m15[j].time+PeriodSeconds(PERIOD_M15)>sweepOpen", self.source)
        self.assertIn("h1[j].time+PeriodSeconds(PERIOD_H1)<=sweepOpen", self.source)

    def test_csv_campos_cabecalho_e_registro(self):
        def args_at(pos):
            start = self.source.index("FileWrite(g_csv", pos)
            body = self.source[start:]
            depth = 0
            quoted = False
            last = body.index("(") + 1
            result = []
            for i in range(last - 1, len(body)):
                c = body[i]
                if c == '"' and (i == 0 or body[i-1] != "\\"):
                    quoted = not quoted
                if quoted:
                    continue
                if c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        result.append(body[last:i])
                        break
                elif c == "," and depth == 1:
                    result.append(body[last:i])
                    last = i + 1
            return result
        data = args_at(0)
        header = args_at(self.source.index("if(FileSize(g_csv)==0)"))
        self.assertEqual(len(data), len(header))
        self.assertEqual(len(data), 22) # handle + 21 colunas

if __name__ == "__main__":
    unittest.main()
