# Executor quantitativo ALIEN

## Fila quantitativa em operação no Dell

O ALIEN_CENTRAL usa o mesmo supervisor na subpasta `MT5_DELL` para tarefas quantitativas. O Agendador do Windows inicia o processo no logon, com estado SQLite no SSD e cópia consistente no disco de acervo. A fila anterior continua disponível para Intelligence e seu histórico até a transferência do estado.

Envie o envelope `alien.task/v1` para `ALIEN_CENTRAL/MT5_DELL/ENTRADA/pendentes/<id>.json`. A ação é `quant_backtest`. O resultado e o ZIP aparecem em `MT5_DELL/RESULTADOS/task_<id>`. O heartbeat próprio fica em `MT5_DELL/ESTADO/heartbeat.json`. Consulte o ID anterior se o envio for incerto. Para uma nova tentativa, use outro ID.

O modo `remote-spread-sweep` compila o ALIEN V12.1 e testa o filtro `AbsoluteMaxSpreadPts` em 20, 25 e 30 pontos nos MetaTesters do Samsung. O XML e o diário precisam confirmar os três passes remotos. A triagem usa OHLC M1, uma janela curta anterior ao período reservado e o preset versionado. A validação econômica exige checagem separada com ticks reais.


Estado em 26/11/2026. A referência inicial é o commit 90cdaed30e82c4292120f90ba0e0eeccafa6b56f da main. A implementação vive em experimental/alien-quant-executor. Esta sessão confirmou o repositório, o EA V12.1, o preset e a existência do catálogo de ferramentas. A política de aprovação bloqueou a criação de processos locais, incluindo inventário, Python e PowerShell. A pasta do Drive também não pôde ser aberta pela consulta web. A compilação, os testes do MT5, os agentes e a sincronização permanecem pendentes de evidência do Dell. Nenhum resultado quantitativo foi gerado nesta sessão.

## Decisões

- O executor usa Python 3.11 ou superior e Git. Reaproveita o EA, o preset e o parser HTML de tools/parse_and_record_results.py. A interface de compilação e a configuração do Strategy Tester seguem o padrão de tools/Run-Backtest.ps1, com caminhos explícitos, nomes exclusivos e limites de tempo.
- A instalação Windows é portátil, dedicada e vinculada apenas a uma conta demo para acesso ao histórico. Os parâmetros desligam negociação automatizada ao vivo, DLL e MQL5 Cloud. A fila recebe somente parâmetros de teste para o código versionado.
- Uma tarefa por vez. O estado local é a fonte de verdade. Uma interrupção produz estado interrupted na retomada. Para solicitar outra execução, use um identificador novo.
- Capital simulado de USD 10.000, alavancagem 1:100 e período M1. OHLC M1 serve à sondagem. Use ticks reais para a avaliação do ALIEN. Dados de mercado, corretora e histórico podem alterar os resultados.

## Instalação e diagnóstico no Dell

Use um clone separado na branch experimental. Identifique o diretório gravável do terminal portátil já usado para testes. Confirme que contém terminal64.exe e metaeditor64.exe, usa somente conta demo e que o histórico do XAUUSD está disponível. Configure nele o marcador local .alien-tester-only conforme a seção de integração. Cadastre, na aba Agentes desse terminal, os dois endereços do Samsung em 192.168.3.47, portas 2000 e 2001. Insira a senha pelo MT5. Feche o terminal dedicado e o MetaEditor antes de iniciar o executor.

