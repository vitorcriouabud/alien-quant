import urllib.request
import json

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"

msg = """🎯 <b>A CONFLUÊNCIA EXATA ENTRE O ROBÔ NO MT5 E A ANÁLISE DO YURI:</b>

Comandante Vitor, excelente pergunta! Aqui está como as duas pontas se cruzam na prática, sem enrolação:

<b>1. O QUE O YURI MARCA NO TRADINGVIEW:</b>
• O Yuri traça as zonas de <b>Order Block</b> (onde os grandes bancos deixam ordens acumuladas).
• O Yuri marca as viradas de estrutura (<b>CHoCH e BOS</b>).
• O Yuri identifica onde os tubarões foram caçar stop dos amadores (<b>Liquidity Sweeps / Stop Hunts</b>).

<b>2. O QUE O ROBÔ NO MT5 FAZ COM ESSAS MARCAÇÕES:</b>
Olha o que está escrito no painel amarelo do seu MT5 agora:
👉 <code>PADRÃO DETECTADO: Aguardando Pegadinha dos Tubarões</code>
👉 <code>FLUXO DOS BANCOS: CONSOLIDADO</code>

Isso significa que <b>o robô usa a MESMA lógica de Price Action que o Yuri estuda</b>:
1. <b>O Robô NÃO entra no meio do caminho:</b> Ele só atira se o preço for nos topos ou fundos estourar a máxima/mínima (a mesma linha que o Yuri marcou como Sweep) e voltar com fluxo institucional.
2. <b>Filtro de Tendência do Yuri:</b> Se o Yuri está vendo alta no M15/H1, o nosso robô no MT5 tem o veto institucional que proíbe ele de abrir venda contra a tendência macro.
3. <b>Execução sem Emoção:</b> O Yuri é o olho humano que acha a região. O robô é o braço mecânico que executa em milissegundos com Stop Loss colado e puxa o Break-even de $0.60 assim que o preço anda a favor.

<b>3. POR QUE PARECEU LENTO OU CRU ATÉ AGORA?</b>
• <b>Madrugada Asiática:</b> O mercado agora está lateral (ATR baixo de 175 pts). Nem o robô nem o Yuri devem operar agora, porque não há liquidez institucional.
• <b>Sincronia ao Vivo:</b> O Yuri acabou de receber o indicador no TradingView. Assim que ele olhar a tela e disser: <i>'Galera, o ouro tá testando o Order Block dos 2.650'</i>, o robô no MT5 vai estar na mesma zona vigiando a rejeição para atirar.

É a união do <b>Olho do Yuri</b> com a <b>Disciplina de Aço do Robô do Vitor</b>! 🔥"""

url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
payload = {"chat_id": CHAT_ID, "text": msg, "parse_mode": "HTML"}

req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req) as resp:
    res = json.loads(resp.read().decode())
    print("Enviado com sucesso! Message ID:", res["result"]["message_id"])
