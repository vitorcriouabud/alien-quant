# Arquivos deixados de fora desta pasta

Motivo geral: dados grandes, binários, logs do testador, ou risco de segredo (token, senha, login da demo).

| Motivo | Quantos | Exemplos |
|---|---:|---|
| saídas brutas do testador (HTML, logs, fitas, arquivos com login no nome) | 220 | `IDX_smoke.htm`, `FINAL_m1_2025_100000-holding.png`, `FIX_F5_m4_FIX_F5_m4.htm` … (+217) |
| parquet/pkl de trades ou barras | 52 | `smc_trades_Z.parquet`, `v2_trades_RF.parquet`, `smc_trades.parquet` … (+49) |
| relatórios grandes do MT5 em alien-indices/relatorios | 19 | `FINAL_100000_log.csv`, `FINAL_rt2025_100000.htm`, `FINAL_cap3_10000.png` … (+16) |
| logs | 14 | `goat_run.log`, `goat_run2.log`, `smc_rerun.log` … (+11) |
| possível segredo: account_login | 3 | `DIAGNOSTICO_V11.md`, `REAL_TICKS_V11.md`, `TESTE.md` |
| saída excluída (.htm) | 3 | `V11_commECN_20260801_20261113.htm`, `V11_comm0_20261102_20261107.htm`, `V11_comm0_20260801_20261113.htm` |
| saída excluída (.png) | 3 | `V11_comm0_20260801_20261113.png`, `V11_comm0_20261102_20261107.png`, `V11_commECN_20260801_20261113.png` |
| CSV/txt grande (477975 bytes) | 1 | `summary_A.csv` |
| CSV/txt grande (168153 bytes) | 1 | `v2_summary_RF.csv` |
| CSV/txt grande (232257 bytes) | 1 | `smc_summary.csv` |
| CSV/txt grande (478675 bytes) | 1 | `summary_B.csv` |
| CSV/txt grande (478596 bytes) | 1 | `summary_B_withflats.csv` |
| CSV/txt grande (472041 bytes) | 1 | `summary_Z.csv` |
| CSV/txt grande (480534 bytes) | 1 | `summary_B_nocap.csv` |
| CSV/txt grande (168403 bytes) | 1 | `v2_summary.csv` |
| CSV/txt grande (227690 bytes) | 1 | `smc_summary_Z.csv` |
| CSV/txt grande (254823 bytes) | 1 | `news_trades.csv` |
| CSV/txt grande (256034 bytes) | 1 | `news_trades_gross.csv` |
| tipo excluído (.ex5) | 1 | `ALIEN_INDICES_V1.ex5` |
| não pedido ou grande (.csv, 187910) | 1 | `research_trades_window.csv` |

A senha da demo nunca foi incluída. O login da demo foi removido de `code/run_mt5_test.sh` (passe `MT5_LOGIN` no ambiente).

Os relatórios `DIAGNOSTICO_V11.md`, `REAL_TICKS_V11.md` e `alien-indices/TESTE.md` entraram com o número da conta demo substituído por `[login da demo omitido]`.
