import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

new_func = """def is_asking_for_chart(text):
    if not text:
        return False
    t = text.lower()
    triggers = [
        "grafico", "gráfico", "print", "foto", "tela", "como ta", "como tá", 
        "ouro", "xau", "entrada", "posicao", "posição", "vendo", "olha aí", 
        "olha ai", "confluencia", "confluência", "situacao", "situação", 
        "mostra", "mercado", "ordem", "sinal", "preço", "preco", "vela", "candle",
        "visao", "visão", "lendo", "esperando", "painel", "hud", "freedom"
    ]
    return any(k in t for k in triggers)"""

content = re.sub(r'def is_asking_for_chart\(text\):[\s\S]*?return any\(k in t for k in triggers\)', new_func, content, count=1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("is_asking_for_chart atualizada com sucesso!")
