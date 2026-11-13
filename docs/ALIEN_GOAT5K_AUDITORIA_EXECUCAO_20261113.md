# Auditoria ALIEN GOAT5K — 13/11/2026

**Fonte:** ZIP privado `ALIEN_GOAT5K_RISK_20261113_110711.zip`. Os arquivos brutos do usuario permanecem fora do repositorio.

- MT5 **MetaQuotes-Demo**, nao Goat, XAUUSD M1, 21/10/2026–07/11/2026, deposito **US$5.000**, alavancagem 1:100.
- HTML reportou **17.455 barras**, **5.651.752 ticks**, qualidade 100% de ticks reais, **0 ordens**.
- Checksums SHA256 dos 4 arquivos HTML, preset e 2 CSV conferiram com o manifesto. MQ5/EX5 nao estavam no ZIP para verificação independente.
- 1025 registros de eventos, 211 registros de outcomes: **89 OPEN, 89 desfechos, 33 SEM_PIVO_LOCAL**. 61 candidatos M5 e 28 M1 em 60 sweeps distintos.
- Stop M5: 6 TP/40 SL/12 TIMEOUT/3 GAP_TIMEOUT, stop mediano 431 pts.
- Stop local M1: 5 TP/20 SL/2 TIMEOUT/1 GAP_TIMEOUT; mediana 334 pts (no conjunto pareado, M5 mediana 403,5).
- Funil stop 35–180 pts: M5 3/61, M1 4/28. Spread <=25 pts: 16/61 e 9/28. Espaco para 4R: 13/61 e 9/28. Todos os filtros combinados **0/89**.
- Gate individual simulado 0,25% de US$5.000 = **US$12,50**: 87 candidatos dentro, 2 rejeitados (US$16,25 e US$147,18); o maior stop foi **14.693 pts**.
- Guarda preventiva de floating abaixo de **US$40**: 88 dentro individualmente, 1 vetado. **Nao e um teste de risco combinado de posicoes shadow**: o campo de perdas flutuantes existentes foi **zero em todos os candidatos**, porque le apenas posicoes reais do testador.
- Piso diario ilustrativo US$4.800 e referencia fixa US$5.000. Sem ordens, a equity nao variou. **Reset diario da Goat e portfolio virtual NAO foram simulados**.
- Comissao 5 USD/lote roundtrip e spread utilizados neste backtest sao **suposicoes**, spread da MetaQuotes-Demo. A conta Goat, sua variante 1% Floating, fase, status e custos reais requerem confirmacao.

**Decisao:** O teste verifica mecanismos de registro/risco individual mas **nao valida estrategia operavel nem conformidade de risco combinado**. Preservar software atual em modo observador. Nao relaxar filtros para forcar ordens. Antes de pesquisar nova variante, obter cotacoes Goat view-only, confirmar regras no dashboard, comissao de ida/volta e EA autoria; so depois avaliar holdout fora da amostra. Nao rodar no desafio real.

**Arquivo derivado de resultados auditados; nao publicar CSVs integrais, relatorios de conta ou credenciais.**
