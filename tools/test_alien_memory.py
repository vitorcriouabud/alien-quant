from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
from types import SimpleNamespace
import unittest

import alien_memory as mem


def fixture(agent="Codex", step=1):
    return {"schema": "alien.memory/v1", "agente": agent, "tarefa": "ensaio", "etapa": step,
            "utc": "2026-01-02T03:04:05Z", "natureza": "observacao", "motivo": "Conferir o fluxo.",
            "versao": None, "responsavel": agent, "proximo_passo": "Conferir o recibo.",
            "limitacoes": "Dados de teste.", "decisoes": ["Usar o recibo."],
            "descobertas": ["Fila acessível."], "erros": ["Amostra incompleta."],
            "resultados": ["Entrada conferida."], "pendencias": ["Revisar cobertura."],
            "evidencias": ["dell:ensaio_de_teste"]}


class MemoryTests(unittest.TestCase):
    def setUp(self):
        t = tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.local = Path(t.name)
        self.central = self.local / "Central"
        self.central.mkdir()
        self.master = self.central / "MEMORIA_MESTRE_ALIEN.md"
        self.master.write_bytes(b"master\n")
        (self.central / "MT5_DELL/ESTADO").mkdir(parents=True)
        self.state = self.central / "MT5_DELL/ESTADO/RETOMADA_MEMORIA.md"

    def cli(self, *args):
        return subprocess.run([sys.executable, "-I", "-X", "utf8", str(Path(mem.__file__)),
                               "--central", str(self.central), *map(str, args)],
                              capture_output=True, encoding="utf-8")

    def test_four_agents_and_fresh_process(self):
        for agent in sorted(mem.AGENTS):
            e = fixture(agent)
            draft = self.local / "draft.json"
            draft.write_text(json.dumps(e), encoding="utf-8")
            self.assertEqual(self.cli("registrar", draft).returncode, 0)
        self.assertEqual(self.cli("atualizar").returncode, 0)
        got = self.cli("retomar")
        self.assertEqual(got.returncode, 0)
        self.assertEqual(got.stdout.rstrip(), self.state.read_text(encoding="utf-8").rstrip())
        self.assertEqual(got.stdout.count("### "), 4)
        self.assertEqual(self.master.read_bytes(), b"master\n")

    def test_retries_concurrency_and_synced_copies(self):
        e = fixture()
        with ThreadPoolExecutor(8) as pool:
            names = list(pool.map(lambda _: mem.submit(self.central, e), range(16)))
        self.assertEqual(len(set(names)), 1)
        path = mem.folder(self.central) / names[0]
        shutil.copyfile(path, path.with_name(path.stem + " (1).json"))
        self.assertEqual(mem.events(self.central), ([e], [], 0))
        mem.refresh(self.central)
        first = self.state.stat().st_mtime_ns
        mem.refresh(self.central)
        self.assertEqual(first, self.state.stat().st_mtime_ns)

    def test_conflict_and_new_step(self):
        e = fixture()
        mem.submit(self.central, e)
        changed = dict(e, proximo_passo="Verificar outra fonte.")
        with self.assertRaises(mem.Invalid):
            mem.submit(self.central, changed)
        # Dois notebooks desconectados podem criar variantes antes de sincronizar.
        data = mem.canonical(changed)
        p = mem.folder(self.central) / f"{mem.event_id(e)}-{hashlib.sha256(data).hexdigest()}.json"
        p.write_bytes(data)
        self.assertEqual(mem.events(self.central), ([], [mem.event_id(e)], 0))
        mem.submit(self.central, fixture(step=2))
        self.assertEqual(len(mem.events(self.central)[0]), 1)
        self.assertEqual(len(list(p.parent.glob("*.json"))), 3)

    def test_closure_and_partial_or_modified_file(self):
        e = fixture()
        name = mem.submit(self.central, e)
        closed = dict(fixture(step=2), pendencias=[], proximo_passo="Etapa encerrada.")
        mem.submit(self.central, closed)
        state = mem.render(self.central)
        self.assertNotIn("Revisar cobertura.", state.split("## Histórico")[0])
        self.assertIn("Revisar cobertura.", state.split("## Histórico")[1])
        d = mem.folder(self.central)
        (d / "partial.tmp").write_bytes(b"{")
        (d / name).write_bytes(mem.canonical(dict(e, motivo="Alterado.")))
        self.assertEqual(mem.events(self.central), ([closed], [], 1))

    def test_native_drive_note_and_materialized_copy(self):
        e = fixture()
        data = mem.canonical(e)
        digest = hashlib.sha256(data).hexdigest()
        directory = mem.folder(self.central)
        directory.mkdir(parents=True)
        pointer = directory / f"{mem.event_id(e)}-{digest}.gdoc"
        pointer.write_text(json.dumps({"doc_id": "offline_fixture_id"}))
        self.assertIn("Registros nativos", mem.render(self.central))
        self.assertIn("offline_fixture_id", mem.render(self.central))
        mem.submit(self.central, e)
        self.assertNotIn("Registros nativos", mem.render(self.central))
        pointer.rename(directory / f"{mem.event_id(e)}-{'a' * 64}.gdoc")
        text = mem.render(self.central)
        self.assertIn("Etapas em conflito: codex-ensaio-000001", text)
        self.assertNotIn("Revisar cobertura.", text)

    def test_private_material_rejected_before_publication(self):
        for key, value in (("motivo", "senha: exemplo ficticio"),
                           ("erros", ["Bearer FAKE"]), ("resultados", ["https://a.invalid/?x=fake"]),
                           ("evidencias", ["drive:ghp_" + "x" * 35]), ("desconhecido", "fake"),
                           ("responsavel", "valor fora da lista"), ("pendencias", ["meu@email.invalid"])):
            event = dict(fixture(), **{key: value})
            draft = self.local / "draft.json"
            draft.write_text(json.dumps(event), encoding="utf-8")
            proc = self.cli("registrar", draft)
            self.assertNotEqual(proc.returncode, 0)
            self.assertNotIn(str(value), proc.stderr + proc.stdout)
        self.assertFalse(mem.folder(self.central).exists())

    def test_hook_from_supervisor_patch_invokes_local_writer(self):
        patch = Path(mem.__file__).with_name("alien_memory_supervisor.patch").read_text(encoding="utf-8")
        first_hunk = patch.split("@@")[2]
        method = textwrap.dedent("\n".join(line[1:] for line in first_hunk.splitlines() if line.startswith("+")))
        scope = {"json": json, "Path": Path, "subprocess": subprocess, "sys": sys}
        exec(compile(method, "supervisor.patch", "exec"), scope)
        state = self.local / "local-state"
        state.mkdir()
        (state / "quant_executor.json").write_text(json.dumps({"checkout": str(Path(mem.__file__).parents[1])}))
        supervisor = SimpleNamespace(central=self.central / "MT5_DELL", local_state=state,
                                     workspace=self.central, log_event=lambda *args: self.fail(str(args)))
        e = fixture()
        mem.submit(self.central, e)
        scope["refresh_shared_memory"](supervisor)
        self.assertIn(mem.event_id(e), self.state.read_text(encoding="utf-8"))
        self.assertEqual(self.master.read_bytes(), b"master\n")

    def test_projection_of_real_supervisor_schema_without_payload(self):
        r = {"schema": "alien.result/v1", "task_id": "task_unit", "action": "diagnose",
             "status": "completed", "completed_utc": "2026-01-02T05:00:00Z",
             "input_sha256": "c" * 64, "result": {"raw": "PRIVATE_FIXTURE"},
             "summary": "PRIVATE_FIXTURE", "errors": ["PRIVATE_FIXTURE"]}
        for root in [self.central, self.central / "MT5_DELL"]:
            p = root / "RESULTADOS/task_unit/RESULTADO.json"
            p.parent.mkdir(parents=True)
            p.write_text(json.dumps(r), encoding="utf-8")
        invalid = self.central / "RESULTADOS/task_bad/RESULTADO.json"
        invalid.parent.mkdir()
        invalid.write_bytes(b"{")
        result = mem.render(self.central)
        self.assertIn("samsung", result)
        self.assertIn("dell", result)
        self.assertIn("Recibos inválidos omitidos: 1", result)
        self.assertNotIn("PRIVATE_FIXTURE", result)
        self.assertNotIn("task_unit", result)


if __name__ == "__main__":
    unittest.main()
