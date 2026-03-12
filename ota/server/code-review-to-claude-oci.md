# OTA_GH OCI/PAR 변경 코드 리뷰 (for Claude)

작성일: 2026-03-06  
검토자: Codex  
검토 범위:
- `ota/server/server/app.py`
- `ota/server/server/config.py`
- `ota/server/docker-compose.yml`
- `ota/server/client/config.py`
- `ota/server/README.md`
- 참고 문서: `DES_Head-Unit/ota/code-review-request.md`, `DES_Head-Unit/ota/README.md`

## Executive Summary

OCI PAR 연동 방향 자체는 타당하지만, 현재 구현은 **업로드 성공 보장/장애 시 fallback/토큰 보안** 측면에서 운영 리스크가 큽니다.  
핵심은 다음 3가지입니다.

1. **업로드 실패 시에도 OCI URL을 강제 사용**해서 OTA 다운로드 실패를 유발할 수 있음.
2. **PAR 토큰이 로그에 노출**됨.
3. `build_oci_par_url`는 이름과 역할이 맞지 않음(“PAR 생성”이 아니라 “PAR 기반 URL 조합”).

## Findings (심각도 순)

### 1. [High] OCI 업로드 실패해도 OCI URL이 기본 경로로 사용됨
- 근거:
  - URL 생성이 `OCI_PAR_TOKEN` 존재 여부만 보고 OCI URL 우선 반환: `ota/server/server/app.py:274-281`
  - 업로드 실패 시에도 API는 성공 응답(단지 `oci_uploaded=false`) 가능: `ota/server/server/app.py:629-646`, `811-819`
  - 다운로드 API도 토큰만 있으면 무조건 OCI redirect: `ota/server/server/app.py:649-662`
- 영향도:
  - 업로드 실패/지연 시 실제 오브젝트가 없는데 OTA 클라이언트는 OCI URL로만 접근하게 되어 `404/403` 발생.
  - 결과적으로 정상 배포 직후에도 업데이트 실패율 급증 가능.
- 개선안:
  - 옵션 A: `_upload_to_oci()` 성공 시에만 OCI URL 사용(실패 시 로컬 URL fallback).
  - 옵션 B: DB에 `oci_uploaded_at`/`oci_object_key` 상태를 저장하고, `build_firmware_url()`은 해당 상태 기반으로 결정.
  - 옵션 C: `/firmware/<filename>` redirect 전에 OCI HEAD 체크 실패 시 로컬 파일 제공.

### 2. [High] PAR 토큰 로그 노출
- 근거:
  - 성공 로그에 전체 OCI URL 출력: `ota/server/server/app.py:639`
  - PAR URL 구조상 `/p/<PAR_TOKEN>/...`이므로 토큰이 그대로 로그 저장됨.
- 영향도:
  - 로그 접근 권한만 있어도 PAR 토큰 유출 가능.
  - 유출 시 허용 범위 내 object 접근 권한이 외부로 확산될 수 있음.
- 개선안:
  - URL 전체 출력 금지, `filename/object_key/status_code`만 기록.
  - 필요 시 `/p/<...>/` 구간 마스킹 후 로깅.
  - 장기적으로는 토큰 직접 노출 방식 대신 서버측 프록시/단기 서명 URL 전략 검토.

### 3. [Medium] 함수 네이밍이 동작을 오해하게 만듦 (`_build_oci_par_url`)
- 근거:
  - 함수는 PAR을 “생성”하지 않고, 이미 가진 PAR 토큰으로 object URL을 “조합”함: `ota/server/server/app.py:259-271`
- 영향도:
  - 코드 읽는 사람이 “새 PAR 발급 로직”으로 오해하기 쉬움.
  - 운영 문서/인수인계 시 용어 혼동(특히 “PAR 발급” vs “PAR URL 조합”).
- 개선안:
  - 함수명 변경 권장:
    - `compose_oci_object_url_from_par()`
    - `build_object_url_with_par_token()`
    - `get_oci_object_url()`
  - `OCI_PAR_TOKEN`도 가능하면 `OCI_PAR_PATH_TOKEN` 또는 `OCI_OBJECT_READWRITE_PAR_TOKEN`처럼 scope가 드러나게 명명.

