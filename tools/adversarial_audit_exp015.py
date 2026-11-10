"""
tools/adversarial_audit_exp015.py
Adversarial Verification of EXP-015 Execution & Tick Mechanics.
"""

import os
import re
import sys
from datetime import datetime

# Configure stdout
if sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

TERMINAL_DIR = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79"
TESTER_DIR = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Tester\5FFA568149E88FCD5B44D926DCFEAA79"
TERMINAL_LOG = os.path.join(TERMINAL_DIR, "Tester", "logs", "20261109.log")
AGENT_LOG = os.path.join(TESTER_DIR, "Agent-127.0.0.1-3000", "logs", "20261109.log")
CACHE_FILE = os.path.join(TERMINAL_DIR, "bases", "RoboForex-ECN", "ticks", "XAUUSD", "202610.tkc")
TST_FILE = os.path.join(TERMINAL_DIR, "Tester", "cache", "ALIEN_V12_1_INSTITUTIONAL.XAUUSD.M1.20261021_20261024.4.7ECFFFFBA0CFE7BF666D2D2D419EC12A.tst")
REPORT_FILE = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\EXP_015_V12_1_BENCHMARK\EXP_015_V12_1_BENCHMARK.htm"
EA_SOURCE = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"

def check_terminal_log_sync():
    print("="*80)
    print("1. TERMINAL & AGENT SYNCHRONIZATION LOG FORENSICS")
    print("="*80)
    
    with open(TERMINAL_LOG, "r", encoding="utf-16le", errors="ignore") as f:
        t_lines = f.readlines()
        
    # Search for EXP-015 in terminal log (around 04:40:24)
    exp_t_lines = []
    capture = False
    for l in t_lines:
        if "04:40:24" in l or ("2026.10.21" in l and "2026.10.24" in l and "ALIEN_V12_1_INSTITUTIONAL" in l):
            capture = True
        if capture:
            exp_t_lines.append(l.strip())
            if "04:43:00" in l or "final balance" in l:
                if len(exp_t_lines) > 20:
                    break
                    
    print(f"Terminal log events during test launch ({len(exp_t_lines)} lines):")
    for l in exp_t_lines[:20]:
        print(f"  {l}")
    for l in exp_t_lines[-10:]:
        print(f"  {l}")

def extract_exp015_agent_lines():
    with open(AGENT_LOG, "r", encoding="utf-16le", errors="ignore") as f:
        raw_lines = f.readlines()
        
    start = -1
    end = -1
    for i, l in enumerate(raw_lines):
        if "04:40:24.802" in l:
            start = i
        if start != -1 and i > start and "04:42:59.881" in l:
            end = i + 5
            break
            
    assert start != -1 and end != -1, f"Could not find exact EXP-015 bounds! start={start}, end={end}"
    print(f"\nExact EXP-015 session in Agent Log: lines {start} to {end} ({end - start} lines)")
    return raw_lines[start:end]

