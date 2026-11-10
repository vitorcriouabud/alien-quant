import urllib.request
import subprocess
import os

url = "https://dl.google.com/edgedl/chrome-remote-desktop/chromeremotedesktophost.msi"
dest = r"C:\Users\notebook\AppData\Local\Temp\chromeremotedesktophost.msi"

print("Baixando Chrome Remote Desktop Host da Google...")
urllib.request.urlretrieve(url, dest)
size = os.path.getsize(dest)
print(f"Download concluido ({size} bytes). Instalando no Windows...")

cmd = ["msiexec.exe", "/i", dest, "/quiet", "/norestart"]
res = subprocess.run(cmd)
print(f"Instalacao finalizada com codigo: {res.returncode}")
