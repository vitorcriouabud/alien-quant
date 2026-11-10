# -*- coding: utf-8 -*-
filepath = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_INSTITUTIONAL.mq5"
with open(filepath, "r", encoding="utf-8") as f:
    text = f.read()

target1 = "if(newBar != barStart)\n   {\n      barStart = newBar;"
repl1 = "if(newBar != barStart)\n   {\n      ChartScreenShot(0, \"ALIEN_LIVE_CONFLUENCE.png\", 1280, 720, ALIGN_RIGHT);\n      barStart = newBar;"

target2 = "lastReason = (direction > 0 ? \"BUY \" : \"SELL \") + SetupName(lastSetup) + \" executada\";"
repl2 = "ChartScreenShot(0, \"ALIEN_LIVE_CONFLUENCE.png\", 1280, 720, ALIGN_RIGHT);\n      lastReason = (direction > 0 ? \"BUY \" : \"SELL \") + SetupName(lastSetup) + \" executada\";"

if target1 in text:
    text = text.replace(target1, repl1, 1)
    print("Target 1 replaced")
else:
    # Try with \r\n
    target1_rn = target1.replace("\n", "\r\n")
    repl1_rn = repl1.replace("\n", "\r\n")
    if target1_rn in text:
        text = text.replace(target1_rn, repl1_rn, 1)
        print("Target 1 replaced (CRLF)")
    else:
        print("Target 1 NOT found")

if target2 in text:
    text = text.replace(target2, repl2, 1)
    print("Target 2 replaced")
else:
    target2_rn = target2.replace("\n", "\r\n")
    repl2_rn = repl2.replace("\n", "\r\n")
    if target2_rn in text:
        text = text.replace(target2_rn, repl2_rn, 1)
        print("Target 2 replaced (CRLF)")
    else:
        print("Target 2 NOT found")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(text)

print("Finalizado add_screenshot!")
