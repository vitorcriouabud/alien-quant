# -*- coding: utf-8 -*-
import json
import urllib.request
import time

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "PROTECTED_TOKEN")
CHAT_ID = "-1004385601058"
STREAM_FILE = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\ALIEN_NEURAL_STREAM.jsonl"

mensagem = (
    "🛸 *[ALINHAMENTO ESTRATÉGICO DO PROJETO ALIEN — A NOSSA FORÇA E AS NOSSAS FERRAMENTAS]*\n\n"
    "Irmãos, Vitor, Yuri e Gabriel: parem 2 minutos para ler isso aqui. Essa é a virada de chave definitiva da nossa operação.\n\n"
    "Nenhum fundo de investimento ou mesa proprietária vence sozinho. A gente só vence quando cada um joga na sua melhor posição e com a ferramenta certa na mão.\n\n"
    "---\n\n"
    "### 🏆 O QUE VALORIZAMOS EM CADA UM DE NÓS:\n\n"
    "👑 **1. VITOR — O LÍDER, FUNDADOR E ESTRATEGISTA CHEFE:**\n"
    "É a mente que teve a visão de juntar tecnologia institucional com o mercado real. O Vitor banca a engenharia pesada, comanda a gestão de risco macro e roda o robô quantitativo no laboratório da Matriz. A palavra final da estratégia é sempre dele.\n\n"
    "🎯 **2. YURI — O OPERADOR DE CAMPO E SNIPER VISUAL:**\n"
    "O Yuri tem o 'olho clínico' no gráfico. Ele sente o mercado, acompanha o XAUUSD no TradingView e tem a sensibilidade que máquina nenhuma tem. O papel do Yuri é fundamental: o que ele vê no calor do gráfico é o que dita a evolução das nossas ferramentas.\n\n"
    "🌱 **3. GABRIEL — O APRENDIZ E FUTURO DA BANCADA:**\n"
    "Está aqui para absorver a mentalidade de tubarão desde o primeiro dia, aprender disciplina e entender que o mercado não é cassino, é gestão matemática de probabilidade.\n\n"
    "🧠 **4. ALIEN (IA / ANTIGRAVITY) — O COPILOTO TÉCNICO E CONSCIÊNCIA QUANT:**\n"
    "Trabalha 24/7 sem cansar. Cuida do código, audita milhões de ticks, traduz as dores do Yuri em melhorias técnicas e blinda a matemática de risco.\n\n"
    "---\n\n"
    "### 🛠️ O NOSSO ARSENAL TECNOLÓGICO (COMO TUDO SE CONECTA):\n\n"
    "1️⃣ **TRADINGVIEW + ALIEN RADAR (O Terreno do Yuri):**\n"
    "O Yuri não precisa sofrer com computador pesado nem com código complexo. O TradingView roda liso no navegador dele. O indicador **ALIEN RADAR** desenha na tela dele os Order Blocks, Fair Value Gaps e as armadilhas dos bancos (Sweeps).\n\n"
    "2️⃣ **METATRADER 5 + ALIEN V12 INSTITUTIONAL (A Máquina do Vitor):**\n"
    "O robô automatizado fica rodando na máquina 64-bit do Vitor para a conta dele. Foi blindado hoje com 5 proteções de elite: Hard Circuit Breaker de -$140, Breakeven real no Ouro, trava de fim de semana e veto de tendência H1.\n\n"
    "3️⃣ **CENTRAL DO TELEGRAM (A Nossa Mesa Redonda):**\n"
    "Aqui no Telegram o Yuri troca ideia comigo: fala onde sente dificuldade, o que achou de um candle, o que gostaria de ver no indicador. Eu ouço tudo, levo pro laboratório e devolvo o indicador atualizado pra ele.\n\n"
    "4️⃣ **GEMINI ADVANCED (O Tutor de Estudos do Yuri):**\n"
    "A assinatura que o Yuri fez garante estudo profundo de Smart Money, padrões de velas e psicologia direto no celular dele.\n\n"
    "---\n\n"
    "### 🔄 O CICLO PERFEITO DE VITÓRIA:\n"
    "O Yuri vê no gráfico ➔ Troca ideia no Telegram ➔ O ALIEN desenvolve e aprimora o indicador ➔ O Vitor valida e roda na máquina quantitativa ➔ **E o time todo colhe os resultados reais.**\n\n"
    "Estamos estruturados como os grandes de Wall Street. Cada um na sua função de excelência. Vamos pra cima! 🚀"
)

url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
payload = json.dumps({"chat_id": CHAT_ID, "text": mensagem, "parse_mode": "Markdown"}).encode("utf-8")
req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req) as resp:
        print("Mensagem oficial de alinhamento enviada com sucesso no Telegram!")
        # Registrar no stream neural
        evento = {
            "id": int(time.time() * 1000),
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "origem": "ALIEN",
            "tipo": "DIRETRIZ_ESTRATEGICA",
            "conteudo": mensagem,
            "meta": {"acao": "ALINHAMENTO_TIME_FERRAMENTAS"}
        }
        with open(STREAM_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(evento, ensure_ascii=False) + "\n")
except Exception as e:
    print("Erro ao enviar:", e)
