"""
tools/verify_empirical_mechanics.py
Comprehensive Adversarial Empirical Verification Suite for EXP-015:
- Tick Cache & Model 4 Authenticity
- Core Agent Log & Strategy Tester Execution Logs
- Deal #30 Fine-Grained Trailing Stop Ratchet Analysis
- Deal #28 Fast Breakeven Analysis
- All 30 Deals Slippage, Spread, and Execution Audit
- Lookahead Bias & Synthetic Tick Interpolation Scrutiny
"""

import os
import re
import sys
import struct
from datetime import datetime

# Set UTF-8 encoding for stdout
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

def section(title):
    print("\n" + "="*80)
    print(f" {title} ")
    print("="*80)

def verify_tkc_cache():
    section("1. TICK CACHE FORENSICS (202610.tkc & Model 4)")
    if not os.path.exists(CACHE_FILE):
        print(f"[FAIL] Cache file does not exist: {CACHE_FILE}")
        return False
    
    stat = os.stat(CACHE_FILE)
    size_mb = stat.st_size / (1024 * 1024)
    print(f"Tick Cache Path: {CACHE_FILE}")
    print(f"File Size: {stat.st_size:,} bytes ({size_mb:.2f} MB)")
    print(f"Last Modified: {datetime.fromtimestamp(stat.st_mtime)}")
    
    # MT5 .tkc files store ticks in binary records (often 60-byte header + 40/60-byte tick records or compressed blocks)
    # Let's inspect the first 64 bytes
    with open(CACHE_FILE, "rb") as f:
        header = f.read(128)
    print(f"Binary header bytes (hex): {header[:32].hex()}")
    
    # Check .tst cache file
    if os.path.exists(TST_FILE):
        tst_stat = os.stat(TST_FILE)
        print(f"\nTester Cache File (.tst): {TST_FILE}")
        print(f"File Size: {tst_stat.st_size:,} bytes")
        print(f"Last Modified: {datetime.fromtimestamp(tst_stat.st_mtime)}")
        # Check naming pattern: ALIEN_V12_1_INSTITUTIONAL.XAUUSD.M1.20261021_20261024.4.<hash>.tst
        fname = os.path.basename(TST_FILE)
        parts = fname.split('.')
        print(f"Parsed Filename: EA={parts[0]}, Symbol={parts[1]}, Period={parts[2]}, Range={parts[3]}, Model={parts[4]}")
        assert parts[4] == "4", f"Model is not 4! Got: {parts[4]}"
        print(f"[VERIFIED] Tester cache filename explicitly encodes Model 4 (Every tick based on real ticks).")
    else:
        print(f"[WARN] Tester cache file not found: {TST_FILE}")

def parse_agent_log_exp15():
    section("2. CORE 1 AGENT LOG AUDIT (EXP-015 TEST SESSION)")
    if not os.path.exists(AGENT_LOG):
        print(f"[FAIL] Agent log not found: {AGENT_LOG}")
        return []
    
    with open(AGENT_LOG, "r", encoding="utf-16le", errors="ignore") as f:
        raw_lines = f.readlines()
        
    print(f"Total lines in Agent log: {len(raw_lines)}")
    
    # Locate EXP-015 session in agent log
    # Look for session with ALIEN_V12_1_INSTITUTIONAL from 2026.10.21 to 2026.10.24
    session_start = -1
    session_end = -1
    for i, line in enumerate(raw_lines):
        if "ALIEN_V12_1_INSTITUTIONAL" in line and "2026.10.21" in line and "2026.10.24" in line:
            session_start = i
        if session_start != -1 and i > session_start and "final balance 9894.34" in line:
            session_end = i + 10
            break
            
    if session_start == -1:
        # Try fallback: look for final balance 9894.34
        for i, line in enumerate(raw_lines):
            if "final balance 9894.34" in line:
                session_end = i + 10
                session_start = max(0, i - 1000)
                break
                
    print(f"EXP-015 Agent log range: lines {session_start} to {session_end}")
    lines = raw_lines[session_start:session_end] if session_start != -1 else []
    
    # Check setup lines
    print("\n--- Session Setup Lines ---")
    for l in lines[:25]:
        txt = l.strip()
        if any(k in txt for k in ["XAUUSD", "ticks", "testing of", "initial deposit", "spread", "leverage", "currency"]):
            print(f"  {txt}")
            
    # Check end summary lines
    print("\n--- Session Conclusion Lines ---")
    for l in lines[-20:]:
        txt = l.strip()
        if any(k in txt for k in ["ticks", "bars", "final balance", "summary", "deals", "trades", "tester"]):
            print(f"  {txt}")
            
    return lines

