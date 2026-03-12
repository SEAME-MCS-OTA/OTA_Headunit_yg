# OTA_HeadUnit_Itg

Raspberry Pi 4 기반 DES Head-Unit/Instrument-Cluster 시스템에
**RAUC 기반 OTA(yg 스택)** 를 통합한 작업 디렉토리입니다.

- HeadUnit/Cluster 앱( Qt6/QML )은 DES 구현을 유지
- OTA는 기존 `des-ota-clientd` 커스텀 경로를 제거하고
  `ota-backend + RAUC + OTA_GH + OTA_VLM` 경로로 통합
- 이 디렉토리가 통합 작업본이며, 기존 `DES_Head-Unit`은 백업 역할

## 현재 통합 원칙

1. Yocto/Weston/HeadUnit/Cluster는 DES 경로 유지
2. OTA는 `/ota` 구조 유지
3. 기존 `des-ota-clientd` 커스텀 OTA 경로는 제거
4. 디바이스 OTA는 `ota/client` + `rauc`
5. 서버/대시보드는 `ota/server` + `ota/OTA_VLM`

## 시스템 구성

- 디바이스 측
  - `ota/client`: HTTP-first + MQTT fallback OTA 엔트리
  - `rauc`: A/B 슬롯 설치/전환/상태 관리
  - `yocto-workspace/meta-custom/meta-app/recipes-ota/rauc`
  - `yocto-workspace/meta-custom/meta-app/recipes-ota/ota-backend`
  - `yocto-workspace/meta-custom/meta-app/recipes-ota/rauc-bundle`
- 서버 측
  - `ota/server`: Flask + PostgreSQL + MQTT + Dashboard
  - `ota/OTA_VLM`: Node/MySQL 기반 관제/분류 대시보드
- 스택 실행
  - 루트 `docker-compose.ota-stack.yml`
  - `ota/tools/ota-stack-up.sh`, `ota/tools/ota-stack-down.sh`

## OTA 흐름 (통합 기준)

1. 관리자 대시보드에서 firmware(.raucb) 업로드/활성화
2. OTA_GH가 디바이스에 HTTP `POST /ota/start` 시도
3. 실패 시 MQTT fallback 명령 발행
4. OTA 명령은 `ed25519`로 서명되어 전달됨
5. `ota-backend`가 번들 다운로드 후 `SHA256/size` 검증 + 서명 검증 후 `rauc install`
6. 설치 직후 post-write 검증(`e2fsck`) 수행
7. 재부팅 후 healthcheck/mark-good 처리
8. 결과 로그가 `ota/server`/`ota/OTA_VLM`로 수집

## 디렉토리 구조

```text
OTA_HeadUnit_Itg/
├── ARCHITECTURE.md                             # 통합 아키텍처 문서
├── OTA_Project_Detailed_Guide.md              # Yocto/OTA 상세 가이드
├── OTA_E2E_TEST_GUIDE.md                      # E2E 테스트 런북
├── Head-Unit/                                  # DES 유지: Qt6/QML HU
├── DES_Instrument-Cluster/                     # DES 유지: IC 앱
├── ota/
│   ├── client/                                 # 디바이스 OTA 백엔드
│   ├── server/                                 # OTA 서버/대시보드/MQTT
│   ├── keys/
│   │   ├── rauc/                               # RAUC cert/key
│   │   └── ed25519/                            # 추가 서명키
│   └── tools/
│       ├── yocto-init.sh
│       ├── build-image.sh
│       ├── build-rauc-bundle.sh
│       ├── rauc-generate-keys.sh
│       ├── ed25519-generate-keys.sh
│       ├── ota-generate-keys.sh
│       ├── ota-stack-up.sh
│       └── ota-stack-down.sh
│   ├── OTA_VLM/                                # 관제/VLM 대시보드
├── yocto-workspace/
│   └── meta-custom/meta-app/recipes-ota/
│       ├── rauc/
│       ├── ota-backend/
│       └── rauc-bundle/
├── docker-compose.ota-stack.yml
└── out/
```

## Yocto 빌드

```bash
# 통합 키 생성 (RAUC + OTA 명령 서명용 ed25519)
./ota/tools/ota-generate-keys.sh
```

```bash
cd yocto-workspace
source poky/oe-init-build-env build-des
bitbake des-image
bitbake des-hu-bundle
```

산출물 예시:

```text
yocto-workspace/build-des/tmp-glibc/deploy/images/raspberrypi4-64/
├── des-image-*.wic.bz2
├── des-image-*.ext4.bz2
└── des-hu-bundle-*.raucb
```

## OTA 서버 스택 실행

```bash
# from repository root
./ota/tools/ota-stack-up.sh
# ...
./ota/tools/ota-stack-down.sh
```

## E2E 테스트 가이드

- 상세 실행 절차: [OTA_E2E_TEST_GUIDE.md](./OTA_E2E_TEST_GUIDE.md)
- 포함 내용:
  - 언제 Yocto 이미지를 다시 빌드해야 하는지
  - 어떤 스크립트를 어떤 순서로 실행해야 하는지
  - API 기반 OTA 트리거 예시
  - 서명/SHA256/post-write 검증 확인 포인트와 트러블슈팅

## 문서

- 아키텍처 문서: [ARCHITECTURE.md](./ARCHITECTURE.md)
- 상세 빌드/운영 가이드: [OTA_Project_Detailed_Guide.md](./OTA_Project_Detailed_Guide.md)
- E2E 테스트 런북: [OTA_E2E_TEST_GUIDE.md](./OTA_E2E_TEST_GUIDE.md)

## 빠른 점검

```bash
# 디바이스 핵심 서비스
systemctl status weston headunit instrument-cluster ota-backend

# RAUC 상태
rauc status --output-format=json

# OTA 백엔드 로그
journalctl -u ota-backend -n 200 --no-pager

# 서버 스택 상태
docker compose -f docker-compose.ota-stack.yml ps
```

## 메모

- `des-ota-clientd` 레시피/서비스는 통합 경로에서 제거됨
- `/ota` 디렉토리는 제거 대상이 아니라 통합 OTA 루트로 유지함
