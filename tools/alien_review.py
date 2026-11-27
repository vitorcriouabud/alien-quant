"""Revisões de pesquisa DEMO, com entradas numéricas e sem comandos vindos da fila."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROUTES = {"amostra": ("codex-business", "dell"), "custos": ("antigravity", "dell"),
          "replicacao": ("abacus", "samsung"), "evidencia": ("codex-pessoal", "dell")}
QUESTIONS = {
    "amostra": "A contagem sozinha permite concluir vantagem robusta?",
    "custos": "O saldo apos os custos informados e positivo?",
    "replicacao": "Estao presentes ticks reais e ao menos uma operacao para iniciar a replica?",
    "evidencia": "Uma unica amostra prova vantagem fora da amostra?",
}
KEYS = {"tipo", "trades", "resultado_bruto_centavos", "custos_centavos", "ticks_reais_pct"}


def envelope(job):
    if type(job) is not dict or set(job) != KEYS or job.get("tipo") not in ROUTES:
        raise ValueError("revisao_invalida")
    for key, lo, hi in (("trades", 0, 1000000), ("resultado_bruto_centavos", -10**9, 10**9),
                        ("custos_centavos", 0, 10**9), ("ticks_reais_pct", 0, 100)):
        if type(job[key]) is not int or not lo <= job[key] <= hi:
            raise ValueError("metrica_invalida")
    digest = hashlib.sha256(json.dumps(job, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"schema": "alien.task/v1", "id": "rev_" + digest[:32], "action": "agent_review", "payload": job}


def review(job, work):
    agent, machine = ROUTES[job["tipo"]]
    prompt = ("Pesquisa DEMO. Sem ferramentas, arquivos ou ordens. Responda somente SIM ou NAO. "
              + QUESTIONS[job["tipo"]] + " Metricas: " + json.dumps(job, ensure_ascii=True))
    env = os.environ.copy()
    for key in ("OPENAI_API_KEY", "CODEX_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "ABACUS_API_KEY"):
        env.pop(key, None)
    if agent.startswith("codex-"):
        env["CODEX_HOME"] = str(Path.home() / (".codex-vtr-business" if agent == "codex-business" else ".codex"))
        exe = Path(os.environ["LOCALAPPDATA"]) / "Programs/OpenAI/Codex/bin/codex.exe"
        args = ["--no-daemon", "exec", "--ignore-user-config", "--ephemeral", "--skip-git-repo-check",
                "--sandbox", "read-only", "-o", "resposta.txt", prompt]
    elif agent == "antigravity":
        exe = Path(os.environ["LOCALAPPDATA"]) / "agy/bin/agy.exe"
        args = ["--mode", "plan", "--sandbox", "--disable-slash-commands", "--print-timeout", "50s", "-p", prompt]
    else:
        exe = shutil.which("abacusai.exe") or shutil.which("abacusai.cmd")
        args = ["-p", prompt, "--permission-mode", "plan", "--output-format", "text"]
    if not exe or not Path(exe).is_file():
        raise ValueError("cli_ausente")
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=work, prefix="revisao-") as tmp:
        try:
            proc = subprocess.run([str(exe), *args], cwd=tmp, env=env, timeout=75,
                                  stdin=subprocess.DEVNULL, capture_output=True, check=False)
        except subprocess.TimeoutExpired:
            raise ValueError("tempo_excedido") from None
        if proc.returncode:
            err = proc.stderr.decode("utf-8", errors="replace").lower()
            if re.search(r"quota exceeded|rate.limit.exceeded|usage limit reached", err):
                raise ValueError("cota_atingida")
            if re.search(r"access is denied|acesso negado|permission denied|os error 5", err):
                raise ValueError("acesso_negado")
            if re.search(r"not_authenticated|not logged in|not authenticated", err):
                raise ValueError("autenticacao_indisponivel")
            if re.search(r"network|connection|connect:|transport|unreachable", err):
                raise ValueError("conexao_indisponivel")
            raise ValueError("cli_falhou")
        answer = (Path(tmp, "resposta.txt").read_text(encoding="utf-8-sig") if agent.startswith("codex-")
                  else proc.stdout.decode("utf-8")).strip().strip(".").upper()
        if answer not in {"SIM", "NAO", "NÃO"}:
            raise ValueError("formato_inesperado")
        return {"agente": agent, "maquina": machine, "parecer": "NAO" if answer == "NÃO" else answer}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("tipo", choices=ROUTES)
    p.add_argument("--executar", action="store_true")
    p.add_argument("--work", type=Path, default=Path.cwd() / "operacao" / "testes_cli")
    a = p.parse_args()
    task = envelope({"tipo": a.tipo, "trades": 6, "resultado_bruto_centavos": 200,
                     "custos_centavos": 240, "ticks_reais_pct": 100})
    if not a.executar:
        print(json.dumps(task))
    else:
        try:
            print(json.dumps(review(task["payload"], a.work)))
        except (ValueError, OSError) as error:
            print(json.dumps({"agente": ROUTES[a.tipo][0], "erro": str(error) if type(error) is ValueError else "io_indisponivel"}))
            raise SystemExit(1)
