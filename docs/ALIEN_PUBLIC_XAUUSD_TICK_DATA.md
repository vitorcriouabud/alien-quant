# ALIEN — ticks públicos XAUUSD sem depender do histórico MT5

## O que esta solução resolve

Para pesquisar o comportamento do ouro e testar hipóteses de mercado, não precisamos esperar o servidor MT5 disponibilizar ticks nem exportar histórico da conta.

Este pacote baixa arquivos semanais de ticks XAUUSD já preparados a partir do feed público da Dukascopy Bank SA. O download usa somente a biblioteca padrão do Python: não precisa instalar Node.js, pandas, requests, conectar conta, informar login ou senha, nem abrir o MT5.

## Como executar

No Windows, dê dois cliques em:

`RUN_ALIEN_XAUUSD_DATA.cmd`

O script baixa os anos 2024, 2025 e 2026 para `DATA/TICKS/<ano>/`. O processo:
- lê o manifesto público de cada ano;
- baixa cada arquivo semanal e seu metadado;
- salva em arquivo temporário antes de finalizar;
- retoma arquivos parciais quando o servidor aceita Range;
- confere tamanho, CRC gzip, cabeçalho, quantidade de linhas, ordem temporal, Ask >= Bid e volumes não negativos;
- preserva arquivos semanais já validados;
- gera `DATA/TICKS/ALIEN_XAUUSD_DOWNLOAD_SUMMARY.json`.

Pode ser interrompido. Execute o mesmo CMD novamente para retomar o que faltar. O script processa um arquivo por vez por worker e não carrega milhões de ticks na memória.

## Cobertura publicada verificada na preparação

- 2024: 56.217.145 ticks, ano completo.
- 2025: 71.403.972 ticks, ano completo.
- 2026: 84.371.369 ticks, com dados publicados até 22/11/2026 (manifesto de 23/11/2026).
- Total de referência: 211.992.486 ticks.

Os números são os manifestos das fontes públicas; o resumo local só marca um ano como verificado depois de conferir todos os arquivos semanais contra os respectivos metadados.

## Formato

`timestamp,ask,bid,ask_volume,bid_volume`

- Timestamp UTC com precisão de milissegundos.
- Bid e Ask em USD por onça troy.
- Volumes indicativos do feed Dukascopy.

## Limitações importantes

1. É um feed OTC da Dukascopy, não o feed idêntico da RoboForex ou de outra corretora. Preços, spread e horário de atualização podem divergir.
2. Os campos de volume são indicativos do feed OTC, não volume negociado em bolsa.
3. Esta base serve para pesquisa de mercado, reconstrução de candles e testes independentes em Python. Não prova o preço de execução da conta demo do usuário.
4. Para reconciliar o resultado monetário de operações já executadas (comissão, swap, fee e fills), aí sim é necessário um extrato de negócios da corretora ou histórico de deals. Essa auditoria é separada e pode ficar para depois.

## Fontes

- 2024: https://github.com/Touhid-HZ/xauusd-tick-data-2024
- 2025: https://github.com/Touhid-HZ/xauusd-tick-data-2025
- 2026: https://github.com/Touhid-HZ/xauusd-tick-data-2026
- Instrumento XAUUSD e disponibilidade histórica Dukascopy: https://www.dukascopy-node.app/instrument/xauusd

Este downloader obtém os arquivos públicos do GitHub raw, sem escrever de volta no repositório e sem enviar dados privados.
