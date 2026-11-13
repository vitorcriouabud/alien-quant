# Auditoria de replay ALIEN — somente leitura

Esta pasta e uma **camada de auditoria**, nao um novo robo nem um setup.
Ela nao altera o MT5, nao importa `MetaTrader5`, nao envia ordens e nao
precisa de `pip install` (Python 3.9+).

## Como rodar no Windows

No terminal, dentro da pasta do repositorio:

```powershell
python research/audit_replay_v02.py "C:\CAMINHO\trades_replay.csv" --expect-count 93 --expect-mean -0.364 --expect-pf 0.537
```

O programa tenta localizar a coluna **R liquido por trade** pelos nomes
mais comuns. Se nao encontrar, **para** e mostra os cabecalhos reais.
Entao use o nome exato, por exemplo:

```powershell
python research/audit_replay_v02.py "C:\CAMINHO\trades_replay.csv" --r-col "NOME_EXATO_DA_COLUNA" --time-col "NOME_EXATO_DO_HORARIO" --id-col "NOME_EXATO_DO_ID" --expect-count 93 --expect-mean -0.364 --expect-pf 0.537 --output "C:\CAMINHO\auditoria_v02.json"
```

Os nomes entre aspas sao **exemplos**, nao afirmacoes sobre o layout do
CSV v0.2, que nao estava disponivel no repositorio. A coluna deve conter
**R liquido individual**, nao preco, USD ou pontos. O custo de 7+2 pontos
foi apenas uma hipotese do replay e nao e recalculado por este programa.

## O que ele verifica

- SHA-256 do CSV, numero de trades, soma/media/mediana de R;
- profit factor em R, drawdown cumulativo em R e dependencia dos
  tres maiores trades vencedores;
- identificadores duplicados, valores invalidos, cronologia fora de
  ordem, timezone ausente e dados insuficientes;
- intervalo bootstrap de media R **por dia** quando ha >=10 datas;
- divergencia versus N=93, media=-0,364 e PF=0,537 com tolerancia
  de arredondamento.

**O que ele nao verifica:** validade do replay original, causalidade,
ticks executaveis, custo de corretora, fills, duplicatas sem ID,
sobreposicao de posicoes, oportunidades censuradas, out-of-sample ou
lucro futuro. Nao e uma prova de edge, mesmo se todos os testes passarem.

## Testes sinteticos

```powershell
python -m unittest discover -s research -p "test_*.py" -v
```

Testes nao dependem do CSV do usuario nem de MT5. O workflow
`.github/workflows/alien-research-audit.yml` executa a mesma suite
quando a PR e aberta. Testes sinteticos verificam o auditor, **nao**
o desempenho do setup.

Leia [a decisao e o gate](DECISAO_E_GATE_V02.md) antes de criar novos EAs.
