# REGRAS OPERACIONAIS INSTITUCIONAIS - ALIEN LAB (GOAT FUNDED TRADER)

Este documento define as regras invariantes e diretrizes operacionais absolutas para o ecossistema ALIEN no MetaTrader 5.

## 1. Ativo e Símbolo Obrigatório
- O símbolo oficial de negociação na Goat Funded Trader é estritamente **`XAUUSD.x`**.
- O símbolo genérico `XAUUSD` está permanentemente desativado na corretora e nunca deve ser usado em gráficos, scripts ou ordens.

## 2. Arquitetura Dual-MT5 Isolada
- **Conta 1 ($5,000 Oficial - Fase 1):**
  - Diretório: `C:\Program Files\Goat Funded MT5 Terminal`
  - Login: `315462944` @ `GoatFunded-Server`
  - Magic Number: `802092`
  - Lote Fixo: `0.08` | Meta Diária: `$60.00` | Disjuntor Diário: `$100.00`
- **Conta 2 ($25,000 Competição):**
  - Diretório: `C:\Goat_MT5_25K` (Executado estritamente com flag `/portable`)
  - Login: `436271843` @ `GoatFunded-Server2`
  - Magic Number: `802095`
  - Lote Fixo: `0.35` | Meta Diária: `$350.00` | Disjuntor Diário: `$500.00`
- Ambas as instâncias possuem arquivos de configuração, relatórios MQL5 e capturas de tela segregados.

## 3. Gestão Anti-Boost e Preservação de Drawdown
- É terminantemente proibido o aumento agressivo dinâmico de lotes (escalada sem evidência quíntupla) em contas de avaliação e mesa proprietária.
- As operações são regidas por Lote Base Proporcional e Trava Automática de Meta Diária (`StopOnDailyProfitTarget = true`).
- A meta diária batida encerra imediatamente novas entradas até o próximo pregão.

## 4. Janelas Operacionais e Sessões (Killzones)
- Operações a mercado são autorizadas exclusivamente entre **08:00 e 18:00 UTC** (05:00 às 15:00 BRT), correspondentes às sessões de Londres e Nova York.
- Entradas durante a madrugada ou sessão asiática são bloqueadas por disciplina quantitativa.
- Filtro de notícias nativo do MT5 (`EnableNewsFilter = true`) bloqueia novas entradas 15 minutos antes e depois de divulgações de alto impacto dos EUA.

## 5. Persistência de Processos no Windows
- Processos de suporte de longa duração (MT5, Living Core e Watchdog) devem ser lançados delegando para o serviço de sistema `WmiPrvSE.exe` (via WMI `Win32_Process.Create`) para evitar terminação acidental por Job Objects de sessões de terminal.
