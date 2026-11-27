"""Diário de continuidade ALIEN. Biblioteca padrão, Python 3.11+."""
import argparse
from collections import defaultdict
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import unicodedata
from uuid import uuid4

AGENTS = {"ChatGPT", "Codex", "Abacus", "Gemini"}
KINDS = ("decisoes", "descobertas", "erros", "resultados", "pendencias", "evidencias")
FIELDS = {"schema", "agente", "tarefa", "etapa", "utc", "natureza", "motivo",
          "versao", "responsavel", "proximo_passo", "limitacoes", *KINDS}
SLUG = re.compile(r"[a-z][a-z0-9_-]{0,47}")
COMMIT = re.compile(r"[a-f0-9]{7,40}")
SECRET = re.compile(
    r"pass(?:word|phrase|wd)|senha|secret|segredo|token|bearer|basic\s+\S+|"
    r"api[_ -]?key|access[_ -]?key|credencial|credentials?|private[_ -]?key|"
    r"chave\s+(?:privada|de\s+acesso)|authorization|cookie|://|www\.|"
    r"-----BEGIN|(?:\bAKIA|\bASIA)[A-Z0-9]{16}|\b(?:sk[-_]|gh[pousr]_|github_pat_|"
    r"xox[baprs]-|AIza|eyJ)[\w.-]+|[A-Za-z0-9_+/=-]{32,}|[^\s@]+@[^\s@]+",
    re.I,
)
REF = re.compile(r"(?:git:[a-f0-9]{7,40}|drive:[A-Za-z0-9_-]{10,64}|"
                 r"(?:dell|samsung):[a-zA-Z0-9_-]{1,80})")
ACTIONS = {"quant_backtest", "peer_exchange", "diagnose", "collect", "summarize",
           "analyze_existing_report"}


class Invalid(ValueError):
    """Somente mensagens constantes podem ser mostradas ao usuário."""


def obj(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise Invalid("Campo repetido.")
        out[key] = value
    return out


def read_json(path, limit=32768):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise Invalid("Documento acima do limite.")
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=obj)


def stamp(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value):
        raise Invalid("Data UTC inválida.")
    datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    return value


def prose(value):
    if (not isinstance(value, str) or not 1 <= len(value) <= 360 or value != value.strip()
            or not value.isprintable() or any(c in value for c in '<>[]{}|\x60\\@=')
            or SECRET.search(unicodedata.normalize("NFKC", value))
            or re.search(r"(?:[A-Za-z]?[0-9]){10,}|[A-Za-z0-9]{20,}", value)):
        raise Invalid("Resumo recusado; revise os campos em área privada.")


def valid(e):
    if type(e) is not dict or set(e) != FIELDS or e["schema"] != "alien.memory/v1":
        raise Invalid("Campos ou versão inválidos.")
    if e["agente"] not in AGENTS or e["responsavel"] not in AGENTS | {"Proprietário"}:
        raise Invalid("Agente inválido.")
    if e["natureza"] not in {"observacao", "relato", "hipotese", "plano"}:
        raise Invalid("Natureza inválida.")
    if not SLUG.fullmatch(e["tarefa"]) or SECRET.search(e["tarefa"]):
        raise Invalid("Tarefa inválida.")
    if type(e["etapa"]) is not int or not 1 <= e["etapa"] <= 999999:
        raise Invalid("Etapa inválida.")
    stamp(e["utc"])
    if e["versao"] is not None and not COMMIT.fullmatch(e["versao"]):
        raise Invalid("Revisão inválida.")
    for key in ("motivo", "proximo_passo", "limitacoes"):
        prose(e[key])
    for key in KINDS:
        values = e[key]
        if type(values) is not list or len(values) > 12:
            raise Invalid("Lista inválida.")
        for value in values:
            if key == "evidencias":
                if not isinstance(value, str) or not REF.fullmatch(value):
                    raise Invalid("Referência inválida.")
                # IDs de Drive são opacos. Bloquear prefixos de autenticação conhecidos.
                if re.search(r"(?i)(?:token|secret|password|sk-|gh[pousr]_|github_pat_|AIza|AKIA|ASIA|xox[baprs]-|eyJ)", value.split(":", 1)[1]):
                    raise Invalid("Referência sensível.")
            else:
                prose(value)
    if not any(e[k] for k in KINDS[:-1]) or (e["natureza"] == "observacao" and not e["evidencias"]):
        raise Invalid("Falta conteúdo ou evidência da observação.")
    return e


def event_id(e):
    return f"{e['agente'].lower()}-{e['tarefa']}-{e['etapa']:06d}"


