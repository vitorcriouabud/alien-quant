# Mais de 30 melhorias sinceras — ALIEN PROFESSOR

Escrito em 15 de novembro de 2026, à tarde (horário de Brasília), para o Vitor. Esta lista **não** repete o que já está no build em andamento (aviso de “Voltei”, notícias locais, número da versão, instalador numa pasta só, tom mais natural, teclado do Telegram, diário em português, horário de Brasília, estado que não some ao reiniciar, modo assistente como padrão, alertas sozinhos, memória, áudio, cobrança de disciplina, foto com explicação e o registro em planilha).

## A verdade nua, antes da lista

Não existe “nível quântico perfeito”. Isso é marketing. O que existe é rigor: escrever a regra **antes** de testar, pagar spread, comissão e escorregão, e só acreditar no que sobrevive num período que o teste nunca viu.

No ouro, a seta com nota 7 ou mais **perdeu em todos os 10 anos** de 2016 a 2025 (cerca de −0,32 R por operação no período principal, zero anos positivos). A nota não separa nada: nota alta perde quase igual à nota baixa. Seguir o sinal no automático, hoje, não é um produto. É um prejuízo antecipado. O valor de verdade do Alier é ler o gráfico, calcular o lote, te avisar e te segurar na disciplina.

A cesta dos índices, no teste longo, deu algo em torno de 3,8% ao ano, com queda máxima perto de 7,6%. É pouco, é frágil, e ainda não foi comprovado ao vivo. Não dá para vender isso como máquina de lucro.

**Vender agora um “robô que ganha no ouro” seria mentira.** Para comercializar com lisura, primeiro precisa de histórico verificado (meses, de preferência mais de um ano), em conta real ou no mínimo numa demonstração pública que não possa ser apagada, e de um enquadramento legal honesto. Sem isso, o máximo responsável é um assistente de estudo — nunca uma promessa de renda.

Esforço: **P** = pequeno (dias), **M** = médio (1 a 3 semanas), **G** = grande (um mês ou mais). Impacto: o quanto isso te ajuda de verdade, não o quanto parece moderno.

---

## 1. Rigor quant e pesquisa

1. **Laboratório com pré-registro:** uma hipótese por semana, escrita antes de rodar, e a regra não muda depois de ver o resultado. Esforço M. Impacto alto.
2. **Teste que anda no tempo (walk-forward):** otimiza num pedaço, valida no pedaço seguinte, e vai deslizando. Se só funciona no passado usado para criar a regra, é ilusão. Esforço M. Impacto alto.
3. **Monte Carlo da curva:** embaralha a ordem dos trades e mede quantas curvas sortudas ficam iguais à sua. Se a sua some no meio do acaso, não tem vantagem. Esforço M. Impacto alto.
4. **Índice de Sharpe deflacionado e correção por muitas tentativas:** em dois anos muita ideia já foi testada; o número “bonito” precisa ser puxado para baixo por isso. Sem isso, qualquer vitória é suspeita. Esforço M. Impacto alto.
5. **Grade de custo honesta:** a mesma regra com spread apertado e largo, comissão da RoboForex, escorregão comum e escorregão de notícia. Se morre com um custo um pouco pior, não serve na vida real. Esforço M. Impacto alto.
6. **Repetir o teste com ticks da RoboForex,** não só da Dukascopy, no ouro e nos índices. Dados de outro corretor mentem no detalhe que paga a conta. Esforço M. Impacto alto.
7. **Detecção de regime** (tendência, lateral, volatilidade alta ou baixa): só entra no robô se passar no laboratório com período cego. Sozinha, é moda — muita gente inventa “filtro de regime” depois de ver o gráfico. Esforço G. Impacto médio (hoje é hipótese, não fato).
8. **Estudo de eventos** (inflação americana, Folha de Pagamento, decisão do Federal Reserve): medir o que o ouro faz na janela, em vez de operar no chute. Esforço M. Impacto médio.
9. **Caderno de hipóteses mortas:** lista pública do que já foi testado e falhou, para não repetir a mesma ideia com outro nome. Esforço P. Impacto médio.
10. **Conta de poder estatístico:** antes de declarar “funciona” ou “não funciona”, dizer quantos trades são precisos. Com 30 operações, quase tudo é ruído. Esforço P. Impacto médio.
11. **Trava de honestidade no laboratório:** depois de ver o resultado, é proibido retocar a nota, o stop ou o horário “só um pouquinho”. Foi assim que o V11 se enganou. Esforço P. Impacto alto.

