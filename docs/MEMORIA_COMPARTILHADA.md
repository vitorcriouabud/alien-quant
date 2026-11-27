# Memória compartilhada do ALIEN

Ao abrir uma sessão do ChatGPT, Codex, Abacus ou Gemini, leia `MEMORIA_MESTRE_ALIEN.md` na raiz da ALIEN_CENTRAL. Abra `MT5_DELL/ESTADO/RETOMADA_MEMORIA.md` e confira as evidências das tarefas que pretende assumir. Se a visão estiver ausente ou desatualizada, o comando `retomar` reconstrói o estado a partir dos arquivos sincronizados. Considere observações, relatos, hipóteses e planos de acordo com a natureza declarada. Um recibo concluído confirma o processamento da tarefa. A conclusão científica exige consultar a evidência.

## Registrar uma etapa

Cada agente registra sua própria etapa ao decidir, descobrir, errar, entregar um resultado ou deixar trabalho em aberto. Use um nome curto e estável para a tarefa, e um inteiro crescente para a etapa daquele agente nessa tarefa. Em um reenvio, reutilize o mesmo registro completo, inclusive o horário. Para corrigir, crie a próxima etapa, indique a anterior no motivo e declare a lista atual de pendências daquele agente na tarefa. Use uma lista vazia quando elas estiverem resolvidas. Faça a passagem de responsabilidade no próximo passo. Um agente que assume de outro deve mencionar a etapa de origem.

Prepare o JSON em área privada. Escreva um resumo revisado em vez de colar comandos, logs ou conteúdo de relatórios. Referencie só artefatos destinados ao projeto. Use `drive:ID`, `git:SHA`, `dell:ID` ou `samsung:ID` (ID de tarefa sem o prefixo interno `task_`). Os filtros rejeitam campos extras, URLs, caminhos comuns, indicadores de autenticação e formatos de segredo. Uma senha arbitrária pode parecer texto comum. A revisão na origem continua necessária. Nunca coloque um rascunho, credencial ou dado de conta em pasta sincronizada.

```json
{
  "schema": "alien.memory/v1",
  "agente": "Abacus",
  "tarefa": "ensaio-local",
  "etapa": 1,
  "utc": "2026-01-02T03:04:05Z",
  "natureza": "plano",
  "versao": null,
  "motivo": "Conferir a cobertura antes da próxima etapa.",
  "decisoes": ["Revisar a origem dos dados."],
  "descobertas": [],
  "erros": [],
  "resultados": [],
  "pendencias": ["Conferir cobertura."],
  "evidencias": [],
  "limitacoes": "Fonte ainda em revisão.",
  "proximo_passo": "Conferir o relatório da fonte.",
  "responsavel": "Abacus"
}
```

As naturezas aceitas são `observacao`, `relato`, `hipotese` e `plano`. Uma observação exige evidência. Use `null` para uma revisão desconhecida. O responsável pode ser um dos quatro agentes ou `Proprietário`.

Em um checkout com Python 3.11 ou mais recente, passe a pasta sincronizada da Central e o caminho local do rascunho.

```powershell
python -X utf8 tools/alien_memory.py --central "$Central" registrar "$Rascunho"
python -X utf8 tools/alien_memory.py --central "$Central" retomar
```

O primeiro comando valida antes de gravar e devolve o nome exato do evento. Para uma sessão com conector e sem disco sincronizado, execute o mesmo gravador em uma Central temporária privada contendo um arquivo `MEMORIA_MESTRE_ALIEN.md`. Envie somente o JSON validado que o gravador produziu, com o nome devolvido, para `ALIEN_CENTRAL/MEMORIA/eventos`. Leia o arquivo de volta para confirmar. Uma sessão com conector também pode publicar um Google Doc nativo por etapa em MEMORIA/eventos. Revise os campos em memória antes de criar o documento. Use somente o JSON como corpo e o mesmo nome canônico, retirando a extensão .json. Para calcular o hash, ordene as chaves por nome, serialize em UTF-8 sem espaços e com os caracteres Unicode literais, adicione uma quebra LF e aplique SHA-256. Procure primeiro pelo mesmo agente, tarefa e etapa na pasta. Depois de criar, releia o corpo e confira o hash. Quem tiver somente um leitor do Drive pode abrir esses registros diretamente. O supervisor lista os atalhos .gdoc disponíveis no sistema de arquivos para conferência. O corpo de um Doc nativo exige acesso pelo Drive. O gravador também aceita uma cópia local privada do JSON validado e a visão agrupa essa cópia com o atalho correspondente. Se o agente não puder validar o conteúdo, aguarde a conferência de um agente com o gravador antes de publicar. A identidade do autor é declarada pelo agente. O acesso depende das permissões existentes do Drive.

A chave lógica combina agente, tarefa e etapa. O nome inclui o SHA-256 dos campos canônicos. Reenvios iguais contam uma vez. Variantes concorrentes da mesma etapa permanecem preservadas e sinalizadas até a reconciliação por uma nova etapa. Uma entrada com nome ou conteúdo inválido fica fora da visão. O histórico original e as etapas anteriores continuam acessíveis. Os arquivos do Drive dependem das permissões e do histórico de versões do serviço.

## Integração no Dell

Coloque `tools/alien_memory.py` no checkout local configurado em `quant_executor.json`. O patch incremental `tools/alien_memory_supervisor.patch` aplica-se ao `supervisor.py` que já contém a integração `peer_exchange`. Na pasta desse supervisor, use `git apply --check --no-index <caminho-do-patch>` e depois `git apply --no-index <caminho-do-patch>`. O processo carrega a alteração ao iniciar. Coordene a ativação com o proprietário do processo e as tarefas em andamento.

O supervisor do Dell atualiza `MT5_DELL/ESTADO/RETOMADA_MEMORIA.md` em cada ciclo. O mesmo comando pode gerar a visão sob demanda.

```powershell
python -X utf8 tools/alien_memory.py --central "$Central" atualizar
```

A visão junta etapas dos agentes e recibos `alien.result/v1` das duas pastas RESULTADOS. Dos recibos, copia apenas horário, máquina, identificador derivado da pasta, ação conhecida e estado. A referência derivada são os primeiros 16 dígitos do SHA-256 do nome da pasta do recibo em UTF-8. A referência `dell:ID` ou `samsung:ID` de um evento aponta para o manifesto completo. Arquivos JSON incompletos ficam sinalizados na contagem de inválidos e são relidos no ciclo seguinte.

## Validação

```powershell
python -m unittest discover -s tools -p test_alien_memory.py -v
```

Os testes usam pastas temporárias, recibos sintéticos e processos independentes. Para aceitação no Dell, registre uma etapa real, aguarde a próxima atualização do supervisor e confira a abertura da visão no Drive em uma sessão sem histórico.
