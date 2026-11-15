# Verificação independente da V1.1 — resultados exploratórios

- Ambiente de execução da auditoria: Python 3; 15 testes Pytest aprovados; prova sintética reproduz `sell=-1`, `buy=1` e hash das definições `cf3314529d3562b679fc45706fc22782cc3134ad3d94a08f8bed4064265ece4e`.
- CSV RoboForex M1: 100.000 candles. SHA-256 `2e49d012df1183a2ad29cb538ccc3df1c38f19c4d67bb7b81e786d84027e7558`.
- Execução da grade reduzida: 15 min, spread zero penalizado/excluído, slippage hipotético 10 pontos, servidor UTC+2 fixo **não confirmado**, `one_per_hypothesis`.
- 168.466 sinais; 336.932 linhas de eventos. Teste e retomada executados com ZIP final verificado.
- Classificações observadas nas 66 grades (2 cenários por regra): `REJECT` 45, `TIMEZONE_UNVERIFIED` 8, `SURVIVES_SCREEN` 5, `FRAGILE` 4, `INCONCLUSIVE` 4. Estas contagens são **triagem da amostra previamente conhecida**, não lucro nem prova de vantagem.
- Pico de memória medido no ambiente de auditoria: aproximadamente 547 MB; tempo ~11 s. Não há garantia dessa duração no notebook Windows.

## Como reproduzir

Instale requisitos uma única vez; na pasta do motor:

```bash
python -m pytest tests -q
python -m alienlab.proof
python -m alienlab.nightly --csv /CAMINHO/ALIEN_LAB_M1_XAUUSD.csv --outdir /CAMINHO/resultado_novo --timestamp-kind server --server-utc-offset 2 --horizons 15 --slippage 10 --position-policy one_per_hypothesis
```

Depois repita com `--resume` e os demais argumentos iguais. Compare os hashes de `input_manifest.json`, `events_complete.json` e do ZIP. Não publicar o CSV nem dados de conta em repositório público.

## Não aprovado

- Sessões de XAUUSD dependem de timezone validado e calendário DST; `E_*` é `TIMEZONE_UNVERIFIED`.
- Retomada no *meio* de uma geração de eventos ainda não existe. Só retoma após `events_complete.json`.
- Não há backtest de MT5 com ticks reais, comissão verificada, stop intrabar ou saldo/posições compartilhadas.
- Não há controle estatístico formal para múltiplas hipóteses; rankings são exploratórios.
