import subprocess

out = subprocess.run(["tasklist", "/v", "/fo", "csv"], capture_output=True, text=True).stdout
for line in out.splitlines():
    if any(k in line.lower() for k in ["python", "terminal", "metaeditor"]):
        print(line)
