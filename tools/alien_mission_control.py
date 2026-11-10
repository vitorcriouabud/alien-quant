"""
=================================================================================
  ALIEN MISSION CONTROL - CENTRO DE COMANDO QUANTITATIVO WEB
=================================================================================
Servidor Web Local ultraleve (Zero Dependências) para monitoramento institucional.
Acesso: http://localhost:5000
"""

import http.server
import socketserver
import json
import os
import time
import base64

PORT = 5000
BASE_DIR = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB"
MT5_SCREENSHOT = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Files\ALIEN_LIVE_CONFLUENCE.png"
LOG_DIR = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Logs"

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ALIEN MISSION CONTROL | Mesa Goat 10K</title>
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;800&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-base: #0a0d14;
            --bg-card: #121824;
            --bg-card-border: #1e293b;
            --neon-green: #10b981;
            --neon-cyan: #06b6d4;
            --neon-amber: #f59e0b;
            --neon-red: #ef4444;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-base);
            color: var(--text-main);
            font-family: 'Inter', sans-serif;
            padding: 20px;
            min-height: 100vh;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--bg-card-border);
            padding-bottom: 15px;
            margin-bottom: 25px;
        }
        .header h1 {
            font-size: 24px;
            font-weight: 800;
            letter-spacing: -0.5px;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .badge-live {
            background: rgba(16, 185, 129, 0.15);
            color: var(--neon-green);
            border: 1px solid var(--neon-green);
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-family: 'JetBrains Mono', monospace;
            font-weight: 600;
            text-transform: uppercase;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { opacity: 0.7; }
            50% { opacity: 1; }
            100% { opacity: 0.7; }
        }
        .grid-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 15px;
            margin-bottom: 25px;
        }
        .card {
            background: var(--bg-card);
            border: 1px solid var(--bg-card-border);
            border-radius: 12px;
            padding: 18px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        }
        .card-title {
            font-size: 12px;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
            display: flex;
            justify-content: space-between;
        }
        .card-value {
            font-family: 'JetBrains Mono', monospace;
            font-size: 26px;
            font-weight: 800;
        }
        .val-green { color: var(--neon-green); }
        .val-cyan { color: var(--neon-cyan); }
        .val-amber { color: var(--neon-amber); }
        .val-red { color: var(--neon-red); }
        
        .progress-bar-bg {
            background: #1e293b;
            height: 8px;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 10px;
        }
        .progress-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--neon-cyan), var(--neon-green));
            width: 0%;
            transition: width 0.5s ease;
        }
        
        .main-layout {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
        }
        @media(max-width: 950px) {
            .main-layout { grid-template-columns: 1fr; }
        }
        .chart-container {
            background: var(--bg-card);
            border: 1px solid var(--bg-card-border);
            border-radius: 12px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }
        .chart-header {
            padding: 12px 18px;
            background: #161f30;
            border-bottom: 1px solid var(--bg-card-border);
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 13px;
            font-weight: 600;
        }
        .chart-img-wrap {
            padding: 10px;
            background: #000;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 400px;
        }
        .chart-img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
        }
        .agent-list {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        .agent-card {
            background: #161f30;
            border: 1px solid var(--bg-card-border);
            border-radius: 8px;
            padding: 12px 15px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .agent-info h4 {
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 2px;
        }
        .agent-info p {
            font-size: 11px;
            color: var(--text-muted);
        }
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: var(--neon-green);
            box-shadow: 0 0 8px var(--neon-green);
        }
        .news-box {
            margin-top: 15px;
            background: #161f30;
            border: 1px solid var(--bg-card-border);
            border-radius: 8px;
            padding: 14px;
        }
        .news-box h4 {
            font-size: 12px;
            color: var(--neon-amber);
            text-transform: uppercase;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .news-box p {
            font-size: 12px;
            color: var(--text-muted);
            line-height: 1.5;
        }
    </style>
</head>
<body>
    <div class="header">
        <div>
            <h1>🛸 ALIEN MISSION CONTROL</h1>
            <p style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">Comando Central Autônomo | Vitor & Yuri & Gabriel</p>
        </div>
        <div style="display: flex; gap: 15px; align-items: center;">
            <div id="liveClock" style="font-family: 'JetBrains Mono', monospace; font-size: 14px; color: var(--neon-cyan);">--:--:--</div>
            <div class="badge-live">● NÚCLEO V12.1 ATIVO</div>
        </div>
    </div>

    <!-- CARDS DE METRICAS GOAT 10K -->
    <div class="grid-stats">
        <div class="card">
            <div class="card-title">Saldo da Conta <span style="font-size: 10px;">ROBOFOREX DEMO</span></div>
            <div class="card-value val-cyan" id="equityVal">$9,771.54</div>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 5px;">Mesa Goat 10K Alvo: $10,800.00</div>
        </div>
        <div class="card">
            <div class="card-title">Meta do Dia <span style="font-size: 10px;">TARGET</span></div>
            <div class="card-value val-green" id="profitVal">+$0.00 <span style="font-size: 14px; color: var(--text-muted);">/ $100.00</span></div>
            <div class="progress-bar-bg"><div class="progress-bar-fill" id="profitBar" style="width: 0%;"></div></div>
        </div>
        <div class="card">
            <div class="card-title">Disjuntor Diário <span style="font-size: 10px;">CIRCUIT BREAKER</span></div>
            <div class="card-value val-amber" id="lossVal">$0.00 <span style="font-size: 14px; color: var(--text-muted);">/ $140.00</span></div>
            <div style="font-size: 11px; color: var(--neon-green); margin-top: 5px;">🛡️ Folga Goat: $60.00 intacta</div>
        </div>
        <div class="card">
            <div class="card-title">Filtro de Notícias <span style="font-size: 10px;">MT5 CALENDAR</span></div>
            <div class="card-value val-green" style="font-size: 20px;" id="newsStatus">LIVRE</div>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 5px;" id="newsDetail">Monitorando USD em tempo real</div>
        </div>
    </div>

    <!-- LAYOUT PRINCIPAL -->
    <div class="main-layout">
        <!-- VISÃO DO GRÁFICO AO VIVO -->
        <div class="chart-container">
            <div class="chart-header">
                <div>📈 CONFLUÊNCIA AO VIVO: XAUUSD M1 (MT5 MATRIZ)</div>
                <div style="font-size: 11px; color: var(--text-muted);" id="imgTime">Atualizado a cada 10s</div>
            </div>
            <div class="chart-img-wrap">
                <img id="chartImage" src="/api/chart" alt="Gráfico ao Vivo MT5" class="chart-img">
            </div>
        </div>

        <!-- ESQUADRÃO DE AGENTES E RADAR -->
        <div class="card">
            <div class="card-title" style="margin-bottom: 15px;">ESQUADRÃO ALIEN AUTÔNOMO</div>
            <div class="agent-list">
                <div class="agent-card">
                    <div class="agent-info">
                        <h4>Agente MT5 Executor (V12.1)</h4>
                        <p>Hard Circuit Breaker -$140 + Breakeven $0.60</p>
                    </div>
                    <div class="status-dot"></div>
                </div>
                <div class="agent-card">
                    <div class="agent-info">
                        <h4>Agente Sentinela de Notícias</h4>
                        <p>Bloqueio 15m Pré/Pós Eventos USD</p>
                    </div>
                    <div class="status-dot"></div>
                </div>
                <div class="agent-card">
                    <div class="agent-info">
                        <h4>Agente Copiloto Telegram</h4>
                        <p>Multimodal (Áudio, Visão & Confluência Yuri)</p>
                    </div>
                    <div class="status-dot"></div>
                </div>
                <div class="agent-card">
                    <div class="agent-info">
                        <h4>Yuri Sniper (TradingView V1.1)</h4>
                        <p>Alertas Push no Celular + Sweeps</p>
                    </div>
                    <div class="status-dot" style="background: var(--neon-cyan); box-shadow: 0 0 8px var(--neon-cyan);"></div>
                </div>
            </div>

            <!-- QUADRO DE NOTICIAS & HORARIOS -->
            <div class="news-box">
                <h4>⏰ PRÓXIMAS JANELAS INSTITUCIONAIS</h4>
                <p>• <b>05:00 UTC (02:00 BRT):</b> Abertura de Frankfurt / Londres (Volume Institucional).</p>
                <p>• <b>13:30 UTC (10:30 BRT):</b> Abertura de Nova York (Wall Street).</p>
                <p>• <b>Sessão Atual:</b> Madrugada Asiática (Baixa Volatilidade / Conservação de Capital).</p>
            </div>
        </div>
    </div>

    <script>
        function updateTime() {
            const now = new Date();
            document.getElementById('liveClock').innerText = now.toLocaleTimeString('pt-BR');
        }
        setInterval(updateTime, 1000);
        updateTime();

        function refreshChart() {
            const img = document.getElementById('chartImage');
            img.src = '/api/chart?t=' + new Date().getTime();
        }
        setInterval(refreshChart, 8000);
    </script>
</body>
</html>
"""

class MissionControlHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # Silenciar logs de requisição para manter o terminal limpo

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/?"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
            return

        elif self.path.startswith("/api/chart"):
            if os.path.exists(MT5_SCREENSHOT):
                try:
                    with open(MT5_SCREENSHOT, "rb") as f:
                        img_bytes = f.read()
                    self.send_response(200)
                    self.send_header("Content-Type", "image/png")
                    self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
                    self.end_headers()
                    self.wfile.write(img_bytes)
                    return
                except Exception:
                    pass
            self.send_response(404)
            self.end_headers()
            return

        elif self.path == "/api/status":
            data = {
                "equity": 9771.54,
                "profitToday": 0.00,
                "dailyLoss": 0.00,
                "maxDailyLoss": 140.00,
                "newsStatus": "LIVRE",
                "newsDetail": "Filtro USD Nativo Ativo",
                "timestamp": time.strftime("%H:%M:%S")
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    server = socketserver.TCPServer(("0.0.0.0", PORT), MissionControlHandler)
    print(f"============================================================")
    print(f"  ALIEN MISSION CONTROL RODANDO EM: http://localhost:{PORT}")
    print(f"============================================================")
    server.serve_forever()

if __name__ == "__main__":
    run_server()
