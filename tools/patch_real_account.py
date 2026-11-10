import os
import re

mq5_path = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.mq5"
with open(mq5_path, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Add input AllowLiveRealTrading
target_input = 'input group "=== SUPERVISOR INSTITUCIONAL AUTONOMO (DISJUNTORES E BLINDAGEM) ==="'
replacement_input = '''input group "=== MODO DE CONTA E EXECUCAO REAL ==="
input bool   AllowLiveRealTrading     = true;   // Permite operacao em Conta Real sob gestao estrita de risco

input group "=== SUPERVISOR INSTITUCIONAL AUTONOMO (DISJUNTORES E BLINDAGEM) ==="'''

code = code.replace(target_input, replacement_input)

# 2. Update the OnInit trade mode check
old_check = """   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO &&
      !MQLInfoInteger(MQL_TESTER))
   {
      Print("ALIEN V12.1 INSTITUTIONAL LAB: somente conta DEMO ou Testador de Estrategias.");
      return INIT_FAILED;
   }"""

new_check = """   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO &&
      !MQLInfoInteger(MQL_TESTER))
   {
      if(!AllowLiveRealTrading)
      {
         Print("ALIEN V12.1 INSTITUTIONAL LAB: Operacao em Conta Real bloqueada por parametro AllowLiveRealTrading=false.");
         return INIT_FAILED;
      }
      Print("ALIEN V12.1 INSTITUTIONAL: OPERACAO EM CONTA REAL ATIVADA COM SUCESSO! Titular: ", AccountInfoString(ACCOUNT_NAME), " | Saldo: $", AccountInfoDouble(ACCOUNT_BALANCE));
   }"""

code = code.replace(old_check, new_check)

with open(mq5_path, "w", encoding="utf-8") as f:
    code = f.write(code)

print("Patch de Conta Real aplicado com sucesso!")