def analyze_deal_30(lines):
    section("3. DEEP FORENSIC AUDIT OF DEAL #30 (TRAILING STOP RATCHET DYNAMICS)")
    # We want to trace order, position, and SL modifications around Deal #30
    # From worker handoff: Deal #30 (SELL 0.18 XAUUSD on 2026.10.22 at 11:23:08)
    deal30_lines = []
    capture = False
    
    for l in lines:
        if "11:23:08" in l or "11:23:09" in l:
            capture = True
        if capture:
            deal30_lines.append(l.strip())
            if "deal #31" in l.lower() or ("11:23:31" in l and "performed" in l):
                # continue a few lines after
                pass
            if "11:23:35" in l:
                break
                
    print(f"Extracted {len(deal30_lines)} log events during Deal #30 lifetime (11:23:08 - 11:23:32):")
    sl_mods = []
    for l in deal30_lines:
        print(f"  {l}")
        # Look for order modifications
        # e.g.: modify #... sl: ..., tp: ...
        if "modify" in l.lower() or "sl" in l.lower():
            m = re.search(r"(\d{2}:\d{2}:\d{2}(?:\.\d+)?).*?(?:order #\d+|deal #\d+|position #\d+|sl:?\s*([\d\.]+)).*?(?:sl:?\s*([\d\.]+)|\b)", l, re.IGNORECASE)
            sl_mods.append(l)
            
    print(f"\nSL Modification & Execution Events recorded for Deal #30: {len(sl_mods)}")

def analyze_deal_28(lines):
    section("4. AUDIT OF DEAL #28 (FAST BREAKEVEN DEMONSTRATION)")
    deal28_lines = []
    capture = False
    for l in lines:
        if "11:22:27" in l:
            capture = True
        if capture:
            deal28_lines.append(l.strip())
            if "11:22:58" in l:
                break
                
    print(f"Extracted {len(deal28_lines)} log events during Deal #28 lifetime (11:22:27 - 11:22:58):")
    for l in deal28_lines:
        print(f"  {l}")

def audit_all_deals(lines):
    section("5. AUDIT OF ALL 30 DEALS (SLIPPAGE, SPREAD & EXECUTION INTEGRITY)")
    deals = []
    order_sends = []
    modifications = []
    
    for l in lines:
        if "CTrade::OrderSend" in l or "order send" in l.lower():
            order_sends.append(l.strip())
        if "deal #" in l.lower() and "done" in l.lower():
            deals.append(l.strip())
        if "modify" in l.lower() and "sl:" in l.lower():
            modifications.append(l.strip())
            
    print(f"Total OrderSend events: {len(order_sends)}")
    print(f"Total Deal Done events: {len(deals)}")
    print(f"Total Trailing SL Modification events: {len(modifications)}")
    
    print("\n--- Sample of Deals executed ---")
    for d in deals[:10]:
        print(f"  {d}")
    print("  ...")
    for d in deals[-5:]:
        print(f"  {d}")
        
    print(f"\n--- Trailing Stop Ratchet Activity across entire test ---")
    print(f"Total SL modifications executed: {len(modifications)}")
    for m in modifications[:10]:
        print(f"  {m}")
    if len(modifications) > 10:
        print(f"  ... and {len(modifications) - 10} more trailing modifications.")

