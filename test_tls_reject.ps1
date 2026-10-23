. .\tools\ipad.ps1
Invoke-IPad -IPadHost 192.168.1.176 -Command 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://expired.badssl.com/ 2>&1 || echo "curl failed"'