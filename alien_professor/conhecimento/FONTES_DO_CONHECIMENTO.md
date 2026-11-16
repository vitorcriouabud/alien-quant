# De onde vem cada número do ALIEN_conhecimento.txt

O texto que a IA do Alier consulta (`kit/ALIEN_conhecimento.txt`, instalado em `MQL5\Files\ALIEN_conhecimento.txt`)
só usa números que já estavam nos arquivos do projeto. O teste `teste/check_mocks.py` confere isso.

- Setas nota >= 7 no ouro, 2016-2024: 12.858 trades, acerto 28,9%, média -0,32R, PF 0,59; 2025: -0,22R; 0 de 10 anos positivos → `TESTE_SINAIS.md`.
- Todo BOS por faixa de nota: -0,27 / -0,26 / -0,25 / -0,26 → `TESTE_SINAIS.md`.
- Sem comissão: -0,17R (A) e -0,20R (B); risco mediano 2,0–2,5 pontos → `TESTE_SINAIS.md`.
- Nota 9-10: +0,02R em 248 trades (t 0,2), -0,10R em 2025 → `TESTE_SINAIS.md`.
- US500 setas -0,17R → `TESTE_SINAIS.md`.
- Cesta de índices ~3,8% ao ano, queda máxima ~7,6%; AIBOTFX perdeu → `DIARIO_DO_PROJETO_2026-11-15.md`.
- VO3: "Deu lucro de 2016 a 2024 (poucos trades), perdeu em 2025, e um único dia carregou 14,5% do lucro." → `alien-research/REVISAO_REPOS.md` (pesquisa de 15/11/2026; frase copiada aqui).
- Horários, comando, velas, Trading in the Zone → `conhecimento/ALIER_PROMPT_CONHECIMENTO.txt` e `conhecimento/LOGICA_DO_PRECO_REGRAS.md`.
- Hipóteses do laboratório e critério (>= 200 operações, queda até 20%) → `conhecimento/HIPOTESES_LAB.md`.