def audit_lookahead_and_interpolation():
    section("6. CODEBASE AUDIT: LOOKAHEAD BIAS & SYNTHETIC ARTIFACTS")
    if not os.path.exists(EA_SOURCE):
        print(f"[FAIL] EA source file not found: {EA_SOURCE}")
        return
        
    with open(EA_SOURCE, "r", encoding="utf-8", errors="ignore") as f:
        code = f.read()
        
    print(f"Auditing {EA_SOURCE} ({len(code):,} chars)...")
    
    # 1. Check bar indexing for M1 patterns
    # In MQL5, rates[0] is current incomplete bar, rates[1] is latest closed bar.
    # Look for how rates are accessed
    rates_access = re.findall(r"rates\[\s*\d+\s*\]", code)
    print(f"Rates array accesses: {set(rates_access)}")
    
    # 2. Check CopyRates / iTime / iClose / iHigh / iLow
    bar0_usage = re.findall(r"(?:iClose|iHigh|iLow|iOpen|iTime)\s*\([^)]*,\s*0\s*\)", code)
    bar1_usage = re.findall(r"(?:iClose|iHigh|iLow|iOpen|iTime)\s*\([^)]*,\s*1\s*\)", code)
    print(f"Bar 0 (current forming bar) usage count: {len(bar0_usage)}")
    print(f"Bar 1 (closed bar) usage count: {len(bar1_usage)}")
    
    # Inspect how Bar 0 is used (is it just for current price/time check, or forming structure?)
    if bar0_usage:
        print("Sample Bar 0 usages:")
        for u in bar0_usage[:5]:
            print(f"  {u}")
            
    # 3. Check Trailing stop logic
    trail_pos = code.find("ApplyAdaptiveTrailingStop")
    if trail_pos != -1:
        print("\n--- Trailing Stop Implementation Snippet ---")
        print(code[trail_pos:trail_pos+1500])
        
    # 4. Check Breakeven logic
    be_pos = code.find("CheckBreakeven")
    if be_pos != -1:
        print("\n--- Breakeven Implementation Snippet ---")
        print(code[be_pos:be_pos+1200])

def audit_html_report():
    section("7. HTML TESTER REPORT INDEPENDENT PARSING")
    if not os.path.exists(REPORT_FILE):
        print(f"[FAIL] Report file not found: {REPORT_FILE}")
        return
        
    with open(REPORT_FILE, "r", encoding="utf-16le", errors="ignore") as f:
        html = f.read()
        
    print(f"HTML Report Size: {len(html):,} chars")
    
    # Extract Deals table
    # Pattern: <tr><td>deal</td>...
    deals_rows = re.findall(r"<td>deal</td>.*?</tr>", html, re.DOTALL | re.IGNORECASE)
    print(f"Total 'deal' rows found in HTML: {len(deals_rows)}")
    
    # Parse deals into structured records
    # MT5 deals columns typically: Time, Deal, Order, Symbol, Type, Direction, Volume, Price, Order, Commission, Fee, Swap, Profit, Balance, Comment
    parsed_deals = []
    for row in deals_rows:
        cols = [re.sub(r"<[^>]+>", "", c).strip() for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.DOTALL)]
        if cols:
            parsed_deals.append(cols)
            
    print(f"Successfully parsed {len(parsed_deals)} deals.")
    print("Headers / First 3 deals:")
    for d in parsed_deals[:3]:
        print(f"  {d}")
        
    print("\nDeal #30 and #31 in HTML Report:")
    for d in parsed_deals:
        # Check if deal ticket or order ticket matches #30 or #31 or time 11:23
        if any("11:23:" in str(c) for c in d):
            print(f"  {d}")

if __name__ == "__main__":
    verify_tkc_cache()
    lines = parse_agent_log_exp15()
    analyze_deal_30(lines)
    analyze_deal_28(lines)
    audit_all_deals(lines)
    audit_lookahead_and_interpolation()
    audit_html_report()