### 4. [Medium] MQTT 기본값이 외부 고정 IP로 변경되어 로컬 개발/테스트 분리도가 낮아짐
- 근거:
  - 서버/클라이언트 default broker host가 `129.159.241.110`로 하드코딩: `ota/server/server/config.py:48`, `ota/server/client/config.py:39`
  - compose도 동일 기본값 사용: `ota/server/docker-compose.yml:47`
- 영향도:
  - `.env` 미설정 상태에서 로컬 실행 시 외부 브로커로 연결 시도.
  - 실수로 운영/공유 브로커에 테스트 트래픽 전송 가능.
- 개선안:
  - 기본값은 `localhost` 또는 빈값으로 두고, 환경별 `.env`에서만 주입.
  - `compose`에 `env_file` 분리(`.env.dev`, `.env.prod`) 권장.

### 5. [Medium] README 절차와 스크립트 인터페이스 불일치
- 근거:
  - README 업로드 예시가 `./scripts/create_firmware.sh`(인자 없음): `ota/server/README.md:62`
  - 실제 스크립트는 버전 인자 필수 (`$0 <version>`): `ota/server/scripts/create_firmware.sh:22`, `45-49`
- 영향도:
  - 문서대로 실행 시 즉시 실패, 온보딩 혼선.
- 개선안:
  - `./scripts/create_firmware.sh 1.0.1`로 수정.
  - 업로드 전용 명령은 curl 예시와 환경변수(`OTA_AUTO_UPLOAD`)를 함께 명시.

## 영향도 요약

- 안정성: **High** (OCI 업로드 장애 시 OTA 배포 실패 가능)
- 보안: **High** (PAR 토큰 로그 유출)
- 운영성: **Medium** (환경 분리 미흡, 문서 드리프트)
- 유지보수성: **Medium** (함수명 오해 소지)

## DES_Head-Unit PAR 재사용 권고 (핵심 요청 반영)

현재 DES_Head-Unit은 이미 OCI private bucket + PAR URL 체계를 운영 중입니다.

- 근거 문서:
  - PAR URL 형식 정의: `DES_Head-Unit/ota/README.md:283-295`
  - 실제 운영 release 환경: `DES_Head-Unit/ota/server/release.env` (현재 ARTIFACT/MANIFEST URL에 `<PAR_TOKEN>` 포함)

권고:
1. OTA_GH에서 신규 PAR을 임의 생성/추가하기보다, **DES_Head-Unit에서 이미 검증된 PAR scope**를 재사용.
2. 재사용 방식은 “토큰 하드코딩”이 아니라 `.env` 주입으로 통일:
   - `OCI_REGION`
   - `OCI_NAMESPACE`
   - `OCI_BUCKET`
   - `OCI_PAR_TOKEN` (민감정보, secret store 또는 로컬 비공개 `.env`)
3. `OCI_FIRMWARE_PREFIX`를 DES artifact object 규칙(`releases/<version>/...`)과 맞춰 관리.
4. 문서에 “토큰은 절대 로그/리포지토리에 남기지 않는다”를 명시.

## Claude에게 요청할 수정 항목 (우선순위)

1. `build_firmware_url()`를 “토큰 존재”가 아니라 “OCI 업로드 성공 상태” 기준으로 동작하도록 변경.
2. `_upload_to_oci()` 성공 로그에서 PAR 토큰이 포함된 URL 출력 제거.
3. `_build_oci_par_url` 함수명을 역할 기반 명칭으로 변경.
4. MQTT 기본 host 하드코딩 제거(환경 주입 강제).
5. README 업로드 명령/환경변수 설명을 실제 스크립트 동작과 일치시킬 것.

## 참고 (검증 상태)

- Python 문법 검증: `python3 -m py_compile`로 관련 파일 컴파일 확인 완료.
- 통합/런타임 테스트는 본 리뷰에서 수행하지 않음(OCI 실연동 및 브로커 연결 테스트 미실시).
