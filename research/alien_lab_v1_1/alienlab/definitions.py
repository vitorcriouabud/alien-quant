"""Definições congeladas. O hash deste texto é gravado ANTES de qualquer experimento.

Identificadores H14/H16 originais não são reutilizados para outras regras.
"""

from __future__ import annotations

import hashlib
import json

CANONICAL_RULES = [
    {
        "id": "A_CQ_BUY",
        "family": "A",
        "role": "core",
        "side_rule": "BUY",
        "text": (
            "No fechamento t, somente se H>L: CQ_buy=(C-L)/(H-L) >= cq_min e C>O. "
            "Sem exigência de sweep. Entrada na abertura t+1."
        ),
    },
    {
        "id": "A_CQ_SELL",
        "family": "A",
        "role": "core",
        "side_rule": "SELL",
        "text": (
            "No fechamento t, somente se H>L: CQ_sell=(H-C)/(H-L) >= cq_min e C<O. "
            "Sem exigência de sweep. Entrada na abertura t+1."
        ),
    },
    {
        "id": "A_SWEEP_BUY",
        "family": "A",
        "role": "core",
        "side_rule": "BUY",
        "text": (
            "SL_t = min(L[t-k:t]) apenas os k candles anteriores, sem o candle t e sem o futuro. "
            "Sweep da mínima: L[t] < SL_t e C[t] > SL_t (rejeição, fechou de volta acima). "
            "Hipótese de COMPRA. Não é pivô fractal."
        ),
    },
    {
        "id": "A_SWEEP_SELL",
        "family": "A",
        "role": "core",
        "side_rule": "SELL",
        "text": (
            "SH_t = max(H[t-k:t]) apenas os k candles anteriores. "
            "Sweep da máxima: H[t] > SH_t e C[t] < SH_t. Hipótese de VENDA."
        ),
    },
    {
        "id": "A_SWEEP_CQ_BUY",
        "family": "A",
        "role": "confluence",
        "pairs_with": "A_SWEEP_BUY",
        "side_rule": "BUY",
        "text": "A_SWEEP_BUY e CQ_buy >= cq_min. Mesmo evento precisa satisfazer o núcleo.",
    },
    {
        "id": "A_SWEEP_CQ_SELL",
        "family": "A",
        "role": "confluence",
        "pairs_with": "A_SWEEP_SELL",
        "side_rule": "SELL",
        "text": "A_SWEEP_SELL e CQ_sell >= cq_min.",
    },
    {
        "id": "B_M1_PULLBACK_BUY",
        "family": "B",
        "role": "core",
        "side_rule": "BUY",
        "text": (
            "Regime de alta no M1: (EMA50[t]-EMA50[t-10])/ATR14[t] > slope_thr. "
            "Pullback: L[t] <= EMA21[t] e C[t] > EMA21[t] e C[t] > O[t]. Compra."
        ),
    },
    {
        "id": "B_M1_PULLBACK_SELL",
        "family": "B",
        "role": "core",
        "side_rule": "SELL",
        "text": (
            "Regime de baixa: slope EMA50 < -slope_thr. "
            "H[t] >= EMA21[t], C[t] < EMA21[t], C[t] < O[t]. Venda."
        ),
    },
    {
        "id": "B_M1_PULLBACK_BUY_VOL",
        "family": "B",
        "role": "confluence",
        "pairs_with": "B_M1_PULLBACK_BUY",
        "side_rule": "BUY",
        "text": "B_M1_PULLBACK_BUY e volume relativo (tick_volume / SMA20) > relvol_min.",
    },
    {
        "id": "B_M1_PULLBACK_SELL_VOL",
        "family": "B",
        "role": "confluence",
        "pairs_with": "B_M1_PULLBACK_SELL",
        "side_rule": "SELL",
        "text": "B_M1_PULLBACK_SELL e volume relativo > relvol_min.",
    },
    {
        "id": "B_RANGE_FADE_BUY",
        "family": "B",
        "role": "standalone",
        "side_rule": "BUY",
        "text": (
            "Regime range: |slope| < range_slope e bandwidth < mediana das 100 bandwidths anteriores. "
            "C[t] < banda inferior e CQ_buy >= cq_min. Compra. Não é H16."
        ),
    },
    {
        "id": "B_RANGE_FADE_SELL",
        "family": "B",
        "role": "standalone",
        "side_rule": "SELL",
        "text": (
            "Regime range e C[t] > banda superior e CQ_sell >= cq_min. Venda. Não é H14."
        ),
    },
    {
        "id": "B_H1_PULLBACK_BUY",
        "family": "B",
        "role": "standalone",
        "side_rule": "BUY",
        "text": (
            "Slope da EMA21 em H1 somente da última hora já fechada (existe barra com timestamp >= fim da hora). "
            "A hora em formação não entra. Pullback M1: L<=EMA21_M1, C>EMA21_M1, C>O, slope H1 > 0. Compra."
        ),
    },
    {
        "id": "B_H1_PULLBACK_SELL",
        "family": "B",
        "role": "standalone",
        "side_rule": "SELL",
        "text": "Slope H1 fechado < 0 e rejeição M1 abaixo da EMA21. Venda.",
    },
    {
        "id": "C_BREAK_BUY",
        "family": "C",
        "role": "core",
        "side_rule": "BUY",
        "text": (
            "Compressão: bandwidth[t-1] abaixo do percentil 20 das 120 bandwidths anteriores a t. "
            "Houve compressão em algum dos 5 candles anteriores. "
            "Expansão: C[t] > banda superior e (C-O) > 0.5*ATR14. Compra. ID novo, não é H16."
        ),
    },
    {
        "id": "C_BREAK_SELL",
        "family": "C",
        "role": "core",
        "side_rule": "SELL",
        "text": "Compressão recente e C[t] < banda inferior e (O-C) > 0.5*ATR14. Venda.",
    },
    {
        "id": "C_BREAK_BUY_VOL",
        "family": "C",
        "role": "confluence",
        "pairs_with": "C_BREAK_BUY",
        "side_rule": "BUY",
        "text": "C_BREAK_BUY e volume relativo > relvol_min.",
    },
    {
        "id": "C_BREAK_SELL_VOL",
        "family": "C",
        "role": "confluence",
        "pairs_with": "C_BREAK_SELL",
        "side_rule": "SELL",
        "text": "C_BREAK_SELL e volume relativo > relvol_min.",
    },
    {
        "id": "D_H14_ORIG",
        "family": "D",
        "role": "standalone",
        "side_rule": "SELL",
        "text": (
            "H14 ORIGINAL, inalterado: candle anterior fecha acima da banda superior anterior; "
            "candle atual fecha abaixo da banda superior atual; candle atual é de baixa (C<O). "
            "Sinal de VENDA. Bollinger SMA20, desvio populacional ddof=0, multiplicador 2. "
            "Não é o algoritmo iBands da MetaTrader bit a bit."
        ),
    },
    {
        "id": "D_H16_NO_VOL",
        "family": "D",
        "role": "core",
        "side_rule": "SELL",
        "text": (
            "Variação registrada, NÃO é a H16 original: candle de baixa fecha em ou abaixo da banda inferior "
            "e EMA9 < EMA21. Sem filtro de volume."
        ),
    },
    {
        "id": "D_H16_ORIG",
        "family": "D",
        "role": "confluence",
        "pairs_with": "D_H16_NO_VOL",
        "side_rule": "SELL",
        "text": (
            "H16 ORIGINAL: candle de baixa fecha abaixo ou sobre a banda inferior; "
            "EMA9 abaixo da EMA21; volume relativo (tick_volume/SMA20 incluindo o candle t) > 1.2. "
            "Sinal de VENDA."
        ),
    },
    {
        "id": "E_ASIA_LONDON_CONT",
        "family": "E",
        "role": "core",
        "side_rule": "SIGN_OF_ASIA",
        "text": (
            "Sessões em UTC após conversão explícita. Ásia [00:00, 08:00). "
            "Retorno = último close dentro da janela menos o primeiro open. "
            "Sinal na primeira barra com timestamp >= 08:00 UTC, lado = sinal do retorno asiático "
            "(continuação). Só depois da Ásia ter fechado."
        ),
    },
    {
        "id": "E_ASIA_LONDON_FADE",
        "family": "E",
        "role": "control",
        "pairs_with": "E_ASIA_LONDON_CONT",
        "side_rule": "OPPOSITE_OF_ASIA",
        "text": "Mesmo relógio da Ásia para Londres, lado oposto ao retorno. Controle de direção, não confluência.",
    },
    {
        "id": "E_LONDON_NY_CONT",
        "family": "E",
        "role": "standalone",
        "side_rule": "SIGN_OF_LONDON",
        "text": "Londres [08:00, 14:30) UTC. Sinal na primeira barra >= 14:30 UTC na direção do retorno de Londres.",
    },
    {
        "id": "E_CLOCK_SHIFT_CONT",
        "family": "E",
        "role": "control",
        "side_rule": "SIGN_OF_SHIFT_WINDOW",
        "text": (
            "Controle de horário: janela [02:00, 10:00) UTC, sinal na primeira barra >= 10:00, "
            "mesma regra de continuação. Não é a fronteira Ásia/Londres."
        ),
    },
    {
        "id": "F_SWEEP_RETEST_BUY",
        "family": "F",
        "role": "core",
        "side_rule": "BUY",
        "text": (
            "Sweep causal da mínima em s. Reteste em r, com s < r <= s+12: "
            "L[r] <= SL_s + 0.25*ATR[r] e C[r] > SL_s e C[r] > O[r]. "
            "Sinal só em r. Sem exigir deslocamento."
        ),
    },
    {
        "id": "F_SWEEP_RETEST_SELL",
        "family": "F",
        "role": "core",
        "side_rule": "SELL",
        "text": (
            "Sweep causal da máxima em s. Reteste em r: H[r] >= SH_s - 0.25*ATR[r] e C[r] < SH_s e C[r] < O[r]. Venda."
        ),
    },
    {
        "id": "F_SWEEP_DISP_RETEST_BUY",
        "family": "F",
        "role": "confluence",
        "pairs_with": "F_SWEEP_RETEST_BUY",
        "side_rule": "BUY",
        "text": (
            "Exige deslocamento de alta entre o sweep e o reteste: algum candle d, s<d<r, "
            "com TR[d] > 1.3*ATR14[d], C[d] > O[d] e C[d] > C[s]. Sinal de compra em r."
        ),
    },
    {
        "id": "F_SWEEP_DISP_RETEST_SELL",
        "family": "F",
        "role": "confluence",
        "pairs_with": "F_SWEEP_RETEST_SELL",
        "side_rule": "SELL",
        "text": (
            "Deslocamento de baixa entre sweep e reteste: TR[d] > 1.3*ATR14[d], C[d] < O[d], C[d] < C[s]. Venda em r."
        ),
    },
    {
        "id": "G_DISP_BUY",
        "family": "G",
        "role": "core",
        "side_rule": "BUY",
        "text": (
            "TR[t] > percentil 80 dos 50 TRs anteriores (sem o candle t). "
            "CQ_buy >= 0.70 e C>O. Compra. Volume de ticks não entra."
        ),
    },
    {
        "id": "G_DISP_SELL",
        "family": "G",
        "role": "core",
        "side_rule": "SELL",
        "text": "TR[t] > percentil 80 dos 50 TRs anteriores, CQ_sell >= 0.70 e C<O. Venda.",
    },
    {
        "id": "G_DISP_BUY_VOL",
        "family": "G",
        "role": "confluence",
        "pairs_with": "G_DISP_BUY",
        "side_rule": "BUY",
        "text": "G_DISP_BUY e volume relativo > relvol_min. Volume é intensidade do candle, não fluxo institucional nem ordem dos ticks.",
    },
    {
        "id": "G_DISP_SELL_VOL",
        "family": "G",
        "role": "confluence",
        "pairs_with": "G_DISP_SELL",
        "side_rule": "SELL",
        "text": "G_DISP_SELL e volume relativo > relvol_min.",
    },
]


def definitions_payload() -> dict:
    return {
        "lab": "ALIEN_LAB_V1",
        "version": "1.0.0",
        "point_default": 0.01,
        "point_note": "RoboForex XAUUSD: point=0.01. 1 ponto MT5 = 0.01 de preço. 1.00 de preço = 100 pontos MT5.",
        "usd_note": (
            "USD por lote = variação de preço * contract_oz. "
            "O default contract_oz=100 é hipótese de contrato padrão, NÃO lida do terminal. "
            "0.50 de preço = 50 pontos MT5 = 50 USD por lote de 100 oz, não 0.50 ponto."
        ),
        "entry": "abertura do candle seguinte ao sinal",
        "exit": "fechamento do candle de índice entry_idx + horizonte - 1 (horizonte em minutos M1)",
        "causality": "níveis de sweep usam somente [t-k, t). Sinais usam dados até o fechamento de t.",
        "rules": CANONICAL_RULES,
    }


def definitions_hash() -> str:
    blob = json.dumps(definitions_payload(), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def frozen_document() -> dict:
    payload = definitions_payload()
    payload["sha256"] = definitions_hash()
    return payload
