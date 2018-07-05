#!/bin/sh
#written by benson huang
#admin@zhetenger.com
#http://www.terryche.me/openwrt-dnspod-ddns.html

#token
token=''

#域名
domainname='11111.me'

#需要更新的子域名列表，多个的话，以空格分割。
#例如：
#  sub_domains='www home'
sub_domains='xxxxxxx'


#检查是否安装curl
curl_status=`which curl 2>/dev/null`
[ -n "$curl_status" ] || { echo "curl is not installed";exit 3; }

os=$(uname -a | egrep -io 'openwrt' | tr [A-Z] [a-z])

API_url="https://dnsapi.cn"
format='json'
lang='en'
record_type='A'
offset="2"
length=""
common_options="--data-urlencode \"login_token=${token}\"\
				--data-urlencode \"format=${format}\"\
				--data-urlencode \"lang=${lang}\""
PROGRAM=$(basename $0)
is_svc=0

printMsg() {
	local msg="$1"
	if [ $is_svc -eq 1 ];then
		logger -t ${PROGRAM} "${msg}"
	else
		echo $msg
	fi
}

getJsonValue(){
	local params="$1"
	echo $json_data | sed 's/\\\\\//\//g' | sed 's/[{}]//g;s/\(\[\|\]\)//g' |\
		awk -F ',' '{ for (i=1;i<=NF;i++) { print $i }}' |\
		sed 's/":/\|/g;s/"//g' |\
		awk -v k="$params" -F'|' '{ if ($(NF - 1) == k )  print $NF }'
}

execAPI() {
	local action="$1"
	local extra_options="$2"
	eval "curl -s -k -A  'xddns' ${API_url}/${action} ${common_options} ${extra_options}"
}

getDomainId() {
	local extra_options="--data-urlencode \"domain=${domainname}\""
	json_data=$(execAPI "Domain.info" "${extra_options}")
	getJsonValue id
}

getRecordId() {
	local extra_options
	for sub_domain in $sub_domains;do
		extra_options="--data-urlencode \"record_type=${record_type}\"\
						--data-urlencode \"domain_id=${domain_id}\"\
						--data-urlencode \"sub_domain=${sub_domain}\"\
						--data-urlencode \"offset=${offset}\"\
						--data-urlencode \"length=${length}\""

		json_data=$(execAPI "Record.List" "${extra_options}")

		#check if record type is NS
		IS_NS=$(getJsonValue type | grep -o 'NS' | head -n1)

		#if there are multi @ subdomains, get the first non-NS record id only
		if [ "$IS_NS" = "NS" ];then
			numofline=$(getJsonValue id | sed '/^[0-9]\{7\}$/d' | wc -l)
			[ $numofline -eq 3 ] && tmp_result_id="$(getJsonValue id | sed '/^[0-9]\{7\}$/d' | head -n1 )" || continue
		else
			tmp_result_id="$(getJsonValue id | sed '/^[0-9]\{7\}$/d')"
		fi	
		#if result_id is not empty or unset, append a space to split record id
		result_id="${result_id:+${result_id} }${tmp_result_id}"
	done
	echo $result_id
	exit
}

updateRecord() {
	local record_id_list
	local extra_options
	local tmp=${sub_domains}
	local tmp_sub_domains
	printMsg 'Start update records'
	record_id_list=$(getRecordId)
	printMsg "Records IDs: ${record_id_list}"
	for record_id in $record_id_list;do
		tmp_sub_domains=$(echo $tmp | awk '{ print $1 }')
		tmp=${tmp#* }
		extra_options="--data-urlencode \"domain_id=${domain_id}\"\
						--data-urlencode \"record_id=${record_id}\"\
						--data-urlencode \"sub_domain=${tmp_sub_domains}\"\
						--data-urlencode \"record_line=默认\""
		json_data=$(execAPI "Record.Ddns" "${extra_options}")
		printMsg "Update [${tmp_sub_domains}.${domainname}] ${record_type} record to [${pub_ip_addr}] : $(getJsonValue message)"
	done
	printMsg 'Update records finish'
}


execUpdate() {
	domain_id=`getDomainId $domainname`
	updateRecord
}


printMsg "Start update record, domain: ${domainname}, sub_domains: ${sub_domains}";
execUpdate;

