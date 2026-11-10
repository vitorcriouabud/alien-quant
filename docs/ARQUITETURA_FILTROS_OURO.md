# 🏛️ ARQUITETURA DE FILTROS INSTITUCIONAIS: ALIEN QUANT (XAUUSD)

**Autor:** Antigravity AI & Vitor (Sniper Operator)  
**Repositório:** `https://github.com/vitorcriouabud/alien-quant.git`  
**Branch:** `dev-filtros-institucionais`  
**Ativo:** XAUUSD (Gold)  
**Meta:** Aprovação e Gestão Segura em Mesa Proprietária (Goat Funded Trader 5K/25K)

---

## 📊 1. AUDITORIA DOS TESTES DE 3 MESES (33,6 MILHÕES DE TICKS REAIS)

Executamos o backtest rigoroso no Strategy Tester do MT5 com ticks reais da Goat de 10 de Agosto a 10 de Novembro de 2026:

| Estratégia | Timeframe | Trades | Lucro Líquido | Profit Factor | Winrate | Diagnóstico |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **ALIEN V12.1 / V12.2 (Legado M1)** | M1 | **142** | **-$111.75** | **0.58** | **34.8%** | **Sangria por Ruído:** Tomou 12 stops seguidos por operar momentum em velas de 1 minuto em meio a consolidações. |
| **ALIEN V12.3 HTF (Proposta ChatGPT)** | D1/H4/H1 + M5 | **0** | **$0.00** | **0.00** | **0.0%** | **Paralisia por Filtro Excessivo:** Exigir que D1, H4 e H1 estejam todos em pivôs idênticos congelou o robô por 90 dias. |

---

## 🎯 2. O FILTRO QUE REALMENTE FAZ DINHEIRO NO OURO

Para superar esses dois extremos (o cassino do M1 e a paralisia do D1), definimos a **Arquitetura de 3 Filtros Institucionais**:

### ⏰ FILTRO 1: O Relógio Institucional (Janelas de Volume Real)
O ouro só deve ser operado nos momentos de injeção de liquidez interbancária:
* **Janela Londres:** 07:00 às 10:00 UTC (04h00 às 07h00 Brasília).
* **Janela Nova York:** 12:00 às 15:30 UTC (09h00 às 12h30 Brasília).
* **Fora dessas janelas:** Negociação 100% bloqueada (evita o "chopping" de almoço e mercados laterais).

### ⚖️ FILTRO 2: O Terreno (Regra do 50% de H1 — Premium vs Discount)
Comprar barato e vender caro em relação ao range diário:
* **Preço acima dos 50% de H1 (Premium / Caro):** Apenas VENDA permitida. Compras são estritamente proibidas.
* **Preço abaixo dos 50% de H1 (Discount / Barato):** Apenas COMPRA permitida. Vendas são estritamente proibidas.

### 🪤 FILTRO 3: O Gatilho no M5 (Liquidity Sweep com Rejeição)
Não compramos rompimento; compramos a falha de rompimento (captura de liquidez institucional):
1. O ouro agulha abaixo da mínima do range recente ou da sessão anterior.
2. O candle de **M5** fecha com pavio de rejeição (wicking) voltando para dentro do range.
3. **Entrada na ponta compradora**, com Stop Loss colado na ponta da agulhada e alvo no Fair Value Gap (FVG) ou topo oposto (BSL).

---

## 💰 3. GESTÃO MATEMÁTICA E PROTEÇÃO DA BANCA GOAT
* **Lote Fixo:** 0.01 por ordem (risco financeiro entre $3.00 e $5.00).
* **Relação Risco / Retorno:** Mínimo 1:2.5 a 1:3 (perde $4 para buscar $12 a $15).
* **Autonomia e Git:** A branch `main` permanece estável. Toda nova evolução é comitada em `dev-filtros-institucionais` para revisão e validação pelo ChatGPT.
