import subprocess
print(subprocess.run(["tasklist"], capture_output=True, text=True).stdout)
