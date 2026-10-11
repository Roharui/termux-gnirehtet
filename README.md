# termux-gnirehtet

안드로이드 휴대폰의 인터넷을 USB로 연결된 안드로이드 태블릿에 공유합니다.
PC나 루팅 없이 Termux에서 실행합니다. 이 저장소는
[AlphaBs/termux-gnirehtet](https://github.com/AlphaBs/termux-gnirehtet)의 포크이며,
`.env`에서 지정한 서버 트래픽만 USB로 전달하는 실행 스크립트를 추가했습니다.

## 설치

인터넷을 제공하는 **휴대폰**에 다음 두 앱을 설치하세요.

- [Termux](https://github.com/termux/termux-app/releases)
- [Termux:API](https://github.com/termux/termux-api/releases)

두 앱은 같은 배포처에서 설치해야 합니다. 아래 명령은 휴대폰의 Termux에서 실행합니다.
제공된 gnirehtet 실행 파일은 ARM64(aarch64)용입니다.

```bash
pkg update
pkg install git curl termux-api python
git clone https://github.com/Roharui/termux-gnirehtet.git
cd termux-gnirehtet
./install.sh
```

설치 질문에서 삼성 기기 여부는 휴대폰 기준으로 답하세요.
`Replace 'adb' with 'termux-adb'?` 또는 `Create a symbolic link for 'adb' command?`
질문에는 `y`를 입력하면 이후 `adb` 명령을 사용할 수 있습니다.

## USB 연결

1. 인터넷을 받을 태블릿에서 개발자 옵션의 USB 디버깅을 켭니다.
2. 데이터 전송 가능한 USB 케이블로 두 기기를 연결합니다.
3. 원본 프로젝트의 USB 제어 설정은 휴대폰에서 **연결된 기기**, 태블릿에서
   **이 기기**입니다. 메뉴와 지원 여부는 기기에 따라 다를 수 있습니다.
4. USB 접근 요청과 태블릿의 USB 디버깅 허용 요청을 승인합니다.
5. 휴대폰에서 `adb devices`를 실행해 기기 번호 옆에 `device`가 나오는지 확인합니다.
   처음 인식에는 1~2분 걸릴 수 있습니다.

## 실행 모드

처음 한 번 예시 설정을 복사하세요. 기존 `.env`가 있다면 그대로 편집합니다.

```bash
cp .env.example .env
nano .env
```

`nano`가 없다면 `pkg install nano`로 설치하거나 다른 편집기를 사용하세요.
실제 서버 주소로 변경합니다. 프로토콜, 포트, 경로는 넣지 않습니다.

```dotenv
ALLOWED_HOSTS="
api.example.com
files.example.com
192.0.2.10
"
DNS_IP=1.1.1.1
```

| 설정 | 설명 |
| --- | --- |
| `ALLOWED_HOSTS` | 허용 도메인 또는 IPv4 주소 목록. 공백, 쉼표, 줄바꿈으로 구분 |
| `SERVER_HOST` | 이전 설정과의 호환용. `ALLOWED_HOSTS`가 비어 있을 때 사용 |
| `DNS_IP` | 태블릿에서 사용할 DNS 서버의 IPv4 주소 |
| `SERVER_IP` | 이전 설정과의 호환용. `SERVER_HOST`가 비어 있을 때 사용 |

```bash
./run.sh
```

기존 gnirehtet 실행은 먼저 Ctrl+C로 종료하세요. 스크립트는 기존 클라이언트를
중지한 뒤 새 경로로 시작합니다. 태블릿에 VPN 승인 창이 나오면 허용합니다.
서버에는 `https://api.example.com` 등 기존 주소로 접속합니다.
다른 설정 파일을 쓰려면 `./run.sh /경로/다른.env`로 실행하세요.
`.env`는 Bash에서 읽으므로 `KEY=value` 형식을 사용하고 신뢰할 수 있는 파일만 사용합니다.

`--all`은 `.env` 없이 실행할 수 있으며 설정 파일을 읽지 않습니다.

### 경로와 DNS 동작

- 도메인은 시작할 때 휴대폰의 시스템 DNS로 조회하고 반환된 IPv4 주소를 모두
  USB 경로에 추가합니다. 조회 실패 시 실행을 중단합니다. 주소 변경 시 재시작해야 합니다.
- 도메인 설정에서 `DNS_IP`가 비어 있으면 `1.1.1.1`을 사용합니다.
  **DNS 서버 트래픽도 USB로 전달됩니다.** 휴대폰과 태블릿의 DNS 응답이 다르면
  일부 서버 주소가 USB 경로에 포함되지 않을 수 있습니다.
- 서버를 IPv4 주소로 지정하고 `DNS_IP`를 비워 두면 해당 서버 IP를 DNS로 사용합니다.
  서버가 DNS를 제공하지 않으면 IP로 접속해야 합니다. DNS 요청이 서버의 53번 포트로 갈 수 있습니다.
- 서버 IP의 모든 TCP/UDP 포트에 적용합니다. 공유 IP를 사용하는 다른 도메인도
  같은 경로를 사용하며, 도메인별 또는 포트별 방화벽 제한은 하지 않습니다. IPv6는 지원하지 않습니다.
- 다른 목적지는 태블릿의 기존 Wi-Fi/모바일 연결을 사용할 수 있습니다.
  휴대폰 자체 통신은 제한하지 않습니다.

기본 실행(`./run.sh` 또는 `./run.sh --env`)은 `.env`에 지정한 주소만 USB로 전달합니다.
목록의 중복 IP는 한 번만 추가합니다. 도메인 개수에 별도 제한은 없습니다.

중지는 Ctrl+C입니다. 전체 트래픽을 USB로 공유하려면 다음처럼 실행하세요.

```bash
./run.sh --all
```

## 연결 문제 확인

휴대폰의 Termux 앱에서 직접 실행하세요.

```bash
timeout 10s termux-battery-status
echo $?
termux-usb -l
adb devices
```

배터리 조회 결과 없이 종료 코드 `124`가 나오면 Termux:API 응답부터 확인해야 합니다.
Termux:API 앱 설치 여부와 두 앱의 설치 출처가 같은지 확인하세요.
`pkg install termux-api` 패키지와 Termux:API 앱은 둘 다 필요합니다.
USB 목록이 `[]`면 케이블과 USB 제어 설정을 확인하고, ADB가 `unauthorized`면
태블릿에서 디버깅 요청을 승인하세요. 서버 경로 설정은 USB 연결 문제를 해결하지 않습니다.

## 구조와 빌드

[Gnirehtet](https://github.com/Genymobile/gnirehtet)은 원래 PC의 인터넷을
안드로이드에 공유하는 프로젝트입니다. 원본 termux-gnirehtet은 중계 프로그램을
ARM64 Termux용으로 빌드하고 [termux-adb](https://github.com/nohajc/termux-adb)로
안드로이드 기기 간 ADB 연결을 지원합니다.
서버 경로 스크립트는 gnirehtet의 `-r` 및 `-d` 옵션을 사용합니다.

중계 프로그램을 직접 빌드하려면 Rust/Cargo를 준비하고 `./build-gnirehtet.sh`를
실행하세요. 결과 실행 파일은 스크립트를 실행한 폴더에 생성됩니다.
포함된 APK는 [Gnirehtet 공식 릴리스](https://github.com/Genymobile/gnirehtet/releases)에서
가져온 것입니다. 앱 빌드는 [개발 안내](https://github.com/Genymobile/gnirehtet/blob/master/DEVELOP.md)를 참고하세요.

## 라이선스

이 저장소의 라이선스는 [MIT](LICENSE)입니다. 기반 Gnirehtet 프로젝트는
Apache-2.0 라이선스를 사용합니다.