## 2. Risco e disciplina

12. **Pausa obrigatória depois de um stop** (por exemplo 30 a 60 minutos, ou até o próximo horário bom). Protege mais a cabeça do que mais um indicador. Esforço P. Impacto alto.
13. **Limite de perda da semana e do mês,** além do limite do dia. Um dia ruim já está coberto; uma semana teimosa ainda não. Esforço P. Impacto alto.
14. **O aprendizado não desliga uma faixa com poucos trades.** Trinta operações numa fatia (nota, lado, sessão) é pouco e vicia no acaso. Só sugere ou bloqueia com amostra grande e com um pedaço de histórico que ele não usou para decidir. Esforço M. Impacto alto.
15. **Registrar com um toque se o trade foi planejado, pulado ou improvisado.** Sem isso, o laboratório de domingo mistura o que o método fez com o que você fez nervoso. Esforço P. Impacto alto.
16. **Risco aberto total** no dia em que ouro e índices (ou mais de um gráfico) estiverem juntos: a soma não pode furar o teto. Esforço M. Impacto médio.
17. **Pacote de regras de mesa proprietária** (teto de perda flutuante, horário, lote) só como alerta no modo assistente, até existir histórico ao vivo. Empacotar isso para “operar na mesa” antes da prova é empurrar risco para cima de você. Esforço M. Impacto médio.

## 3. Telegram e experiência de uso

18. **Um toque no Telegram: “fiz”, “pulei” ou “saí do plano”.** Alimenta o diário e a revisão de domingo sem você ter que escrever texto. Esforço P. Impacto alto.
19. **Horário de silêncio** (por exemplo de madrugada, ou no almoço da barbearia): o robô guarda o aviso e manda depois, em vez de te acordar. Esforço P. Impacto médio.
20. **Relatório da semana numa imagem só:** acerto, R total, onde você saiu do plano, horários piores. Mais útil do que planilha crua. Esforço M. Impacto alto.
21. **Comando “o que eu teria feito hoje”:** lista os alertas do dia e o que teria acontecido, sem operar. Serve de treino e de prova. Esforço M. Impacto médio.
22. **Fila de mensagens** se a internet do terminal cair: quando voltar, manda o que ficou preso, sem repetir o mesmo aviso. Esforço M. Impacto médio.
23. **Primeiro uso no próprio Telegram:** ele pergunta o que ainda falta (endereços permitidos no MetaTrader, gráfico certo, modo assistente) e te guia em português. Esforço M. Impacto médio.

## 4. Qualidade da inteligência artificial

24. **A IA responde num formato travado (lado, entrada, stop, alvo, confiança) e o robô é quem escreve em português.** Texto livre inventa preço e enche de formalidade. Esforço M. Impacto alto.
25. **Checagem de alucinação:** se a resposta citar um preço que não está no retrato do gráfico, a frase é cortada ou marcada como inválida. Esforço M. Impacto alto.
26. **Placar visível de acerto da IA** em 15 e 60 minutos (e em R, não só “acertou o lado”). Sem maquiagem. Se ela não ganha do “esperar”, isso tem que aparecer. Esforço M. Impacto alto.
27. **A IA não veta operação** até esse placar ser confiável com amostra grande. Hoje o veto é um interruptor perigoso: troca uma regra clara por um palpite. Esforço P. Impacto alto.
28. **O retrato enviado à IA deve lembrar, toda vez, que a seta histórica do ouro perdeu.** Sem isso, ela tende a vender setup com confiança de jornal. Esforço P. Impacto médio.
29. **Economia das chaves grátis:** a segunda opinião só é chamada quando a primeira vier no limite (compra contra venda, ou confiança baixa). Gasta menos e não mistura duas respostas longas. Esforço P. Impacto médio.

## 5. Confiabilidade e operação do dia a dia

