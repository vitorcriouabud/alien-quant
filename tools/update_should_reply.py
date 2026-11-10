import re

path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_living_core.py"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

new_should_reply = """def should_reply(chat_type, text, msg):
    chat_id = str(msg.get("chat", {}).get("id", ""))
    if chat_type == "private" or chat_id == CHAT_ID_OFICIAL or chat_id == "-1004385601058":
        return True
    t = (text or "").lower()
    if t.startswith("/"):
        return True
    reply_to = msg.get("reply_to_message", {})
    if reply_to.get("from", {}).get("is_bot") or reply_to.get("from", {}).get("id") == 9152893557:
        return True
    keywords = ["alien", "robô", "robo", "copiloto", "co-piloto", "@alienfreedomquantbot", "antigravity", "bot", "mesa", "goat"]
    return any(kw in t for kw in keywords)"""

content = re.sub(r'def should_reply\(chat_type, text, msg\):[\s\S]*?return any\(kw in t for kw in keywords\)', new_should_reply, content, count=1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("should_reply atualizado para sempre responder no grupo oficial!")
