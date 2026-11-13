# EXP-018 — Próxima etapa controlada (13/11/2026)

## O que foi verificado no ZIP original

- Dois relatórios do mesmo XAUUSD M1, janela 21–24/10/2026, modelo reportado de 100% ticks reais.
- `ALIEN_EXP018.htm`: +US$ 69,32, 32 entradas.
- `EXP_018_V12_1_VERIFIED.htm`: −US$ 3,24, 30 entradas.
- Ambos possuem **210 parâmetros de entrada**; apenas duas diferenças explícitas:
  - `TeacherPanelCompactRows`: `true` vs `false`;
  - `TeacherPanelWidth`: `640` vs `540`.
- Comparando a chave `(data/hora, lado, lote, preço de entrada)`: **19 entradas idênticas**, 13 somente no primeiro, 11 somente no segundo.
- Primeira entrada do relatório positivo: **21/10/2026 11:10:03, buy, lote 0.18, 4120.97**.
- Primeira entrada do relatório denominado 'verified': **21/10/2026 11:01:00, sell, lote 0.18, 4124.04**.
- A compra de **11:10:03** existe em ambos, reforçando que são execuções com diferenças localizadas e não apenas uma renomeação de arquivos.

## Hipóteses — NÃO afirmar a causa sem prova

(1) Binários EX5 diferentes; (2) estado interno/global do MT5 ou EA diferente;
(3) efeito de configuração visual/timing; (4) efeitos de cache ou configuração fora dos parâmetros reportados.

Só o relatório HTML não identifica hash do EX5 original. Os 210 parâmetros
quase iguais não provam igualdade de código, execução ou ambiente.

## Próximo experimento obrigatório: EXP-018-REPRO

1. **Não alterar lógica de entrada, nem executar em conta real.**
2. Selecionar um único `ALIEN_V12_1_INSTITUTIONAL.mq5` do GitHub,
   registrar SHA256 fonte; compilar e registrar SHA256 EX5 e build do compilador.
3. Congelar um único preset completo com base no HTML; comparar nomes
   de parâmetros com o código atual; qualquer parâmetro adicional exige
   anotação explícita. O `*.set` publicado atualmente no GitHub contém
   valores que diferem do histórico, então não deve ser reutilizado
   silenciosamente.
4. Usar **somente instalação MT5 portátil de teste** `C:\ALIEN_TEST_MT5`,
   com `Model=4`, XAUUSD M1, 21–24/10, depósito 10K, alavancagem 1:100,
   mesmo servidor/dados e mesmo preset.
5. Executar **duas vezes, sequencialmente**, sem recompilar/alterar
   EX5 e sem trocar o .set. Salvar cada HTM e trade/deal log.
6. Comparar entradas por timestamp, lado, lote e preço; comparar
   hash dos inputs e do EX5, além de indicador de qualidade real dos ticks.
7. Se repetirem exatamente: histórico original tinha variável não controlada.
   Se divergirem: investigar estado/caches/GlobalVariables e dependências
   de gráfico antes de calibrar estratégia.
8. Somente depois tratar SMC-Liquidity como hipótese A/B separada.

## Gate para avançar

Não chamar o V12.1 de reproduzido nem 'versão final' até duas execuções
idênticas produzirem trades idênticos e dados auxiliares verificáveis.

**Privacidade:** armazenar EX5, .set, HTM e logs localmente e compartilhar
apenas nesta conversa; não subir logs ou identificadores de conta ao
repositório público.