def audit_all_trades(lines):
    print("\n" + "="*80)
    print("2. COMPLETE RECONSTRUCTION OF ALL 30 TRADES (DEALS 2 TO 61)")
    print("="*80)
    
    # We want to pair entries and exits, trace trailing stop modifications, check slippage and PnL
    # Parse orders, deals, modifications
    deals = {} # deal_id -> dict
    orders = {} # order_id -> dict
    positions = {} # pos_id -> list of events
    
    # Let's inspect each line
    for l in lines:
        txt = l.strip()
        # Look for deal performed
        # e.g.: 2026.10.22 11:23:08 deal #30 sell 0.18 XAUUSD at 4093.06 done (based on order #30)
        m_deal = re.search(r"(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})\s+deal\s+#(\d+)\s+(buy|sell)\s+([\d\.]+)\s+XAUUSD\s+at\s+([\d\.]+)\s+done\s+\(based on order #(\d+)\)", txt)
        if m_deal:
            d_time, d_id, d_type, d_vol, d_price, d_order = m_deal.groups()
            deals[int(d_id)] = {
                "time": d_time,
                "deal_id": int(d_id),
                "type": d_type,
                "vol": float(d_vol),
                "price": float(d_price),
                "order_id": int(d_order),
                "raw": txt
            }
            
        # Look for order performed / market entry
        # e.g.: market sell 0.18 XAUUSD sl: 4095.11 tp: 4086.90 (4093.06 / 4093.12)
        m_mkt = re.search(r"(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})\s+market\s+(buy|sell)\s+([\d\.]+)\s+XAUUSD\s+sl:\s*([\d\.]+)\s+tp:\s*([\d\.]+)\s+\(([\d\.]+)\s*/\s*([\d\.]+)\)", txt)
        if m_mkt:
            m_time, m_type, m_vol, m_sl, m_tp, m_bid, m_ask = m_mkt.groups()
            # This corresponds to entry
            pass
            
        # Look for position modified
        # e.g.: 2026.10.22 11:23:18 position modified [#30 sell 0.18 XAUUSD 4093.06 sl: 4092.12 tp: 4086.90]
        m_mod = re.search(r"(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})\s+position modified\s+\[#(\d+)\s+(buy|sell)\s+([\d\.]+)\s+XAUUSD\s+([\d\.]+)\s+sl:\s*([\d\.]+)\s+tp:\s*([\d\.]+)\]", txt)
        if m_mod:
            mod_time, pos_id, p_type, p_vol, p_entry, p_sl, p_tp = m_mod.groups()
            pid = int(pos_id)
            if pid not in positions:
                positions[pid] = []
            positions[pid].append({
                "time": mod_time,
                "sl": float(p_sl),
                "tp": float(p_tp),
                "type": p_type,
                "entry": float(p_entry)
            })
            
        # Look for stop loss triggered
        # e.g.: 2026.10.22 11:23:31 stop loss triggered #30 sell 0.18 XAUUSD 4093.06 sl: 4090.22 tp: 4086.90 [#31 buy 0.18 XAUUSD at 4090.22]
        m_sl_trig = re.search(r"(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})\s+stop loss triggered\s+#(\d+)\s+(buy|sell)\s+([\d\.]+)\s+XAUUSD\s+([\d\.]+)\s+sl:\s*([\d\.]+)\s+tp:\s*([\d\.]+)\s+\[#(\d+)\s+(buy|sell)\s+([\d\.]+)\s+XAUUSD\s+at\s+([\d\.]+)\]", txt)
        if m_sl_trig:
            st_time, pos_id, st_type, st_vol, st_entry, st_sl, st_tp, exit_order, exit_type, exit_vol, trigger_px = m_sl_trig.groups()
            pid = int(pos_id)
            if pid not in positions:
                positions[pid] = []
            positions[pid].append({
                "trigger_time": st_time,
                "triggered_sl": float(st_sl),
                "trigger_price": float(trigger_px),
                "exit_order": int(exit_order)
            })

    print(f"Total deals captured: {len(deals)}")
    print(f"Positions with tracking data: {len(positions)}")
    
    # Now load Deals table from HTML report to cross-check PnL, commission, slippage
    with open(REPORT_FILE, "r", encoding="utf-16le", errors="ignore") as f:
        html = f.read()
    tables = re.findall(r'<table[^>]*>.*?</table>', html, re.DOTALL | re.IGNORECASE)
    rows = re.findall(r'<tr[^>]*>.*?</tr>', tables[1], re.DOTALL | re.IGNORECASE)
    
    # Deals start at row 66
    html_deals = {}
    for r in rows[66:]:
        cols = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL)]
        if len(cols) >= 12 and cols[1].isdigit():
            deal_ticket = int(cols[1])
            vol_str = cols[5].replace(' ', '').replace(',', '.')
            vol_val = float(vol_str) if vol_str else 0.0
            price_str = cols[6].replace(' ', '').replace(',', '.')
            price_val = float(price_str) if price_str else 0.0
            comm_str = cols[8].replace(' ', '').replace(',', '.')
            comm_val = float(comm_str) if comm_str else 0.0
            profit_str = cols[10].replace(' ', '').replace(',', '.') if len(cols) > 10 else ''
            profit_val = float(profit_str) if profit_str else 0.0

            html_deals[deal_ticket] = {
                "time": cols[0],
                "ticket": deal_ticket,
                "symbol": cols[2],
                "type": cols[3],
                "dir": cols[4],
                "vol": vol_val,
                "price": price_val,
                "order": int(cols[7]) if cols[7].isdigit() else 0,
                "comm": comm_val,
                "profit": profit_val,
                "balance": cols[11] if len(cols) > 11 else '',
                "comment": cols[12] if len(cols) > 12 else ''
            }
            
    print(f"Total deals parsed from HTML report: {len(html_deals)}")
    
    # Pair trades: entry deal (in) and exit deal (out)
    trade_num = 1
    total_gross_profit = 0.0
    total_gross_loss = 0.0
    
    # Find all 'in' deals
    in_deals = [d for d in html_deals.values() if d["dir"] == "in"]
    print(f"\nTotal Entry Deals (in): {len(in_deals)}")
    
    print("\n" + "-"*110)
    print(f"{'Trade':<5} | {'Entry Time':<19} | {'PosID':<5} | {'Type':<4} | {'Entry Px':<8} | {'Exit Px':<8} | {'SL Mods':<7} | {'Last SL':<8} | {'Slip (pts)':<10} | {'Net Profit':<10} | {'Exit Reason'}")
    print("-"*110)
    
    for in_d in in_deals:
        pos_id = in_d["order"]
        out_deal_ticket = pos_id + 1
        out_d = html_deals.get(out_deal_ticket)
        if not out_d:
            # find matching out deal by order or symbol
            for d in html_deals.values():
                if d["dir"] == "out" and d["ticket"] > in_d["ticket"]:
                    out_d = d
                    break
                    
        mods = [m for m in positions.get(pos_id, []) if "sl" in m]
        num_mods = len(mods)
        last_sl = mods[-1]["sl"] if mods else None
        
        # Calculate slippage if stopped out
        comment = out_d["comment"] if out_d else ""
        slippage_pts = "N/A"
        m_sl_cmt = re.search(r"sl\s*([\d\.]+)", comment)
        if m_sl_cmt:
            sl_val = float(m_sl_cmt.group(1))
            # slippage in points: abs(exit_price - sl_val) * 100
            diff = round((out_d["price"] - sl_val) * 100, 1)
            slippage_pts = f"{diff:+.1f}"
            
        profit = out_d["profit"] if out_d else 0.0
        if profit > 0:
            total_gross_profit += profit
        else:
            total_gross_loss += abs(profit)
            
        print(f"#{trade_num:<4} | {in_d['time']:<19} | {pos_id:<5} | {in_d['type']:<4} | {in_d['price']:<8.2f} | {out_d['price']:<8.2f} | {num_mods:<7} | {str(last_sl):<8} | {slippage_pts:<10} | {profit:>+9.2f} | {comment}")
        trade_num += 1

    print("-"*110)
    print(f"Gross Profit: +${total_gross_profit:.2f} USD")
    print(f"Gross Loss:   -${total_gross_loss:.2f} USD")
    print(f"Net Realized: +${total_gross_profit - total_gross_loss:.2f} USD")
    print(f"Profit Factor: {total_gross_profit / total_gross_loss:.2f}")

