# LEIA PRIMEIRO, IA: contexto do projeto ALIEN (para qualquer IA que pegar este repositório)

Escrito em 15/11/2026 (horário de Brasília) pelo Grok Bot. Leia tudo antes de propor qualquer coisa. Responda o Vitor **em português do Brasil**, simples e direto.

## 1. Quem é o Vitor
- Barbeiro, trader autodidata. Opera **MT5** no **XAUUSD (ouro)** e em índices (**.US500Cash, .USTECHCash, .DE40Cash**).
- Corretora: **RoboForex ECN** (conta demo 67316641 usada nos testes). Comissão do ouro ~US$ 20 por milhão por lado (~US$ 16 por lote ida e volta); índices ~US$ 5 por milhão por lado.
- Hora do servidor RoboForex = hora de Nova York + 7.
- Mesa proprietária **Goat 2-Step 1% Floating, US$ 5.000**:
  - Fase 1: meta 8%. Fase 2: meta 6%. Cada fase exige 3 dias com lucro ≥ 0,5%.
  - Perda diária 4% (sobre o maior entre saldo e equity às 17h de NY). Perda máxima 10% estática (piso US$ 4.500).
  - **Perda flutuante somada de US$ 50 encerra a conta na hora.**
  - VPS/VPN proibidos. O EA tem de ser dele. Sem martingale, grid ou hedge.
  - Detalhes e fontes: `pesquisa_grokbot/alien-research/GOAT.md`.
- Ele está cansado e frustrado depois de muitos robôs. Quer **um robô que opere** e um "professor" que o ajude no M1. Seja honesto e gentil: **nunca prometa lucro**.

## 2. Objetivo
1. Passar na Goat e ter renda com trading, sem estourar a regra dos US$ 50 flutuantes.
2. Ter ferramentas que ajudem na decisão: leitura do gráfico, disciplina, notícias, Telegram.

## 3. O que já foi testado: cerca de 2.364 tentativas, todas registradas
| Tema | Resultado | Onde |
|---|---|---|
| ALIEN V11 SCALPER (EA dele) | O lucro de agosto a outubro era **artefato de ticks gerados**. Com ticks reais (RoboForex só tem ticks reais a partir de 30/10/2026): −24,31, PF 0,60. Cinco correções testadas, nenhuma passou. | `alien-research/REAL_TICKS_V11.md`, `DIAGNOSTICO_V11.md` |
| Ouro: setups SMC/ICT, sweep, FVG, ORB, sessões, M1/M5, alvos altos, literatura | **Nenhuma vantagem depois dos custos.** | `RESULTS.md`, `RESULTS_V2.md`, `OURO_FOCO.md`, `LITERATURA.md`, `TIRO_ALTO.md`, `DESLOCAMENTO.md`, `FRENTES.md`, `MERCADO.md` |
| **Cesta de índices** (RSI2 + IBS no diário: US500, Nasdaq, DAX) | **A única coisa positiva:** ~**3,8% ao ano**, queda máxima ~**7,6%**, **PF 1,28** no MT5 com swap real. | `alien-indices/TESTE.md` |
| Bug do swap na pesquisa | O swap estava ~1000× menor (datas do pandas em µs divididas por ns). A pesquisa rodou praticamente **sem swap**: 6,2% ao ano viraram 3,8%. Corrigido. | `alien-indices/TESTE.md` §4 |
| Sinais do ALIEN PROFESSOR (nota ≥ 7) | Teste pré-registrado. Ouro: −0,32R por trade (12.858 trades, 0/10 anos positivos). US500: −0,17R. **A nota não separa trades bons de ruins.** | `alien-professor/TESTE_SINAIS.md` |
| Robô AUTO no testador do MT5 (XAUUSD M1) | Ticks reais de 30/10 a 14/11: 13 trades, +US$ 158 (amostra pequena). 2025 com ticks gerados: perdeu (PF 0,25; sem a trava de DD: PF 0,96 e queda de 31%). | `alien-professor/README_PT.md` §8 |
| Tendência multi-mercado, Goat em Monte Carlo | Swap do CFD come a tendência. Passar na Goat com a vantagem real leva **anos** (mediana 1,5 a 2,5). | `TENDENCIA_MULTI.md`, `GOAT.md` |

Regra da casa: **toda mudança de regra depois de ver o resultado é uma tentativa nova.** Pré-registre antes, separe in-sample, validação e período intocado, use custos reais da ECN e ticks reais quando houver.

## 4. Ferramentas (o que cada uma faz)
- **ALIEN_PROFESSOR** (indicador, `alien-professor/`, sem nenhuma função de ordem):
  - Painel amarelo e preto com MTF D1–M1 (ALINHADO/CONFLITO), liquidez (PDH/PDL, semana, Ásia/Londres/NY, topos e fundos iguais), varridas, BOS/CHoCH e FVGs (M5/M15/H1).
  - Nota 0–10 com semáforo; plano com lote para US$ 45 e checagem do limite Goat.
  - PARE POR HOJE, **calendário econômico do MT5** (USD/EUR) e linha de honestidade.
