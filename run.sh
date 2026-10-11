#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
usage() {
    echo "사용법: $0 [--env | --all] [설정 파일]"
    echo "기본값: --env, 스크립트 폴더의 .env"
}
mode=env
config="$script_dir/.env"
config_set=false
mode_set=false
for arg in "$@"; do
    case "$arg" in
        --all|--env)
            if "$mode_set"; then
                echo "모드 옵션은 하나만 지정하세요." >&2
                exit 1
            fi
            mode="${arg#--}"
            mode_set=true
            ;;
        -h|--help) usage; exit 0 ;;
        -*) usage >&2; exit 1 ;;
        *)
            if "$config_set"; then usage >&2; exit 1; fi
            config="$arg"
            config_set=true
            ;;
    esac
done
if [[ "$mode" == all ]]; then
    if "$config_set"; then
        echo "--all에서는 설정 파일을 지정하지 마세요." >&2
        exit 1
    fi
    cd "$script_dir"
    echo "전체 IPv4 트래픽을 USB로 전달합니다."
    ./gnirehtet stop
    exec ./gnirehtet run
fi
if [[ ! -f "$config" ]]; then
    echo "설정 파일을 찾을 수 없습니다: $config" >&2
    exit 1
fi
SERVER_IP=
SERVER_HOST=
ALLOWED_HOSTS=
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

hosts="${ALLOWED_HOSTS:-${SERVER_HOST:-$SERVER_IP}}"
if [[ -z "${hosts//[[:space:],]/}" ]]; then
    echo "ALLOWED_HOSTS에 도메인 또는 IPv4 주소를 입력하세요." >&2
    exit 1
fi
# 쉼표, 공백, 줄바꿈으로 구분하며 glob 확장을 하지 않습니다.
hosts="${hosts//,/ }"
hosts="${hosts//$'\n'/ }"
read -r -a allowed_hosts <<< "$hosts"
domain_mode=false
server_ips=()
for host in "${allowed_hosts[@]}"; do
    if [[ -z "$host" || "$host" == -* || "$host" == *[/:[:space:]]* ]]; then
        echo "잘못된 주소: $host (프로토콜/포트/경로 제외)" >&2
        exit 1
    fi
    if valid_ipv4 "$host"; then
        server_ips+=("$host")
    else
        domain_mode=true
        command -v python3 >/dev/null || {
            echo "도메인 조회에 Python이 필요합니다: pkg install python" >&2
            exit 1
        }
        resolved="$(python3 - "$host" <<'PYDNS'
import socket
import sys
try:
    addresses = sorted({item[4][0] for item in socket.getaddrinfo(
        sys.argv[1], None, socket.AF_INET, socket.SOCK_STREAM)})
    if not addresses:
        raise ValueError('IPv4 주소 없음')
    print('\n'.join(addresses))
except (OSError, ValueError) as error:
    print(f'도메인 {sys.argv[1]} 조회 실패: {error}', file=sys.stderr)
    sys.exit(1)
PYDNS
        )" || exit 1
        mapfile -t resolved_ips <<< "$resolved"
        server_ips+=("${resolved_ips[@]}")
    fi
done
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
    if [[ ",$routes," != *",$ip/32,"* ]]; then
        routes+="${routes:+,}$ip/32"
    fi
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
    echo "허용 주소: ${allowed_hosts[*]} / DNS: $dns (DNS 트래픽도 USB 사용)"
elif [[ -z "$DNS_IP" ]]; then
    echo "DNS 미설정: 서버에 IP로 접속하세요."
fi
# 실행 중인 클라이언트는 새 경로를 무시하므로 먼저 중지합니다.
./gnirehtet stop
exec ./gnirehtet run -r "$routes" -d "$dns"
