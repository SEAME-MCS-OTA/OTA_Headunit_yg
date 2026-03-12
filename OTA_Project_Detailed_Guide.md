# OTA Project Detailed Guide

이 문서는 `/home/jeongmin/OTA_HeadUnit_Itg` 통합 리포지토리에서
DES Head-Unit 시스템에 RAUC 기반 OTA를 적용하고 운영하는 전체 절차를 정리한 실행 가이드다.

## 1. 목표와 범위

이 프로젝트의 목표는 아래 2가지를 동시에 만족하는 것이다.

1. DES 앱 스택 유지
- `Head-Unit`, `DES_Instrument-Cluster`, Weston/Qt6 기반 UI 유지

2. OTA 체계 전환
- 기존 커스텀 OTA 경로를 제거하고 `RAUC + ota-backend + OTA_GH + OTA_VLM` 체계로 통합

## 2. 현재 부팅/OTA 전략

- 플랫폼: Raspberry Pi 4 (`raspberrypi4-64`)
- A/B rootfs 슬롯: `/dev/mmcblk0p2`(A), `/dev/mmcblk0p3`(B)
- 부트 체인: Raspberry Pi firmware direct boot + `/boot/cmdline.txt` root 전환
- U-Boot: 비활성화 (`RPI_USE_U_BOOT=0`)
- OTA 설치: `rauc install <bundle.raucb>`
- 보안 검증:
  - OTA 명령 서명 검증(ed25519)
  - 번들 SHA256/size 검증
  - post-write 검증(`e2fsck`)

## 3. 저장소 핵심 경로

```text
OTA_HeadUnit_Itg/
├── ARCHITECTURE.md
├── OTA_Project_Detailed_Guide.md
├── OTA_E2E_TEST_GUIDE.md
├── docker-compose.ota-stack.yml
├── ota/
│   ├── client/
│   ├── server/
│   ├── OTA_VLM/
│   ├── keys/
│   │   ├── rauc/
│   │   └── ed25519/
│   └── tools/
│       ├── yocto-init.sh
│       ├── build-image.sh
│       ├── build-rauc-bundle.sh
│       ├── ota-generate-keys.sh
│       ├── ota-stack-up.sh
│       └── ota-stack-down.sh
├── yocto-workspace/
│   └── meta-custom/
│       ├── meta-env/
│       └── meta-app/
└── out/
```

## 4. 사전 준비

## 4.1 필수 도구

- Docker / Docker Compose
- bmap-tools (`bmaptool`)
- Yocto 빌드 필수 패키지 (Ubuntu build deps)

## 4.2 디스크 여유 권장치

- 최소 여유: 40GB
- 안정 여유: 50GB+

빌드 중단이 반복되면 먼저 아래를 정리한다.

- `yocto-workspace/build-des/tmp-glibc`
- 오래된 `out/*.wic.bz2`, `out/*.ext4.bz2`, `out/*.raucb`

## 4.3 현재 local.conf 운영 포인트

`yocto-workspace/build-des/conf/local.conf`에서 아래가 반영되어 있어야 한다.

- `MACHINE = "raspberrypi4-64"`
- `DISTRO = "des"`
- `BB_NUMBER_THREADS`, `PARALLEL_MAKE` (호스트 상황에 맞춰 조정)
- `INHERIT += "rm_work"` (빌드 중간 산출물 정리)
- `BB_DISKMON_DIRS` (디스크 조기 중단 임계치)

## 5. 키 관리 표준

키는 리포 내부 표준 경로를 사용한다.

- RAUC 서명키: `ota/keys/rauc/rauc.key.pem`
- RAUC 인증서: `ota/keys/rauc/rauc.cert.pem`
- OTA 명령 서명키: `ota/keys/ed25519/ota-signing.key`
- OTA 명령 공개키: `ota/keys/ed25519/ota-signing.pub`

생성 명령:

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
./ota/tools/ota-generate-keys.sh
```

주의:
- 키를 다시 생성하면 기존 디바이스에 배포된 공개키와 불일치할 수 있다.
- 키 재생성 후에는 이미지/디바이스 키 배포를 동기화해야 한다.

## 6. Yocto 빌드 플로우

## 6.1 빌드 환경 초기화

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
./ota/tools/yocto-init.sh
```

