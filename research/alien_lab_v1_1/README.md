# ALIEN LAB V1.1 — motor quantitativo de triagem (sem ordens)

Laboratório Python isolado em `research/alien_lab_v1_1/`. **Não modifica a V11**, não se conecta à conta MT5 e não envia ordens. Base: motor V1 entregue pelo Grok; definições A–G mantidas e auditadas com regressões extras. Não usar `SURVIVES_SCREEN` como alegação de lucro.

## O que mudou na V1.1

- Reconhece `time_server` e `spread_points` do CSV original RoboForex; erros de linhas inválidas e desordem rejeitados sem interpolação silenciosa.
- Congela experimento com SHA-256 do CSV, parâmetros, textos das regras e código. A opção `--resume` exige CSV original, marca de completude, eventos íntegros e gera ZIP verificável.
- Reserva/holdout vale por **toda** a operação (sinal até saída). Não é uma amostra nova: o período agosto–novembro/2026 já foi analisado.
- Política experimental `one_per_hypothesis` seleciona operações sem sobreposição **dentro da mesma hipótese e cenário**. Não é uma carteira compartilhada; todas as estratégias competem apenas como pesquisa.
- A família E tem classificação `TIMEZONE_UNVERIFIED` até confirmar conversão UTC/DST da corretora. A opção `--timezone-verified` é uma *declaração manual*, não faz correção automática.
- `paired.csv` informa interseção de eventos; diferença de médias entre grupos diferentes não é efeito causal.
- Grade do `INICIAR_LAB.cmd` limitada a 15 minutos e 10 pontos extras por padrão, para notebook 8 GB; grade ampla pode consumir muita memória.

## Rodar no Windows

Requer Python >=3.10, `numpy`, `pandas` e `pytest` instalados. **Uma única vez**, se as dependências faltarem:

```powershell
python -m pip install -r requirements.txt
```

Depois execute em `cmd.exe`:

```bat
INICIAR_LAB.cmd "C:\CAMINHO\ALIEN_LAB_M1_XAUUSD.csv"
```

Para controle explícito de opções (terminal na pasta do laboratório):

```powershell
python -m alienlab.nightly --csv "C:\CAMINHO\ALIEN_LAB_M1_XAUUSD.csv" --outdir resultados --timestamp-kind server --server-utc-offset 2 --horizons 15 --slippage 10 --position-policy one_per_hypothesis
```

**Atenção:** `--server-utc-offset 2` é hipótese de fuso FIXO, não DST comprovado. A família E não pode ser promovida com isso. Alternativas de validação do fuso exigem investigação da configuração real da corretora e do calendário de verão/inverno.

**Retomar** uma corrida cujos eventos foram gravados integralmente (os demais argumentos precisam ser idênticos):

```powershell
python -m alienlab.nightly --csv "C:\CAMINHO\ALIEN_LAB_M1_XAUUSD.csv" --outdir resultados --timestamp-kind server --server-utc-offset 2 --horizons 15 --slippage 10 --position-policy one_per_hypothesis --resume
```

Se faltar CSV, mudar conteúdo/argumentos/código ou houver `events.csv` incompleto, a retomada falha explicitamente. Isso não é ainda um sistema de checkpoint por *cada hipótese*: interrupção antes de gravar `events.csv` exige um novo processamento em nova pasta/execução.

## Testar

```bash
python -m pytest tests -q
python -m alienlab.proof
```

Arquivos do resultado: `input_manifest.json`, `definitions_frozen.json`, `events_complete.json`, `events.csv`, `metrics.csv`, `paired.csv`, `monthly.csv`, `sessions.csv`, `audit.json`, `report.html`, `errors.log`, e o ZIP final. `input_manifest.json` preserva hashes sem incluir credenciais.

## Segurança e interpretação

A base analisada é M1 OHLC, com volume de ticks. Não fornece execução tick-a-tick, fills reais, stop intrabar, comissão efetiva, swap nem slippage medido. `net_usd` usa `contract_oz` assumido (100 por padrão), **não lucro de conta operando**. A política de uma posição por hipótese não incorpora conta, margem, risco total, exposição entre estratégias ou impacto de ordens. Não usar o resultado para trading real nem para declarar edge comprovado.

Ver [LIMITACOES.md](LIMITACOES.md) e [AUDITORIA_V1_1.md](AUDITORIA_V1_1.md). O antigo laboratório V1 de origem permanece preservado fora desta pasta no pacote original.
