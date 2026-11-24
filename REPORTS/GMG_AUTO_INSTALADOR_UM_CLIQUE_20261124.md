# ALIEN GMG Visual — modo automático (24/11/2026)

Pacote distribuído na conversa: `ALIEN_GMG_AUTOMATICO_TOTAL_V2_20261124.zip`.
SHA256 do ZIP: `b0bbfe04b97eb7bfbb46c32846cb1ae7b1d869e430ae7b8da7538dd14d536b5d`.

## Escopo e entrega

- Contém indicador `MQL5/Indicators/ALIEN_GMG_SMC_VISUAL_V1.mq5`, script autoconfigurador `MQL5/Scripts/ALIEN_GMG_AUTO_ANEXAR.mq5`, PowerShell `INSTALAR_E_ABRIR_GMG_AUTOMATICO.ps1`, arquivo `CLIQUE_AQUI_ALIEN_GMG_AUTO.cmd` e instruções.
- Ao clicar: identifica a instalação MT5 por `origin.txt`, prefere RoboForex e a que já possui o GMG; se houver empate, pede escolha. Valida hashes SHA256 embutidos, preserva versões anteriores de arquivos modificados, copia somente o indicador e o script para as pastas correspondentes, compila os dois no MetaEditor e **bloqueia o avanço se não houver EX5 fresco**.
- Cria uma configuração temporária `[StartUp] Script=ALIEN_GMG_AUTO_ANEXAR` com `[Experts] AllowLiveTrading=0` e inicia o terminal; script localiza XAUUSD/GOLD (incluindo sufixos), reutiliza ou abre gráfico M1 e anexa indicador com `iCustom` / `ChartIndicatorAdd`.
- Verifica `MQL5/Files/ALIEN_GMG_AUTOSTART_RESULTADO.txt` após a inicialização; `OK_ADICIONADO` ou `OK_JA_INSTALADO` demonstra que o script concluiu. Ausência de arquivo NÃO é sucesso.
- Gera relatório `RESULTADO_ALIEN_GMG_AUTO.txt` na Área de Trabalho e cria um atalho persistente para iniciar MT5 com o visual, mas **não registra inicialização automática no Windows**.
- Caso o MT5 já esteja aberto, instala e compila, mas não o encerra à força; orienta fechar normalmente e abrir pelo atalho criado. A configuração de inicialização inclui `Symbol=XAUUSD` como gráfico inicial, conforme o símbolo previamente usado nos testes da conta.
- **Não altera a branch principal, o EA ALIEN V12.1, os presets, saldo, conta ou posições. Não envia ordens.**

## Limitações

O pacote foi validado por inspeção estática e integridade de ZIP, mas **não pôde ser compilado nem executado no Windows/MetaEditor pelo assistente**. A ativação visual automática depende de o MT5 executar `[StartUp] Script`, o que pode falhar se não houver gráfico inicial no perfil. No caso de falha, tratar o relatório como diagnóstico; não afirmar sucesso. O fuso da corretora para as caixas de sessão é um offset fixo configurável, não detecção de DST.

## Fontes técnicas

- https://www.metatrader5.com/en/terminal/help/start_advanced/start — uso de `/config:` e `[StartUp]`.
- https://www.mql5.com/en/docs/indicators/icustom — indicador carregado por `iCustom`.
- https://www.mql5.com/en/docs/chart_operations/chartindicatoradd — anexação via handle ao gráfico.

Observação: desenho de OB/FVG continua sendo **heurístico e educacional**, não validação de edge ou sinal de negociação.