30. **Horário de Nova York com horário de verão.** Hoje a zona de caça está fixa no inverno (UTC−5). No verão americano isso atrasa uma hora e o “horário bom” mente. Esforço P. Impacto alto.
31. **Sessões calculadas pelo fuso do servidor da conta,** não travadas nos números da RoboForex. Se um dia a conta for outra, o relógio quebra em silêncio. Esforço M. Impacto médio.
32. **Chaves e token fora do código:** um arquivo local, fora do GitHub e fora do zip que um dia for vendido. O que está dentro do robô vaza na primeira cópia. Esforço M. Impacto alto (segurança e produto).
33. **Vigia de verdade:** se o MetaTrader, o computador ou a internet cair, um processo à parte avisa no Telegram. Robô parado no silêncio é pior do que robô errado. Esforço M. Impacto alto.
34. **Testes automáticos a cada versão** (lote, risco-retorno mínimo, escape de texto, fusos, “não operar abaixo do risco mínimo”). Evita regressão escondida. Esforço M. Impacto alto.
35. **Cópia de segurança das planilhas de aprendizado** (diário, veredictos, alertas), com data, para uma reinstalação não apagar meses de dado. Esforço P. Impacto médio.
36. **Aviso claro no painel e no Telegram:** o “volume” do ouro no MetaTrader é volume de ticks, não volume real de bolsa. Usar isso como se fosse volume institucional é enganar o olho. Esforço P. Impacto médio.

## 6. Produto e comercialização (caminho legal e honesto)

37. **Enquadramento certo, com advogado de mercado de capitais, antes de cobrar de alguém.** No Brasil, oferecer estratégia pronta que indica hora de entrar e sair em valores mobiliários é atividade de analista e pede credenciamento (orientação da CVM, Ofício-Circular CVM/SIN 2/2019 e Resolução CVM 20). Consultoria personalizada pede autorização de consultor (Resolução CVM 19). Gerir dinheiro de terceiro pede registro de administrador de carteira (Resolução CVM 21). Copytrade pago é tratado como recomendação implícita e também pede analista; a operação do analista copiado deve ficar em simulador (Ofício-Circular CVM/SIN 3/2025). Se o programa só executa regras que o próprio usuário definiu, tende a ser serviço de informática — e essa é a forma mais segura de vender. Ouro em contrato por diferença numa corretora de fora pode ficar numa zona cinzenta, mas o Código de Defesa do Consumidor vale do mesmo jeito, e anúncio de renda fácil é pedra no sapato. Isso não é palpite de código: é consulta jurídica de verdade. Esforço G. Impacto alto.
38. **Histórico verificado e público antes de qualquer venda** (plataforma que não deixa apagar mês ruim, conta visível, período longo). Sem isso, não há produto de trading para vender — há só uma ferramenta de estudo. Esforço G (o tempo é de calendário, não de programação). Impacto alto. **É o obstáculo real.**
39. **Vender o Alier como assistente de leitura, diário e risco, nunca como “robô que lucra”.** A CVM já alerta que expressão de renda certa, rentabilidade garantida ou percentual fixo de ganho é sinal de problema — e um estudo dela mostra que pouca pessoa física ganha com day trade, sem prova de que robô mude isso. Esforço P para o discurso e os avisos; o difícil é respeitar isso na prática. Impacto alto.
40. **Mercado da MQL5 só com aviso pesado, sem teste histórico maquiado e sem vender a seta do ouro como vantagem.** A loja tem regra própria e fatia o preço; não substitui a lei brasileira nem inventa histórico. Esforço M. Impacto médio (renda provável pequena; serve mais de vitrine).
41. **Assinatura, se um dia existir, cobra o assistente** (aviso, conversa, diário, suporte), com contrato em português, o que está incluso, o que não está, e regra clara de reembolso. Não cobra “sinal com taxa de acerto”. Esforço G. Impacto médio — e só depois do item 38.
42. **Cada cliente com as próprias chaves, o próprio bot e a própria licença.** Nada de colocar a sua chave Gemini ou o seu token no zip dos outros. Um servidor no meio, se existir, não guarda senha de corretora. Esforço G. Impacto alto (sem isso, não dá para ter mais de um usuário com segurança).
43. **Porta de entrada e suporte de verdade:** instalação guiada, manual curto, horário de atendimento que você consiga cumprir (você é barbeiro, não mesa de 24 horas), e um canal único de dúvida. Prometer suporte eterno é o que mata produto pequeno. Esforço M. Impacto médio.
44. **Empresa formal (MEI ou microempresa) e nota fiscal antes de receber.** Misturar isso com a conta pessoal e com a mesa proprietária é dor de cabeça fiscal e de conflito de interesse. Esforço M (contador, não código). Impacto alto para quem for vender.
45. **Página, anúncio e grupo sem backtest de festa e sem “nível quântico”.** Se for mostrar número, mostra o período inteiro, a queda máxima, o custo e o que falhou. Mentir no anúncio derruba o produto mesmo que o código seja bom. Esforço M. Impacto alto.