def canonical(e):
    return (json.dumps(e, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def folder(central):
    if not (central / "MEMORIA_MESTRE_ALIEN.md").is_file():
        raise Invalid("Selecione a Central que contém a memória mestre.")
    return central / "MEMORIA" / "eventos"


def submit(central, event):
    e = valid(event)
    path = folder(central)
    path.mkdir(parents=True, exist_ok=True)
    data = canonical(e)
    ident = event_id(e)
    digest = hashlib.sha256(data).hexdigest()
    target = path / f"{ident}-{digest}.json"
    # Mesmo conteúdo converge no mesmo nome; alterações nunca substituem o anterior.
    siblings = list(path.glob(f"{ident}-*.json"))
    if any(p != target for p in siblings):
        raise Invalid("Conflito de etapa. Preserve os registros e use uma nova etapa.")
    if target.exists():
        if canonical(valid(read_json(target))) != data:
            raise Invalid("Arquivo anterior divergente.")
        return target.name
    with tempfile.NamedTemporaryFile(dir=path, prefix=".alien-", suffix=".tmp", delete=False) as f:
        tmp = Path(f.name)
        try:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        except BaseException:
            f.close()
            tmp.unlink(missing_ok=True)
            raise
    try:
        try:
            if os.name == "nt":
                os.rename(tmp, target)  # No Windows, falha quando o destino já existe.
            else:
                os.link(tmp, target)  # Criação atômica sem substituir o conteúdo anterior.
        except OSError:
            if not target.is_file() or canonical(valid(read_json(target))) != data:
                raise
    finally:
        tmp.unlink(missing_ok=True)
    return target.name


def events(central):
    groups = defaultdict(dict)
    bad = 0
    for p in folder(central).glob("*.json"):
        try:
            e = valid(read_json(p))
            ident = event_id(e)
            data = canonical(e)
            # O Drive pode criar cópias com nomes diferentes durante sincronização.
            base = f"{ident}-{hashlib.sha256(data).hexdigest()}"
            if not re.fullmatch(re.escape(base) + r"(?: \([0-9]+\))?\.json", p.name):
                raise Invalid("Nome ou integridade divergente.")
            groups[ident][data] = e
        except (OSError, TypeError, ValueError, RecursionError):
            bad += 1
    result = []
    conflicts = []
    for ident, variants in sorted(groups.items()):
        if len(variants) == 1:
            result.append(next(iter(variants.values())))
        else:
            conflicts.append(ident)
    return sorted(result, key=lambda e: (e["utc"], event_id(e))), conflicts, bad


def receipts(central):
    rows = []
    skipped = 0
    for machine, root in (("dell", central / "MT5_DELL"), ("samsung", central)):
        for p in (root / "RESULTADOS").glob("task_*/RESULTADO.json"):
            try:
                r = read_json(p, 1024 * 1024)
                if not isinstance(r, dict) or r.get("schema") != "alien.result/v1":
                    continue
                if (r.get("action") not in ACTIONS or r.get("status") not in {"completed", "failed"}
                        or r.get("task_id") != p.parent.name
                        or not re.fullmatch(r"task_[A-Za-z0-9_-]{1,80}", p.parent.name)
                        or not re.fullmatch(r"[0-9a-f]{64}", r.get("input_sha256", ""))):
                    raise Invalid("Recibo inválido.")
                # Não copiar payload, caminho, ID escolhido pelo remetente, logs ou texto do resultado.
                key = hashlib.sha256(p.parent.name.encode()).hexdigest()[:16]
                rows.append((stamp(r["completed_utc"]), machine, key, r["action"], r["status"]))
            except (OSError, KeyError, TypeError, ValueError, RecursionError):
                skipped += 1
    return sorted(set(rows)), skipped


def drive_notes(central, records, conflicts):
    """O Drive para computador pode expor Docs apenas como atalhos .gdoc."""
    known = {event_id(e): hashlib.sha256(canonical(e)).hexdigest() for e in records}
    by_key = defaultdict(dict)
    pattern = re.compile(r"((?:chatgpt|codex|abacus|gemini)-([a-z][a-z0-9_-]{0,47})-[0-9]{6})-([0-9a-f]{64})(?: \([0-9]+\))?\.gdoc", re.I)
    for path in folder(central).glob("*.gdoc"):
        hit = pattern.fullmatch(path.name)
        if not hit or SECRET.search(hit[2]):
            continue
        ident, digest = hit[1].lower(), hit[3].lower()
        link = ""
        try:
            metadata = read_json(path, 8192)
            doc_id = metadata.get("doc_id", "") if isinstance(metadata, dict) else ""
            if isinstance(doc_id, str) and re.fullmatch(r"[-_A-Za-z0-9]{10,70}", doc_id):
                link = f" (https://docs.google.com/document/d/{doc_id}/edit)"
        except (OSError, ValueError, RecursionError):
            pass
        by_key[ident][digest] = link or by_key[ident].get(digest, "")
    notes = []
    for ident, variants in sorted(by_key.items()):
        if (ident in conflicts or len(variants) > 1
                or ident in known and known[ident] not in variants):
            conflicts.add(ident)
        for digest, link in sorted(variants.items()):
            if known.get(ident) != digest:
                notes.append(f"- {ident} · {digest}{link}")
    return notes


def render(central):
    records, conflicts, bad = events(central)
    conflicts = set(conflicts)
    notes = drive_notes(central, records, conflicts)
    records = [e for e in records if event_id(e) not in conflicts]
    manifest, skipped = receipts(central)
    lines = ["# Retomada do ALIEN", "", "Leia primeiro MEMORIA_MESTRE_ALIEN.md na Central.",
             "", "## Etapas dos agentes", ""]
    latest = {}
    for e in records:
        key = (e["agente"], e["tarefa"])
        if key not in latest or e["etapa"] > latest[key]["etapa"]:
            latest[key] = e
    lines[4] = "## Pendências por agente e tarefa"
    for e in sorted(latest.values(), key=lambda row: event_id(row)):
        lines.append(f"- {event_id(e)} · {e['responsavel']} · {', '.join(e['pendencias']) or 'sem pendências declaradas'} · {e['proximo_passo']}")
    lines.extend(["", "## Histórico cronológico", ""])
    for e in records:
        lines.extend([f"### {e['utc']} · {event_id(e)}", "",
                      f"{e['natureza']} · responsável {e['responsavel']} · revisão {e['versao'] or 'não informada'}",
                      "", "Motivo — " + e["motivo"]])
        for key in KINDS:
            for value in e[key]:
                if key == "evidencias":
                    kind, ref = value.split(":", 1)
                    if kind == "drive":
                        value = f"[Drive](https://drive.google.com/open?id={ref})"
                    elif kind == "git":
                        value = f"[{ref}](https://github.com/vitorcriouabud/alien-quant/commit/{ref})"
                    else:
                        prefix = ".." if kind == "dell" else "../.."
                        value = f"[{kind} · {ref}]({prefix}/RESULTADOS/task_{ref}/RESULTADO.json)"
                lines.append(f"- {key} — {value}")
        lines.extend(["", "Limitações — " + e["limitacoes"], "Próximo passo — " + e["proximo_passo"], ""])
    if notes:
        lines.extend(["## Registros nativos do Drive a conferir", "",
                      "Abra o documento em MEMORIA/eventos e confira o conteúdo e o hash antes de usar.", "", *notes, ""])
    lines.extend(["## Recibos dos supervisores", "",
                  "UTC · máquina · referência derivada da pasta · ação · estado", ""])
    lines.extend(" · ".join(row) for row in manifest)
    lines.extend(["", f"Registros inválidos omitidos: {bad}. Recibos inválidos omitidos: {skipped}.",
                  f"Etapas em conflito: {', '.join(sorted(conflicts)) or 'nenhuma'}.", ""])
    return "\n".join(lines)


def refresh(central):
    data = render(central).encode("utf-8")
    target = central / "MT5_DELL" / "ESTADO" / "RETOMADA_MEMORIA.md"
    if not target.parent.is_dir():
        raise Invalid("Pasta de estado do Dell indisponível.")
    if target.exists() and target.read_bytes() == data:
        return
    tmp = target.with_name(f".alien-{uuid4().hex}.tmp")
    try:
        tmp.write_bytes(data)
        os.replace(tmp, target)
    finally:
        tmp.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--central", required=True, type=Path)
    cmd = parser.add_subparsers(dest="cmd", required=True)
    cmd.add_parser("retomar")
    cmd.add_parser("atualizar")
    cmd.add_parser("registrar").add_argument("rascunho", type=Path)
    args = parser.parse_args()
    try:
        if args.cmd == "registrar":
            draft = args.rascunho.resolve()
            if draft.is_relative_to(args.central.resolve()):
                raise Invalid("Prepare o rascunho fora da Central.")
            print(submit(args.central, read_json(draft)))
        elif args.cmd == "atualizar":
            refresh(args.central)
        else:
            print(render(args.central))
    except (OSError, KeyError, TypeError, ValueError, RecursionError):
        parser.exit(2, "Operação recusada. Verifique a Central e os dados em área privada.\n")


if __name__ == "__main__":
    main()
