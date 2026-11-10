import urllib.request
import io
from PIL import Image, ImageDraw

# Criar imagem didática de demonstração
img = Image.new('RGB', (900, 520), color=(15, 20, 30))
draw = ImageDraw.Draw(img)

# Banner superior
draw.rectangle([(0, 0), (900, 50)], fill=(25, 35, 50))
draw.text((25, 18), 'ALIEN CO-PILOTO | ANALISE VISUAL DE SMART MONEY (XAUUSD)', fill=(255, 215, 0))

# Simulação de velas japonesas
candles = [
    (100, 280, 240),
    (180, 240, 290),
    (260, 290, 360),
    (340, 360, 420),
    (420, 420, 470),
    (500, 470, 380),
    (580, 380, 270),
    (660, 270, 200),
    (740, 200, 140)
]
for x, o, c in candles:
    color = (0, 220, 120) if c < o else (255, 75, 75)
    draw.line([(x, min(o,c)-30), (x, max(o,c)+30)], fill=color, width=2)
    draw.rectangle([(x-18, min(o,c)), (x+18, max(o,c))], fill=color)

# Zona da Pegadinha (Sweep de Fundo)
draw.rectangle([(380, 450), (540, 505)], outline=(255, 60, 60), width=3)
draw.text((385, 430), 'PEGADINHA DOS BANCOS (SWEEP)', fill=(255, 90, 90))

# Zona de Entrada Institucional
draw.rectangle([(480, 350), (620, 400)], outline=(0, 220, 120), width=2)
draw.text((500, 405), 'ENTRADA NA PORRADA (DISPLACEMENT)', fill=(0, 220, 120))

# Linha do Alvo 2.1R
draw.line([(100, 140), (850, 140)], fill=(0, 200, 255), width=3)
draw.text((580, 115), 'ALVO INSTITUCIONAL 2.1R (TAKE PROFIT)', fill=(0, 200, 255))

buf = io.BytesIO()
img.save(buf, format='JPEG', quality=95)
img_bytes = buf.getvalue()

token = 'PROTECTED_TOKEN'
chat_id = '-1004385601058'
boundary = 'WebKitFormBoundaryAlienDemo777'

body = io.BytesIO()
body.write(b'--' + boundary.encode() + b'\r\n')
body.write(b'Content-Disposition: form-data; name="chat_id"\r\n\r\n')
body.write(chat_id.encode() + b'\r\n')

caption = "Olha aí galera! Exemplo de como o ALIEN consegue mandar prints aqui no grupo explicando as regiões: mostrando onde teve a pegadinha dos bancos no fundo, onde foi a porrada de compra e onde fica o alvo de 2.1R!"
body.write(b'--' + boundary.encode() + b'\r\n')
body.write(b'Content-Disposition: form-data; name="caption"\r\n\r\n')
body.write(caption.encode('utf-8') + b'\r\n')

body.write(b'--' + boundary.encode() + b'\r\n')
body.write(b'Content-Disposition: form-data; name="photo"; filename="exemplo_analise.jpg"\r\n')
body.write(b'Content-Type: image/jpeg\r\n\r\n')
body.write(img_bytes + b'\r\n')
body.write(b'--' + boundary.encode() + b'--\r\n')

req = urllib.request.Request(
    f'https://api.telegram.org/bot{token}/sendPhoto',
    data=body.getvalue(),
    headers={'Content-Type': f'multipart/form-data; boundary={boundary}'}
)
resp = urllib.request.urlopen(req, timeout=25)
print('Foto didática enviada com sucesso!')
