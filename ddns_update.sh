#!/bin/sh
curl -k -X POST https://dnsapi.cn/Record.Modify -d "login_token=70629,94c8644d374ef75c8c2412f4227db898&format=json&domain_id=69315524&record_id=387302391&sub_domain=lede&value=$1&record_type=A&record_line=%e9%bb%98%e8%ae%a4"
return $?
