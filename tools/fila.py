"""Publica pedidos de revisão DEMO mantendo o protocolo alien.task/v1."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from runpy import run_path
from uuid import uuid4

REVIEW = run_path(str(Path(__file__).with_name("alien_review.py")))


def task_bytes(task):
    return (json.dumps(task, sort_keys=True, separators=(",", ":")) + "\n").encode()


def receipt(central, job):
    task = REVIEW["envelope"](job)
    agent, machine = REVIEW["ROUTES"][job["tipo"]]
    root = central / "MT5_DELL" if machine == "dell" else central
    result = root / "RESULTADOS" / ("task_" + task["id"]) / "RESULTADO.json"
    expected = hashlib.sha256(task_bytes(task)).hexdigest()
    report = {"id": task["id"], "agente": agent, "maquina": machine, "input_sha256": expected,
              "status": "aguardando_recibo"}
    if not result.is_file():
        return report
    body = json.loads(result.read_bytes())
    if (not isinstance(body, dict) or body.get("schema") != "alien.result/v1"
            or body.get("task_id") != "task_" + task["id"] or body.get("input_id") != task["id"]
            or body.get("input_sha256") != expected or body.get("lab_mode") != "DEMO"
            or body.get("action") != "agent_review" or body.get("status") not in {"completed", "failed"}):
        raise ValueError("Recibo diferente da tarefa canônica.")
    if body["status"] == "completed" and (
            not isinstance(body.get("result"), dict) or body["result"].get("agente") != agent
            or body["result"].get("maquina") != machine
            or body["result"].get("parecer") not in {"SIM", "NAO"}):
        raise ValueError("Parecer do recibo não corresponde à rota.")
    report.update(status=body["status"], completed_utc=body.get("completed_utc"),
                  parecer=body.get("result", {}).get("parecer"), recibo=str(result.relative_to(central)))
    return report


def submit(central, job, output=None):
    task = REVIEW["envelope"](job)
    machine = REVIEW["ROUTES"][job["tipo"]][1]
    root = central / "MT5_DELL" if machine == "dell" else central
    directory = output if output is not None else root / "ENTRADA/pendentes"
    if not directory.is_dir():
        raise ValueError("Pasta de destino indisponível.")
    result = root / "RESULTADOS" / ("task_" + task["id"]) / "RESULTADO.json"
    if output is None and result.is_file():
        receipt(central, job)
        return result
    target = directory / (task["id"] + ".json")
    data = task_bytes(task)
    tmp = directory / (".alien-" + uuid4().hex + ".tmp")
    try:
        tmp.write_bytes(data)
        try:
            if os.name == "nt":
                tmp.rename(target)
            else:
                os.link(tmp, target)
        except OSError:
            if not target.is_file() or json.loads(target.read_bytes()) != task:
                raise
    finally:
        tmp.unlink(missing_ok=True)
    return target


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("tipo", choices=REVIEW["ROUTES"])
    p.add_argument("--central", type=Path, required=True)
    p.add_argument("--consultar", action="store_true", help="Consultar e verificar o recibo sem enviar novo pedido")
    p.add_argument("--pasta-de-envio", type=Path, help="Preparar um arquivo local para o conector Drive")
    p.add_argument("--trades", type=int, required=True)
    p.add_argument("--bruto", type=int, required=True, help="Resultado bruto em centavos")
    p.add_argument("--custos", type=int, required=True, help="Custos em centavos")
    p.add_argument("--ticks-reais", type=int, required=True, help="Percentual inteiro")
    a = p.parse_args()
    if a.consultar and a.pasta_de_envio is not None:
        p.error("--consultar e --pasta-de-envio não podem ser usados juntos.")
    job = {"tipo": a.tipo, "trades": a.trades, "resultado_bruto_centavos": a.bruto,
           "custos_centavos": a.custos, "ticks_reais_pct": a.ticks_reais}
    try:
        if a.consultar:
            print(json.dumps(receipt(a.central, job), ensure_ascii=True))
        else:
            print(submit(a.central, job, a.pasta_de_envio))
    except (ValueError, OSError):
        p.exit(2, "Pedido inválido, conflitante ou destino indisponível.\n")
