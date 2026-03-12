# OTA E2E Test Guide

이 문서는 `/home/jeongmin/OTA_HeadUnit_Itg` 통합 스택 기준으로
RAUC OTA End-to-End 테스트를 실행하는 절차를 정리합니다.

## 1. 빌드 필요 여부

| 상황 | Yocto `des-image` 재빌드 | `des-hu-bundle` 빌드 |
|---|---|---|
| 이번에 반영한 보안 기능(SHA256, 명령 서명 검증, post-write verify)이 디바이스에 아직 없음 | 필요 | 필요 |
| 디바이스가 이미 최신 통합 이미지(ota-backend/openssl/e2fsprogs/공개키 포함)로 올라가 있음 | 선택 | 필요 |
| 앱/루트FS 변경 없이 OTA 서버만 점검 | 불필요 | 선택 |

핵심:
- 디바이스가 옛 이미지면, OTA 명령 서명 검증/공개키 경로 불일치로 실패할 수 있습니다.
- 서버 서명키를 새로 만들면 디바이스 공개키와 반드시 짝이 맞아야 합니다.

## 2. 사전 준비 (처음 1회)

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg

# RAUC + ed25519 키 생성 (최초 1회)
./ota/tools/ota-generate-keys.sh
```

주의:
- 디바이스에 이미 공개키가 배포된 뒤 `ota-generate-keys.sh`를 다시 실행하면
  서버 개인키가 바뀌어 `SIGNATURE_VERIFY_FAILED`가 발생할 수 있습니다.

## 3. 빌드

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg

# Yocto 레이어/환경 준비
./ota/tools/yocto-init.sh

# 디바이스 이미지 (필요한 경우에만)
./ota/tools/build-image.sh

# OTA 번들 (E2E 필수)
./ota/tools/build-rauc-bundle.sh
```

산출물 위치:
- 번들: `out/*.raucb`
- 이미지: `out/*.wic.bz2`, `out/*.ext4.bz2`

## 4. 서버 스택 기동

포트 충돌이 잦으므로 먼저 기존 `yg` 스택을 내립니다.

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg

docker ps --filter 'name=ota_headunit_yg-' -q | xargs -r docker stop
./ota/tools/ota-stack-up.sh
docker compose -f docker-compose.ota-stack.yml ps
```

기본 포트:
- OTA_GH API: `8080`
- OTA_GH Dashboard: `3001`
- OTA_VLM Backend: `4000`
- OTA_VLM MySQL(host): `3307`

## 5. 환경값 체크 (중요)

`.env`에서 아래 2개는 반드시 실제 네트워크와 맞아야 합니다.

1. `OTA_GH_FIRMWARE_BASE_URL`
2. `OTA_GH_LOCAL_DEVICE_MAP`

예시:
```dotenv
OTA_GH_FIRMWARE_BASE_URL=http://192.168.86.33:8080
OTA_GH_LOCAL_DEVICE_MAP=vw-ivi-0026@192.168.86.250:8080
```

설명:
- `FIRMWARE_BASE_URL`은 디바이스가 `.raucb`를 다운로드할 실제 URL입니다.
- `LOCAL_DEVICE_MAP`은 OTA_GH가 HTTP-first 트리거를 보낼 디바이스 주소입니다.

변경 후:
```bash
docker compose -f docker-compose.ota-stack.yml up -d
```

## 6. 디바이스 상태 확인

디바이스에서:

```bash
systemctl status ota-backend rauc
journalctl -u ota-backend -n 200 --no-pager
ls -l /etc/ota-backend/keys/ota-signing.pub
```

호스트에서 디바이스 health 확인:

```bash
curl -sS http://<DEVICE_IP>:8080/health
```

## 7. OTA E2E 실행

### 7-1. 번들 업로드

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
BUNDLE="$(ls -t out/*.raucb | head -n1)"
VERSION="1.0.1-e2e1"

curl -sS -X POST http://localhost:8080/api/v1/admin/firmware \
  -F "file=@${BUNDLE}" \
  -F "version=${VERSION}" \
  -F "release_notes=E2E ${VERSION}"
```

### 7-2. 차량 ID 확인

```bash
curl -sS http://localhost:8080/api/v1/vehicles
```

### 7-3. 트리거

```bash
VEHICLE_ID="vw-ivi-0026"

curl -sS -X POST http://localhost:8080/api/v1/admin/trigger-update \
  -H "Content-Type: application/json" \
  -d "{\"vehicle_id\":\"${VEHICLE_ID}\",\"version\":\"${VERSION}\",\"force\":true}"
```

`force=true`는 오프라인/최근 heartbeat 정책으로 차단되는 상황을 우회할 때 유용합니다.

## 8. 성공 판정 기준

디바이스 로그(`journalctl -u ota-backend -f`)에서 아래 흐름 확인:

1. `SIGNATURE OK signature verified`
2. `VERIFY OK` (SHA256/size 검증 통과)
3. `APPLY START` 이후 RAUC install 성공
4. `POST_WRITE OK`
5. 재부팅 후 `rauc status --output-format=json`에서 target slot 활성화

서버 측 확인:

```bash
docker compose -f docker-compose.ota-stack.yml logs -f ota_gh_server
```

## 9. 자주 발생하는 실패

1. `SIGNATURE_VERIFY_FAILED`
   - 서버 개인키와 디바이스 공개키 불일치
   - 키 재생성 후 디바이스 이미지/키 배포를 동기화하지 않은 경우

2. `SHA256_REQUIRED` 또는 `HASH_MISMATCH`
   - 잘못된 번들 업로드 또는 다운로드 경로/URL 불일치
   - `OTA_GH_FIRMWARE_BASE_URL` 오설정

3. `Failed to send update command`
   - `OTA_GH_LOCAL_DEVICE_MAP`의 디바이스 IP:8080 오설정
   - 디바이스 `ota-backend` 비실행 또는 방화벽 문제

4. 포트 바인딩 실패 (`3307`, `8080` 등)
   - 다른 compose 프로젝트가 같은 포트를 점유
   - 기존 컨테이너 중지 후 재시도

## 10. 종료

```bash
cd /home/jeongmin/OTA_HeadUnit_Itg
./ota/tools/ota-stack-down.sh
```
