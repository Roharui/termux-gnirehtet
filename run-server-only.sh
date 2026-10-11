#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config="${1:-$script_dir/.env}"
if [[ ! -f "$config" ]]; then
    echo "설정 파일을 찾을 수 없습니다: $config" >&2
    exit 1
fi
SERVER_IP=
SERVER_HOST=
DNS_IP=
source "$config"

valid_ipv4() {
    local address="$1" octet
    local -a octets
    [[ "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    IFS=. read -r -a octets <<< "$address"
    for octet in "${octets[@]}"; do
        [[ ${#octet} -le 3 ]] || return 1
        (( 10#$octet <= 255 )) || return 1
    done
}

host="${SERVER_HOST:-$SERVER_IP}"
if [[ -z "$host" || "$host" == -* || "$host" == *[/:[:space:]]* ]]; then
    echo "SERVER_HOST에 도메인 또는 IPv4 주소를 입력하세요 (프로토콜/포트 제외)." >&2
    exit 1
fi
domain_mode=false
if valid_ipv4 "$host"; then
    server_ips=("$host")
else
    domain_mode=true
    command -v python3 >/dev/null || {
        echo "도메인 조회에 Python이 필요합니다: pkg install python" >&2
        exit 1
    }
    resolved="$(python3 - "$host" <<'PY'
import socket
import sys
try:
    addresses = sorted({item[4][0] for item in socket.getaddrinfo(
        sys.argv[1], None, socket.AF_INET, socket.SOCK_STREAM)})
    if not addresses:
        raise ValueError('IPv4 주소 없음')
    print('\n'.join(addresses))
except (OSError, ValueError) as error:
    print(f'서버 도메인 조회 실패: {error}', file=sys.stderr)
    sys.exit(1)
PY
    )" || exit 1
    mapfile -t server_ips <<< "$resolved"
fi
if [[ -n "$DNS_IP" ]] && ! valid_ipv4 "$DNS_IP"; then
    echo "DNS_IP는 IPv4 주소여야 합니다." >&2
    exit 1
fi
cd "$script_dir"
[[ -x ./gnirehtet ]] || {
    echo "이 스크립트와 설정 파일을 gnirehtet 실행 파일과 같은 폴더에 넣으세요." >&2
    exit 1
}

routes=
for ip in "${server_ips[@]}"; do
    valid_ipv4 "$ip" || exit 1
    routes+="${routes:+,}$ip/32"
done
# 외부 DNS 기본값(8.8.8.8)을 사용하지 않도록, DNS 미설정 시 서버 IP 사용.
# 서버가 DNS를 제공하지 않으면 도메인 조회는 실패하며 IP로 접속해야 합니다.
dns="${DNS_IP:-${server_ips[0]}}"
if "$domain_mode"; then
    dns="${DNS_IP:-1.1.1.1}"
fi
if [[ ",$routes," != *",$dns/32,"* ]]; then
    routes+=",$dns/32"
fi
echo "USB 경로: $routes"
echo "다른 목적지 트래픽은 기존 Wi-Fi/모바일 연결을 사용할 수 있습니다."
if "$domain_mode"; then
    echo "도메인: $host / DNS: $dns (DNS 트래픽도 USB 사용)"
elif [[ -z "$DNS_IP" ]]; then
    echo "DNS 미설정: 서버에 IP로 접속하세요."
fi
# 실행 중인 클라이언트는 새 경로를 무시하므로 먼저 중지합니다.
./gnirehtet stop
exec ./gnirehtet run -r "$routes" -d "$dns"