No Drive para computador, identifique o caminho local da [pasta compartilhada](https://drive.google.com/drive/folders/1cl6OyyRZzEN3J6i-PG5JuQtzwkimCcEF). Use uma subpasta exclusiva para esta fila. Os caminhos abaixo são exemplos.

```powershell
git clone --branch experimental/alien-quant-executor https://github.com/vitorcriouabud/alien-quant.git alien-quant-executor
Set-Location alien-quant-executor
$alienPaths = @('--mt5', 'C:\Users\PC\ALIEN_TEST_MT5', '--shared', 'G:\Meu Drive\ALIEN\executor')
python tools/alien_quant_executor.py diagnose @alienPaths
python tools/alien_quant_executor.py once @alienPaths
```


O diagnóstico informa versão do Python, presença do Git, binários, pasta e alcance TCP das duas portas. O alcance TCP sozinho indica conectividade de rede. O primeiro once cria inbox e outbox. Após o teste de aceitação, use watch no lugar de once para consumir a fila continuamente com uma consulta a cada 20 segundos. O Drive para computador é responsável pela transferência.

## Protocolo ChatGPT ↔ executor

Uma tarefa é um arquivo UTF-8 como inbox/qa-001.json. Use um nome de 1 a 48 caracteres alfanuméricos, com hífen e sublinhado permitidos após o primeiro caractere. Forme o JSON completo antes de colocá-lo na pasta.

```json
{"from":"2026.10.21","to":"2026.10.23","mode":"local","symbol":"XAUUSD","model":4}
```


O modelo 1 usa OHLC M1 e o modelo 4 usa ticks reais. Escolha datas com histórico na conta demo e use o símbolo da corretora se ele possuir sufixo. Cada ID é consumido uma vez. O arquivo outbox/qa-001.zip inclui result.json, configuração do Tester, relatório e, quando gerado, summary.json. O relatório HTML é a evidência primária do backtest. Os modos de diagnóstico produzem um XML de passes. Logs locais podem conter dados operacionais e ficam fora do ZIP. O estado local padrão fica em alien-executor-state no terminal portátil. As transições são running, completed, failed e interrupted. result.json inclui horário, revisão, hashes dos insumos e artefatos aplicáveis e código de saída do terminal quando disponível.

## Teste de aceitação

1. Rode diagnose e registre o JSON. Confirme a presença dos executáveis e os dois retornos TCP. Confirme a correspondência da pasta do Drive entre o Dell e a nuvem.
2. Suba o JSON do exemplo no Drive e confirme que ele aparece no inbox local. Rode once, abra o ZIP baixado pela interface web e confira status, revisão, hash e relatório. Compare a leitura do parser com o HTML. Confira no compile.log local o resultado de zero erros.
3. Envie tarefas com IDs distintos, modelo 1 e modos local-passes e remote-passes. Cada uma executa nove passes curtos de uma sonda MQL5 sem chamadas de negociação. Verifique probe_values no manifesto. No diário local do Tester, conte somente agentes com passes concluídos nessa execução. A meta é observar os quatro agentes locais no primeiro teste e as portas 2000 e 2001 no segundo. Se o cache responder passes ou a distribuição não envolver todos os agentes, reteste em outra janela de histórico com passes disponíveis. O modo mixed-passes habilita ambos os grupos.
4. Rode once novamente e confirme que o ZIP anterior mantém o mesmo hash. Envie uma tarefa válida com outro ID e confirme novo ZIP. Para verificar falhas, envie separadamente um JSON com intervalo invertido e confirme status failed no ZIP.
5. Registre neste arquivo os IDs, horários, hashes, resultado de cada verificação e erros observados. Para evidência compartilhável dos agentes, extraia do diário somente as linhas que confirmam passes concluídos por agente e remova dados de conta antes de enviar.

Referências do MT5. [Inicialização com configuração](https://www.metatrader5.com/en/terminal/help/start_advanced/start) · [Agentes e execução de passes](https://www.metatrader5.com/en/terminal/help/algotrading/testing_features)

## Integração com ALIEN_CENTRAL

Use a entrada e os resultados do supervisor existente. A operação integrada usa `supervised` internamente e não requer uma instância de `watch`.

1. Guarde uma cópia de `supervisor.py`, aplique `tools/alien_central_supervisor.patch` na raiz de `ALIEN_CENTRAL` e valide o diff. O patch parte da revisão da Central de 25/11/2026.
2. No computador que executará o supervisor, crie `quant_executor.json` em seu diretório de estado SQLite local com as chaves `checkout` e `installation`, apontando para o clone experimental e para o MT5 portátil DEMO. A ausência desse arquivo deixa a ação de backtest indisponível. O Python do supervisor deve ser 3.11+ e ter Git no PATH.
3. No diretório portátil, configure `.alien-tester-only` como JSON com `server` (texto) e `login` (inteiro) de uma conta comprovadamente DEMO. Mantenha esse arquivo e a autenticação do MT5 no computador autorizado. O pacote leva somente a configuração sem número de conta.
4. Reinicie a instância do supervisor que passará a usar esse ambiente após terminar a tarefa em curso. A fila compartilhada deve ter um único responsável. O modo de análise do Codex continua usando suas regras de aprovação próprias.

Envie o envelope abaixo para `ENTRADA/pendentes/<id>.json`. Consulte `RESULTADOS/task_<id>/RESULTADO.json` e `EVIDENCIAS.zip` na pasta de resultado.

```json
{"schema":"alien.task/v1","id":"v121_xauusd_01","action":"quant_backtest","payload":{"from":"2026.11.24","to":"2026.11.25","mode":"local","symbol":"XAUUSD","model":4}}
```

O supervisor registra falhas no mesmo banco e reaproveita o pacote em tentativas de publicação. Confirme ticks reais e agentes pelo diário da execução. O código de saída e a existência do XML não identificam os agentes responsáveis.