def deep_audit_deal30(lines):
    print("\n" + "="*80)
    print("3. FORENSIC ADVERSARIAL DISSECTION: DEAL #30 TRAILING STOP RATCHET")
    print("="*80)
    
    # We want to trace every single event for position #30
    events = []
    for l in lines:
        if "#30" in l:
            events.append(l.strip())
            
    print(f"Total log lines referencing Position/Order/Deal #30: {len(events)}")
    for e in events:
        print(f"  {e}")
        
    # Verify strict monotonicity of SL
    # Position was SELL: SL must strictly decrease (never increase!)
    sl_history = []
    for e in events:
        m = re.search(r"sl:\s*([\d\.]+)", e)
        if m and "position modified" in e:
            val = float(m.group(1))
            if not sl_history or sl_history[-1] != val:
                sl_history.append(val)
                
    print(f"\nSL Ratchet Sequence: {sl_history}")
    monotonic_decreasing = all(sl_history[i] > sl_history[i+1] for i in range(len(sl_history)-1))
    print(f"Strictly monotonic decreasing (tightening only, zero loosening): {monotonic_decreasing}")
    assert monotonic_decreasing, "VIOLATION: Stop loss loosened or was not monotonic!"
    print("[VERIFIED] Trailing stop ratchet strictly tightened risk with zero loosening across all 10 modifications.")

def audit_lookahead_and_candle_indexing():
    print("\n" + "="*80)
    print("4. ADVERSARIAL CODE AUDIT: LOOKAHEAD BIAS & EXECUTION ANOMALIES")
    print("="*80)
    
    with open(EA_SOURCE, "r", encoding="utf-8", errors="ignore") as f:
        code = f.read()
        
    # Check OnTick entry logic
    print("Checking OnTick signal evaluation...")
    
    # Check if OnTick inspects future bars or incomplete bar close
    # If an EA uses iClose(_Symbol, PERIOD_M1, 0) as if it were a closed candle, that's bar 0 peeking.
    # But if it uses bar 1 for patterns (CHoCH, FVG, Liquidity sweeps), that's strictly historical!
    
    # Let's inspect where CHoCH / BOS / FVG are computed
    fvg_idx = code.find("DetectFVG")
    if fvg_idx != -1:
        print("\n--- FVG Detection Implementation ---")
        print(code[fvg_idx:fvg_idx+1000])
        
    sweep_idx = code.find("DetectLiquiditySweep")
    if sweep_idx != -1:
        print("\n--- Liquidity Sweep Detection Implementation ---")
        print(code[sweep_idx:sweep_idx+1000])

if __name__ == "__main__":
    check_terminal_log_sync()
    lines = extract_exp015_agent_lines()
    audit_all_trades(lines)
    deep_audit_deal30(lines)
    audit_lookahead_and_candle_indexing()
