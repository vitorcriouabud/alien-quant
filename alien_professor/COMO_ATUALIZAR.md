# Como atualizar o ALIEN

1. Feche o MetaTrader 5.
2. Descompacte o zip novo e dê dois cliques no **INSTALAR.bat** dele.
3. Abra o MT5, tire o robô do gráfico e arraste de novo **Consultor expert > ALIEN > ALIEN_PROFESSOR_AUTO**.
4. No Telegram, toque em **ℹ️ Status**: tem que aparecer a versão nova.

Sua configuração (token, chat e chaves) fica em `MQL5\Files\ALIEN_config.txt` e **nunca é apagada** pela atualização.

## Pastas do kit
| Pasta / arquivo | O que é |
|---|---|
| `INSTALAR.bat` | instala ou atualiza com dois cliques |
| `SUBIR_GITHUB.bat` | (kit pessoal) manda código e diários pro GitHub, branch alien-dados |
| `config/` | (kit pessoal) seu ALIEN_config.txt, só é copiado se ainda não existir |
| `presets/` | ajustes prontos (seguro, goat) |
| `indices/` | robô dos índices |
| `relatorios/`, `prints/`, `teste/` | resultados dos testes e prints |
| `README_PT.md`, `MUDANCAS.md` | manual e o que mudou |
