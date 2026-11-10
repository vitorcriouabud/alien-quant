import subprocess

out = subprocess.run(["wmic", "process", "where", "processid=6032", "get", "commandline"], capture_output=True, text=True).stdout
print("PID 6032 commandline:")
print(out)
