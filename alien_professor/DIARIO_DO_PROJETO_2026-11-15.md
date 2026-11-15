# Diário do projeto ALIEN — 15/11/2026

Resumo simples do que a gente aprendeu, onde chegou e o que vem agora.

## Onde estamos hoje
- **Versão 12.3 — agente Alier**, na branch `alien-professor-v12-3` (nunca na `main`; o V11 da `main` não foi mexido).
- O robô é um **assistente e uma ferramenta de disciplina**, não uma máquina de dinheiro. No kit pessoal ele vem em **modo assistente**: analisa, avisa e conversa, mas não manda ordem.
- Telegram ao vivo com o robô: avisos sozinhos (varrida de liquidez, mudança de estrutura CHoCH/BOS, toque em bloco de ordens, VWAP, aviso 15 min antes de notícia forte e o resultado depois), conversa livre sobre qualquer assunto, foto e áudio pela Gemini, memória, botões fixos, resumo de domingo 20:00 (Brasília).
- Instalação e atualização em dois cliques: `INSTALAR.bat` e `ATUALIZAR.bat` (baixa do GitHub). Suas chaves ficam em `MQL5\Files\ALIEN_config.txt` e nunca são apagadas.

## O que os testes mostraram (a verdade)
- **Sinais automáticos no ouro:** em 10 anos de dados, **sem vantagem** — perdeu em média cerca de **-0,32R por trade**. Por isso o ouro fica só como assistente.
- **Cesta de índices (ALIEN_INDICES_V1):** cerca de **3,8% ao ano** com **queda máxima de ~7,6%** no teste. Pouco, e **ainda não provado ao vivo**.
- **Robô AIBOTFX (recuperação):** perdeu dinheiro. Lição: **evitar recuperação e martingale** (dobrar a mão depois de perder). Também nada de grade.
- Regras que ficam: alvo mínimo de 1,5 vez o risco no AUTO, conta real só se você ligar, números só do que o gráfico mostra.

## Sobre as IAs
- **Kimi K3:** muito forte, mas a API é **paga** (crédito mínimo de 1 dólar, ~1 a 2 centavos por pergunta). Não roda no notebook de 8 GB.
- **Kimi K2:** também não roda no notebook, e os modelos K2 vão ser desligados até o fim de dezembro.
- **Conclusão:** as **duas Gemini grátis bastam**. IA mais inteligente explica melhor, mas não faz o trade dar mais certo.

## Os PDFs que você mandou (os arquivos NÃO estão aqui, por direito autoral)
- **Lógica do Preço** (Rodrigo Carvalho): o mais útil. Feito para opção binária; as regras foram adaptadas para o ouro no MT5, com stop e alvo. Resumo em `conhecimento/LOGICA_DO_PRECO_REGRAS.md` e o texto que o Alier consulta em `conhecimento/ALIER_PROMPT_CONHECIMENTO.txt`.
- **ICT (kill zones):** veio duas vezes; os horários já estão no robô (com o horário de verão de Nova York).
- **"J2P"**: na verdade é o livro de candlestick do Debastiani.
- **115 páginas:** "Trading in the Zone", do Mark Douglas (psicologia).
- **Wattles** ("A Ciência de Ficar Rico"): mentalidade, não entra no robô.
- Regras que mais valem: o **comando** (primeira vela de um movimento novo) com reação nos 50% do corpo; rompimento só vale com **corpo**, não pavio; operar em **Londres** e na **abertura de NY**; não operar consolidação apertada; nunca entrar com alvo menor que o risco.

## As 8 hipóteses para o laboratório de domingo (nenhuma provada)
Detalhes em `conhecimento/HIPOTESES_LAB.md`.
1. Reação no 50% do comando, em Londres ou NY.
2. Reteste depois do rompimento de corpo de um micro-lote.
3. Pullback no alinhamento nova alta/baixa + nova posição.
4. Caçada da faixa da Ásia e reversão na abertura de Londres.
5. OTE de 62% a 70% do swing de Londres, na abertura de NY, a favor do viés do dia.
6. Máximas ou mínimas iguais, depois rompimento de corpo.
7. Comando de reversão no extremo versus comando no meio da pernada.
8. Não operar consolidação apertada; só rompimento + reteste.

Critério igual para todas: lucro médio maior que zero **depois dos custos**, pelo menos 200 operações, queda máxima até 20%, testado em 2026 sem reotimizar.

## Próximos passos
1. Usar **2 a 3 meses só na demo**, com o Alier como assistente.
2. **Juntar dados:** os diários `ALIEN_alertas_log.csv` e `ALIEN_disciplina.csv` (backup semanal automático).
3. **Laboratório de domingo:** testar uma hipótese por vez, com custo real.
4. **Sem funções novas** por enquanto: o que falta é tempo de dado, não código.
5. Guardar todo mês uma parte do que entra na barbearia, fora do trade.

## Como você gosta que as coisas sejam
- Tudo **fácil**: instalador de dois cliques, sem configurar nada na mão.
- **Sem travas**: nada bloqueia você sem você querer (a pausa depois do stop vem desligada). Só ficam os avisos e a proteção de conta real.
- Explicação **curta, em português simples**.
