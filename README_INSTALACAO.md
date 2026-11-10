# 👽 ALIEN Observer — Guia de Instalação e Uso

## Fase 1: Professor Observador

---

## 📥 Como Instalar no MT5

### Passo 1 — Copiar o arquivo
1. Abra o **MetaTrader 5**
2. Clique em **Arquivo → Abrir pasta de dados** (ou `Ctrl+Shift+D`)
3. Navegue até: `MQL5\Indicators\`
4. Copie o arquivo `ALIEN_Observer.mq5` para essa pasta

### Passo 2 — Compilar
1. Abra o **MetaEditor** (`F4` no MT5)
2. No painel esquerdo, encontre `Indicators\ALIEN_Observer.mq5`
3. Pressione `F7` para compilar
4. Deve aparecer: `0 error(s), 0 warning(s)`

### Passo 3 — Aplicar no gráfico
1. Volte ao MT5
2. Abra o gráfico **XAUUSD M1**
3. No Navegador (Ctrl+N), procure `ALIEN_Observer`
4. Arraste para o gráfico ou clique duplo

---

## ⚙️ Configurações Recomendadas (XAUUSD M1)

```
=== DETECÇÃO DE LIQUIDEZ ===
Swing Lookback:        20 candles
Sweep Buffer:          5 pontos
Swing Min Strength:    3 candles

=== ESTRUTURA (M1) ===
BOS Lookback:          10 candles
BOS Min Move:          8 pontos

=== RETESTE E DEFESA ===
Retest Window:         15 candles
Defense Body %:        0.60 (60%)
Defense Wick Ratio:    0.40 (40%)

=== FILTROS ===
Max Spread:            25 pontos
Sessão Monitorada:     8h - 21h UTC
```

---

## 🔍 O que o indicador mostra no gráfico

| Elemento | Significado |
|----------|-------------|
| 🔵 Seta azul pequena | Varredura de fundo detectada (possível compra) |
| 🔴 Seta vermelha pequena | Varredura de topo detectada (possível venda) |
| Caixa azul/vermelha | Zona de liquidez varrida |
| Linha tracejada amarela | Nível de BOS/CHoCH confirmado |
| ✅ Seta verde grande | Sinal completo (Defesa confirmada) |
| ❌ Marca cinza | Hipótese invalidada |
| Texto "R:R X.X" | Relação Risco:Retorno hipotética |

---

## 📊 Arquivo CSV gerado

O indicador cria automaticamente um arquivo em:
```
MT5/MQL5/Files/ALIEN_Log_AAAAMMDD.csv
```

**Colunas registradas:**
- `data_hora_sweep` — quando a varredura ocorreu
- `tipo_sinal` — LONG ou SHORT
- `preco_swing` — nível de liquidez varrido
- `extremo_varredura` — ponto mais extremo da varredura
- `nivel_bos` — onde o CHoCH/BOS foi confirmado
- `preco_defesa` — entrada hipotética
- `stop` — stop hipotético
- `alvo` — alvo hipotético (2R inicial)
- `risco_pts` — risco em pontos
- `premio_pts` — prêmio potencial em pontos
- `rr_ratio` — relação risco:retorno
- `spread_pts` — spread no momento do sinal
- `resultado` — SIGNAL_COMPLETE / INVALIDATED / TARGET_HIT / STOP_HIT / RETEST_TIMEOUT
- `hora_utc` — hora UTC (para análise por horário)

---

## 🔎 O que verificar ANTES de confiar nos sinais

Sua tarefa manual nas primeiras semanas:

1. **Olhe cada seta verde** e responda:
   - A varredura faz sentido visualmente? O fundo/topo varrido era mesmo um swing relevante?
   - O CHoCH/BOS realmente mudou a estrutura de curto prazo?
   - O reteste tocou a zona correta?
   - A vela de defesa tem aparência de rejeição real?

2. **Olhe as marcações que NÃO viraram sinal** (STATE_INVALIDATED):
   - Foram invalidadas no momento certo?
   - O preço continuou na direção errada mesmo após a invalidação?

3. **Registre sua avaliação manual** no CSV ou em anotações:
   - `✅ Faz sentido` / `❌ Falso positivo` / `⚠️ Dúvida`

---

## 📋 Missão para o Qwen (Fase 1)

Cole isso no KoboldCpp após ter alguns dados:

```
Você é um pesquisador de sistemas de negociação para MetaTrader 5.
Estamos estudando XAUUSD M1 em conta demo.

Recebi este CSV com sinais detectados pelo ALIEN Observer:
[COLE OS DADOS AQUI]

Sua tarefa:
1. Identifique padrões nos sinais que funcionaram vs falharam
2. Analise se há horários com melhor desempenho
3. Verifique se o R:R médio justifica a taxa de acerto observada
4. Sugira quais parâmetros merecem investigação

NÃO invente resultados. NÃO presuma lucro. Baseie-se apenas nos dados fornecidos.
Responda em português: PADRÕES, ANOMALIAS, PRÓXIMOS TESTES.
```

---

## 🚦 Critério de aprovação da Fase 1

> As marcações fazem sentido visual em **pelo menos 80%** dos casos quando revisadas manualmente.

Só avançamos para a Fase 2 quando isso for confirmado.

---

*ALIEN LAB v1.0 | Fase 1 — Professor Observador*
