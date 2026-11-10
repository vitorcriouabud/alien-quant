Set sh = CreateObject("WScript.Shell")
success = sh.AppActivate("RoboForex")
If Not success Then success = sh.AppActivate("27313466")
If Not success Then success = sh.AppActivate("MetaTrader")
If success Then
    WScript.Sleep 200
    sh.SendKeys "% x"
    WScript.Echo "SUCCESS: Activated and maximized MT5!"
Else
    WScript.Echo "Could not find MT5 window to activate."
End If