- **ALIEN_PROFESSOR_AUTO** (EA): opera os sinais do professor.
  - Travas: risco fixo, 1 posição, 2 stops/dia, perda diária, pausa no DD de 15%, filtros de spread, notícia e horário, SL/TP junto com a ordem. **Conta real bloqueada por padrão.**
  - *InpTradeEnabled=false* = **modo assistente** (não opera).
  - **Chat de duas vias no Telegram:**
    - Comandos `/analise [símbolo] [TF]`, `/status`, `/noticias`, `/foto`, `/ajuda`, mais perguntas livres.
    - Memória das últimas 10 mensagens. Pré-aviso 15 min antes de notícia forte. Resumos na abertura de Londres e de NY.
  - **IA:** xAI Grok + Google Gemini no modo AMBAS. As duas analisam, uma terceira chamada une num texto só com VEREDITO COMPRA/VENDA/ESPERAR; se elas divergirem, sai ESPERAR.
  - Diário `ALIEN_diario.csv` e aprendizado `ALIEN_aprendizado.csv`, ambos em MQL5\Files.
- **ALIEN_PROFESSOR_TELEGRAM** (EA "carteiro"): envia os sinais do indicador para o Telegram e não opera.
- **ALIEN_INDICES_V1** (EA, `alien-indices/`): a cesta de índices. Precisa de ~US$ 3.200. **Um mês em demo primeiro.**
- **VIGIA_MT5.ps1**: reabre o MT5 se ele cair. Faz backup diário opcional e sincronização opcional dos CSVs para o repositório privado `bud-central-sync` (pasta `alien_dados/`).
- Pesquisa em Python: `alien-research/code/` (numba). Os dados grandes (parquet da Dukascopy) **não estão no repositório**.

## 5. Como instalar (Windows do Vitor)
1. Baixe o zip do kit (o arquivo `ALIEN_PROFESSOR.zip` com os .ex5 compilados) e rode `INSTALAR.bat`. Ele copia indicador, EAs, robô dos índices e presets para todos os MT5 do PC.
2. No MT5: Ferramentas > Opções > Expert Advisors > permitir WebRequest para `https://api.telegram.org`, `https://api.x.ai` e `https://generativelanguage.googleapis.com`.
3. Para compilar a partir deste repositório: abra o `.mq5` no MetaEditor e aperte F7. Os fontes do AUTO são montados por `alien-professor/tools/build.sh` a partir de `src/`.

## 6. Onde as coisas ficam
- `pesquisa_grokbot/alien-professor/`: fontes (`src/`), os `.mq5` montados, `kit/` (INSTALAR, VIGIA, presets **sem chaves**), `README_PT.md` e `TESTE_SINAIS.md`. Os testes em Python ficam em `teste/` e as ferramentas em `tools/`.
- `pesquisa_grokbot/alien-indices/`: robô dos índices e testes.
- `pesquisa_grokbot/alien-research/`: relatórios `.md` e código da pesquisa.
- **A V11 na `main` não foi tocada.** Não mexa nela.
- Os `.ex5` (binários) não vão para o GitHub nesta branch. Eles estão nos zips do kit.

## 7. Regras de segurança (não negociáveis)
- **Sem martingale, sem grid, sem preço médio.** SL sempre junto com a ordem.
- **Demo primeiro.** Nada em conta real ou na Goat sem o Vitor decidir por escrito. Respeite sempre os US$ 50 flutuantes.
- **Nunca coloque token, chave de API ou senha no repositório**, em zip público, README ou log. As chaves vão só nos parâmetros do MT5 dele ou num kit pessoal que **nunca** sobe para o GitHub.
  - Um token antigo do Telegram vazou em repositórios públicos dele e foi substituído.
- Não "otimize até dar lucro". Seja honesto quando algo não funciona.

## 8. Ideias em aberto (expectativa baixa, testar com protocolo)
1. **V12.2, hipóteses 6 e 7** (impulso/correção e compressão/rompimento no M1 do ouro). Se falharem, encerrar a família.
2. **Conta ou corretora com swap menor (ou swap-free)** para a cesta de índices. Isso pode devolver ~2 pontos de CAGR. Simular antes.
3. **VO3** (volume 2× + corpo forte + rompimento de 20 barras + FVG no M15 do ouro): **só observação.** Foi bem em 2016–24 (67 trades, PF 2,8), perdeu em 2025.
4. **Dados de futuros** (volume real COMEX; tendência com futuros de verdade): fora do alcance da conta CFD hoje.

## 9. Revisão semanal (fazer toda semana)
- Ler `ALIEN_diario.csv` e `ALIEN_aprendizado.csv`, mais o log dos índices (`ALIEN_INDICES_log.csv`).
- Comparar o R acumulado com o esperado do backtest (índices: ~+0,06R por trade, acerto ~70%).
- Alertar se houver 6 perdas seguidas ou DD > 10%. Ver as perdas por motivo (`loss_tag`).
- Conferir se alguma regra Goat chegou perto (flutuante, perda diária).
- Decidir com o Vitor: continuar, pausar ou ajustar. Qualquer ajuste é **tentativa nova**, com teste antes.
