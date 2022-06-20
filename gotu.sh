#!/usr/bin/env bash
#:: Date: 2022-06-20 - 2022-06-20
#:: Author: Tomas Andriekus
#:: Description: GotYou (gotu) emits connections from ss, aggregates the IP information using whois
#:: Dependencies: apt install ipcalc whois -y

APP='ssh'
CACHE=~/.cache/gotu

function add_ip_info_to_cache() {
	[[ ! -z "$1" ]] && (echo "$1"; echo "$2") > ${CACHE}/${3}
}

function print_results() {
	separator="-->"
	printf '%10s %25s %3s %10s %3s %30s %40s\n' [$(date '+%Y-%m-%d|%H:%M:%S')] [${APP}] $separator [${1}] $separator [${2}] [${3}]
}

function main() {
	mkdir -p $CACHE
	while true
	sleep .1
	do
		OUT=$(ss -nap | grep -i $APP)
		IPS=$(echo $OUT | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}.[0-9]{1,5}\b")
		for IP_PORT in $IPS
		do
			ip_without_port=$(echo $IP_PORT | sed 's@:.*@@g')
			ip_class=$(ipcalc $ip_without_port | grep -c -E "Private|Multicast|Reserved")

			# // We don't need localhost and LAN connections
			if [[ "$ip_class" == 0 ]]; then
				if [[ -f "${CACHE}/${ip_without_port}" ]]; then
					ip_origin=$(cat ${CACHE}/${ip_without_port} | head -1)
					ip_country=$(cat ${CACHE}/${ip_without_port} | tail -1)
					print_results $ip_country $IP_PORT $ip_origin
				else
					ip_origin=$(whois $ip_without_port | grep -i "netname" | sed 's@NetName:@@gi' | tr -d '[:space:]')
					ip_country=$(whois $ip_without_port | grep -i "country" | head -1 | sed 's@country:@@gi' | tr -d '[:space:]')
					add_ip_info_to_cache $ip_origin $ip_country $ip_without_port
					print_results $ip_country $IP_PORT $ip_origin
				fi
			fi
		done
	done
}

main
