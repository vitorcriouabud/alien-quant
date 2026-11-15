# Evidências de execução

Ambiente em que os comandos abaixo rodaram: Linux, CPython 3.10.22.

Dependências importadas nessa sessão:

- numpy 2.2.6
- pandas 2.3.3
- pytest 9.2.0

`requirements.txt` pede `numpy>=1.26`, `pandas>=2.1`, `pytest>=8.0`. Não há pinagem exata além disso.

`INICIAR_LAB.cmd` exige Python 3.11 no Windows. A prova desta conversa foi feita com 3.10.22. O código usa só sintaxe aceita pelo 3.10. Quem auditar no 3.10 pode chamar `python -m pytest` direto; o `.cmd` recusa essa versão de propósito até alguém o altere.

## Comandos

```text
python3 --version
python3 -c "import numpy,pandas,pytest; print(numpy.__version__, pandas.__version__, pytest.__version__)"
cd /workspace/alien_lab_v1
python3 -m pytest tests -q --tb=short
python3 -m pytest tests -v --tb=short
python3 -m alienlab.proof
```

A saída integral de `pytest -v` está em `evidencias_pytest.txt`. Resultado: 8 passed, exit 0, 0.64 s.

Testes coletados:

1. `test_sweep_is_causal_and_directional`
2. `test_future_mutation_does_not_change_past_signals`
3. `test_doji_has_no_close_quality_signal`
4. `test_h14_h16_direction_and_identity`
5. `test_units_points_versus_price`
6. `test_gap_and_spread_zero_and_pnl`
7. `test_repeatable_hash_and_signals`
8. `test_prev_window_excludes_current_and_future`

`python3 -m alienlab.proof` imprimiu:

```json
{"sell": -1, "buy": 1, "hash": "cf3314529d3562b679fc45706fc22782cc3134ad3d94a08f8bed4064265ece4e", "audit_hash": "cf3314529d3562b679fc45706fc22782cc3134ad3d94a08f8bed4064265ece4e", "claim_level": "exploratory"}
```

 Os produtos originais da prova estão em `resultados_sinteticos/`: `events.csv`, `metrics.csv`, `monthly.csv`, `sessions.csv`, `paired.csv`, `audit.json`, `definitions_frozen.json`, `report.html`, `errors.log`, `proof.json` e o ZIP interno daquela rodada.

Contagem de rótulos nessa prova, todas as grades: INCONCLUSIVE 360, REJECT 30, SURVIVES_SCREEN 5, FRAGILE 1. Os cinco `SURVIVES_SCREEN` são `A_CQ_SELL` em horizontes e custos em que a venda plantada domina. Ver `AUDITORIA_MATEMATICA.md`.

## O que não foi executado

- CSV real de 100.000 candles.
- Qualquer comparação com o ALIEN LAB V0.
- MetaTrader 5, ticks, conta, ordem, V11.
- Comissão efetiva, swap, slippage medido, horário de verão automático.
- Correção para múltiplos testes ou dependência temporal.