---

## O que é hype (e o que não vamos fingir)

- Mais indicador (ICT, SMC, Bollinger, volume, ordem bloqueada, vazio de valor justo) **não** deixa o ouro lucrativo. Isso já estava no motor e a seta mesmo assim perdeu dez anos.
- “Inteligência artificial que acerta o trade” não foi provada. As duas Geminis grátis ajudam a explicar e a conversar. Não são oráculo.
- Filtro de regime, áudio, foto e painel bonito melhoram o uso. Não criam vantagem estatística.
- Vender agora, com a curva do ouro negativa, seria vender uma história. O caminho honesto é ferramenta de disciplina, ou, no futuro, uma regra que tenha passado no laboratório **e** na conta visível.

## As 5 próximas (nessa ordem)

1. **Fechar o laboratório honesto** (itens 1 a 6 e 11): pré-registro, teste que anda no tempo, Monte Carlo, custo, ticks da corretora, Sharpe deflacionado, trava para não retocar regra. Sem isso, o resto é enfeite.
2. **Um toque no Telegram: fiz, pulei ou saí do plano** (itens 15 e 18), já alimentando a revisão de domingo. É o dado que falta para medir a *sua* vantagem, não a do robô.
3. **Chaves fora do código e vigia se o MetaTrader cair** (itens 32 e 33). Segurança e confiabilidade, inclusive se um dia houver outra pessoa usando.
4. **IA travada e honesta** (itens 24 a 27): formato fixo, preço conferido, placar visível, sem veto.
5. **Relógio certo e enquadramento de produto** (itens 30, 37 e 39): horário de verão, discurso de assistente (não de máquina de lucro), e conversa com advogado só quando — e se — for hora de cobrar. O histórico verificado (item 38) começa agora, em silêncio, não no anúncio.

## Rota realista dos próximos 6 meses

**Mês 1 (novembro a dezembro de 2026).** Terminar o build que já está em curso e pousar estas 5. Você usa só em modo assistente, na demonstração. O laboratório já nasce com a primeira hipótese escrita *antes* de testar (por exemplo: “depois de varrer a mínima da Ásia, o ouro busca a VWAP no horário bom, com risco-retorno mínimo de 1,5, já com custo”). Se falhar, vai para o caderno de hipóteses mortas.

**Meses 2 e 3 (janeiro e fevereiro de 2027).** Coletar o seu diário de verdade: cada alerta, cada “fiz / pulei / saí do plano”, resultado em R. Uma hipótese por semana, no máximo. Nenhuma vai para o automático. No domingo a revisão mostra números seus, não recorte bonito. A IA ganha placar público no seu chat, mesmo que o placar seja feio.

**Mês 4 (março de 2027).** Só o que passou no teste que anda no tempo, com custo e com um período cego (2026 em diante, se ainda estiver lacrado), vai para algumas semanas ao vivo na demonstração, com o vigia ligado. Se nada passar — e essa é a probabilidade maior — o produto continua sendo o assistente de disciplina. Isso não é fracasso. É o projeto te protegendo.

**Meses 5 e 6 (abril e maio de 2027).** Só se o diário ao vivo estiver limpo, com queda suportável, e se um advogado disser que a forma de venda é segura: preparar um beta pequeno ou uma página no Mercado da MQL5 como **ferramenta de estudo**, com aviso pesado, contrato, licença por usuário, cada um com as próprias chaves, e zero promessa de lucro. Se o histórico ainda for curto ou negativo, **não vende**. Espera. O “nível quântico” que presta é esse: ter coragem de não lançar.

O que mais pode dar dinheiro no fim não é um sinal novo. É saber, com número, onde *você* tem vantagem — e ter um produto que ajuda gente a não se destruir no gráfico, vendido sem mentira.