## 6.2 초기 이미지 빌드

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
./ota/tools/build-image.sh
```

성공 시 주요 산출물:

- `out/des-image-raspberrypi4-64.rootfs.wic.bz2`
- `out/des-image-raspberrypi4-64.rootfs.wic.bmap`
- `out/des-image-raspberrypi4-64.rootfs.ext4.bz2`

## 6.3 OTA 번들 빌드

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
./ota/tools/build-rauc-bundle.sh
```

성공 시:

- `out/*.raucb`

## 7. 초기 물리 플래싱 (첫 부팅용)

초기 플래싱은 `*.raucb`가 아니라 `*.wic.bz2 + *.wic.bmap`을 사용한다.

```bash
IMG_DIR=/home/jeongmin/OTA_HeadUnit_Itg/out
DEV=/dev/sdX

sudo umount ${DEV}?* 2>/dev/null || true
sudo umount ${DEV}p* 2>/dev/null || true

sudo bmaptool copy \
  --bmap "$IMG_DIR/des-image-raspberrypi4-64.rootfs.wic.bmap" \
  "$IMG_DIR/des-image-raspberrypi4-64.rootfs.wic.bz2" \
  "$DEV"

sync
```

주의:
- `DEV`가 시스템 디스크가 아닌 SD/USB 대상 디스크인지 반드시 확인한다.

## 8. OTA 서버 스택 실행

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
./ota/tools/ota-stack-up.sh
```

중지:

```bash
./ota/tools/ota-stack-down.sh
```

기본 포트:
- OTA_GH API: `8080`
- OTA_GH Dashboard: `3001`
- OTA_VLM Backend: `4000`
- OTA_VLM DB(Host): `3307`

포트 충돌 시:
- 기존 컨테이너 정리 후 재기동
- `.env`에서 포트 변경

## 9. E2E OTA 테스트 기본 순서

## 9.1 디바이스 상태 확인

```bash
systemctl status ota-backend rauc
journalctl -u ota-backend -n 200 --no-pager
rauc status --output-format=json
```

## 9.2 서버에 번들 업로드

```bash
curl -sS -X POST http://localhost:8080/api/v1/admin/firmware \
  -F "file=@/home/jeongmin/OTA_HeadUnit_Itg/out/<bundle>.raucb" \
  -F "version=1.0.0-test" \
  -F "release_notes=E2E test"
```

## 9.3 트리거

```bash
curl -sS -X POST http://localhost:8080/api/v1/admin/trigger-update \
  -H "Content-Type: application/json" \
  -d '{"vehicle_id":"vw-ivi-0026","version":"1.0.0-test","force":true}'
```

## 9.4 성공 판정 로그

디바이스 로그에서 아래 흐름을 확인한다.

1. `SIGNATURE OK ...`
2. `VERIFY OK`
3. `APPLY START` -> RAUC install 성공
4. `POST_WRITE OK`
5. 재부팅 후 활성 슬롯 전환 확인

## 10. 자주 발생하는 이슈

## 10.1 저장공간 부족

증상:
- 빌드 도중 비정상 중단
- `No space left on device`

조치:
- `tmp-glibc` 정리
- 스레드 수 하향 (`BB_NUMBER_THREADS`, `PARALLEL_MAKE`)
- `rm_work` 유지

## 10.2 OTA 명령 서명 실패

증상:
- `SIGNATURE_VERIFY_FAILED`

원인:
- 서버 개인키와 디바이스 공개키 불일치

조치:
- 키 재생성 여부 점검
- 디바이스 이미지/키 배포 동기화

## 10.3 SHA256 검증 실패

증상:
- `SHA256_REQUIRED` 또는 hash mismatch

조치:
- 업로드한 번들과 메타데이터 일치 여부 확인
- `FIRMWARE_BASE_URL` 경로 점검

## 10.4 트리거 실패

증상:
- `Failed to send update command`

조치:
- 디바이스 `vehicle_id`, `LOCAL_DEVICE_MAP`, 네트워크 도달성 확인
- `ota-backend` 서비스 상태 확인

## 11. 운영 권장사항

1. 키 재생성은 계획적으로 수행한다.
2. 초기 이미지(`wic`)와 OTA 번들(`raucb`) 역할을 혼동하지 않는다.
3. 빌드 캐시/디스크 정책을 팀 공통 규칙으로 고정한다.
4. E2E 성공 로그 패턴을 체크리스트로 표준화한다.
5. OTA 실패 시 롤백/복구 절차를 문서화한다.

## 12. 관련 문서

- `README.md`
- `ARCHITECTURE.md`
- `OTA_E2E_TEST_GUIDE.md`
