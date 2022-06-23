#!/usr/bin/env bash
#:: Date: 2022-06-20 - 2022-06-23
#:: Author: Tomas Andriekus
#:: Description: GotYou (gotu) emits connections from ss, aggregates the IP information using whois
#:: Dependencies: apt install ipcalc whois -y
#:: Usage: ./gotu.sh appname [OR] bash gotu.sh appname

[[ ! -z "$1" ]] && APP=$1 || APP='ssh'
CACHE=~/.cache/gotu
SS_OUT_FILE="${CACHE}/.ss"
WHOIS_PATH="${CACHE}/.gotulivewhois"
LAST_SENT_PATH="${CACHE}/.lastsnt"
LAST_RECV_PATH="${CACHE}/.lastrcv"
SEPARATOR="-->"

function add_ip_info_to_cache() {
	ip=$1
	ip_country="??"
	ip_origin="UNKNOWN"

	[[ ! -z "$2" ]] && ip_country=$2
	[[ ! -z "$3" ]] && ip_origin=$3

	(echo "${ip_origin^^}"; echo "${ip_country^^}") > ${CACHE}/${ip}
}

function print_results() {
	ts=$(date '+%Y-%m-%d|%H:%M:%S.%3N')
	ip=$(echo ${2} | grep -o -E '^[^:]+')
	port=$(echo ${2} | grep -o -E '[^:]+$')
	printf '%10s %25s %3s %5s %3s %25s %35s\n' [$ts] [${APP}] $SEPARATOR [${1}] $SEPARATOR [${ip}]:${port} [${3}]
}

function main() {
	mkdir -p $CACHE
	while true
	do
		ss -O -o state established -anpi | grep -i $APP > $SS_OUT_FILE
		IPS=$(cat $SS_OUT_FILE | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}.[0-9]{1,5}\b")
		#RECV=$(cat $SS_OUT_FILE | grep -o 'bytes_received.*' | awk '{print $1}' | grep -o '[[:digit:]]*')
		#SENT=$(cat $SS_OUT_FILE | grep -o 'bytes_sent.*'	 | awk '{print $1}' | grep -o '[[:digit:]]*')
		cat $SS_OUT_FILE | grep -o 'lastrcv.*' | awk '{print $1}' | grep -o '[[:digit:]]*' > $LAST_RECV_PATH
		cat $SS_OUT_FILE | grep -o 'lastsnd.*' | awk '{print $1}' | grep -o '[[:digit:]]*' > $LAST_SENT_PATH

		counter=0
		for IP_PORT in $IPS
		do
			ip_without_port=$(echo $IP_PORT | sed 's@:.*@@g')
			ip_class=$(ipcalc $ip_without_port | grep -c -E "Private|Multicast|Reserved|Loopback")

			# // We don't need localhost and LAN connections
			if [[ "$ip_class" == 0 ]] && [[ "$ip_without_port" != "0.0.0.0" ]] && [[ -s $LAST_RECV_PATH ]]; then

				counter=$(($counter+1))
				last_recv=$(sed -n ${counter}p $LAST_RECV_PATH)
				last_sent=$(sed -n ${counter}p $LAST_SENT_PATH)

				if [ $last_recv -le 200 ] || [ $last_recv -le 200 ]; then

					if [[ -f "${CACHE}/${ip_without_port}" ]]; then
						ip_origin=$(cat ${CACHE}/${ip_without_port}  | head -1) 
						ip_country=$(cat ${CACHE}/${ip_without_port} | tail -1)
						print_results $ip_country $IP_PORT $ip_origin
					else
						whois $ip_without_port > $WHOIS_PATH
						ip_origin=$(cat $WHOIS_PATH  | grep -i "netname" | head -1 | sed 's@NetName:@@gi' | tr -d '[:space:]')
						ip_country=$(cat $WHOIS_PATH | grep -i "country" | head -1 | sed 's@country:@@gi' | tr -d '[:space:]')
						add_ip_info_to_cache $ip_without_port $ip_country  $ip_origin 
						print_results $ip_country $IP_PORT $ip_origin
					fi
				fi
			fi
		done
	done
}

main
