. .\tools\ipad.ps1
Invoke-IPad -IPadHost 192.168.1.176 -Command 'killall -9 RealNews 2>/dev/null; sleep 1; sblaunch -u realnews:// com.samcejko.realnews; sleep 3; echo "App launched"'