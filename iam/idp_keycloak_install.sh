#!/bin/bash
#############################################################
# Samsung Cloud Platform v2 자격 증명 공급자(SAML) SSO 실습
# [설치] Keycloak 설치 및 기본 구성          (Virtual Server 에서 실행)
#
# 사용법
#   chmod +x idp_keycloak_install.sh
#   ./idp_keycloak_install.sh
#
# 수행 내용
#   1) OS 업데이트
#   2) Docker 설치
#   3) Keycloak 컨테이너 기동
#   4) Realm / 사용자 / Role 생성
#   5) SAML 메타데이터 URL 안내
#
# 이 스크립트가 끝나면 메타데이터를 SCP 에 등록한 뒤
# idp_keycloak_config.sh 를 실행합니다.
#############################################################

set -o pipefail

STATE_FILE="${HOME}/.scp-keycloak-lab.env"

#############################################################
# 출력 helper
#############################################################
C_INFO='\033[0;36m'; C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_ERR='\033[0;31m'; C_OFF='\033[0m'

info()  { echo -e "${C_INFO}[*]${C_OFF} $*"; }
ok()    { echo -e "${C_OK}[+]${C_OFF} $*"; }
warn()  { echo -e "${C_WARN}[!]${C_OFF} $*"; }
fail()  { echo -e "${C_ERR}[x]${C_OFF} $*"; exit 1; }
step()  { echo; echo -e "${C_INFO}=====================================================${C_OFF}"; echo -e "${C_INFO} $*${C_OFF}"; echo -e "${C_INFO}=====================================================${C_OFF}"; }

# ask VAR "질문" "기본값"   - 기본값이 없으면 입력할 때까지 반복
ask() {
    local __var=$1 __prompt=$2 __default=$3 __input=""
    if [ -n "$__default" ]; then
        read -rp "  ${__prompt} [${__default}]: " __input
        __input=${__input:-$__default}
    else
        while [ -z "$__input" ]; do
            read -rp "  ${__prompt}: " __input
        done
    fi
    printf -v "$__var" '%s' "$__input"
}

# ask_secret VAR "질문"   - 화면에 표시되지 않으며, 입력할 때까지 반복
ask_secret() {
    local __var=$1 __prompt=$2 __input=""
    while [ -z "$__input" ]; do
        read -rsp "  ${__prompt}: " __input; echo
    done
    printf -v "$__var" '%s' "$__input"
}

confirm() {
    local __input=""
    read -rp "  $1 (y/N): " __input
    [[ "$__input" =~ ^[Yy]$ ]]
}

#############################################################
# 0. 입력값 수집
#############################################################
step "0. 설정값 입력"

echo
echo "  Keycloak 이 설치된 서버의 Public NAT IP 를 입력하십시오."
echo "  브라우저가 Keycloak 에 접속할 주소이며, SAML 메타데이터에 기록됩니다."
echo
ask PUBLIC_IP "Public NAT IP[ceweb]"

echo
echo "  Keycloak 관리자 계정 (필수 입력)"
ask KC_ADMIN "관리자 ID"
ask_secret KC_ADMIN_PW "관리자 비밀번호"

# 실습 표준값 (변경이 필요하면 이 두 줄을 수정하십시오)
REALM="creative-energy"
ROLE_NAME="scp-admin"

echo
echo "  Keycloak 실습 사용자"
ask KC_USER "사용자 ID" "leonard"
ask_secret KC_USER_PW "사용자 비밀번호 (필수 입력)"

echo
step "입력값 확인"
cat <<EOF

  Keycloak 주소  : http://${PUBLIC_IP}:8080
  관리자 ID      : ${KC_ADMIN}
  Realm          : ${REALM}
  사용자 ID      : ${KC_USER}
  Keycloak Role  : ${ROLE_NAME}

EOF

confirm "위 내용으로 진행하시겠습니까?" || fail "취소되었습니다."

#############################################################
# 1. OS 업데이트
#############################################################
step "1. OS 업데이트"

info "OS 패키지를 업데이트합니다. (수 분 소요)"
sudo dnf -y update || warn "업데이트 중 일부 오류가 발생했습니다. 계속 진행합니다."
ok "OS 업데이트 완료"

#############################################################
# 2. Docker 설치
#############################################################
step "2. Docker 설치"

if command -v docker >/dev/null 2>&1; then
    ok "Docker 가 이미 설치되어 있습니다: $(docker --version)"
else
    info "Docker 저장소를 추가합니다."
    sudo dnf -y install dnf-plugins-core || fail "dnf-plugins-core 설치 실패"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
        || fail "Docker 저장소 추가 실패 (인터넷 아웃바운드 443 허용 여부를 확인하십시오)"

    info "Docker 를 설치합니다."
    sudo dnf -y install docker-ce docker-ce-cli containerd.io || fail "Docker 설치 실패"
    ok "Docker 설치 완료"
fi

sudo systemctl enable --now docker || fail "Docker 서비스 기동 실패"
ok "Docker 서비스 실행 중"

#############################################################
# 3. Keycloak 기동
#############################################################
step "3. Keycloak 컨테이너 기동"

warn "SCP 의 Security Group 과 Internet Gateway Firewall 에 8080 인바운드가 허용되어야 합니다."

KC_IMAGE="quay.io/keycloak/keycloak:latest"
EXISTING=$(sudo docker ps -qf ancestor=${KC_IMAGE})

if [ -n "$EXISTING" ]; then
    warn "이미 실행 중인 Keycloak 컨테이너가 있습니다: ${EXISTING}"
    if confirm "기존 컨테이너를 삭제하고 새로 기동하시겠습니까? (설정이 모두 초기화됩니다)"; then
        sudo docker rm -f "$EXISTING" >/dev/null
        ok "기존 컨테이너를 삭제했습니다."
        EXISTING=""
    else
        info "기존 컨테이너를 그대로 사용합니다."
    fi
fi

if [ -z "$EXISTING" ]; then
    info "Keycloak 을 기동합니다. (이미지 다운로드에 시간이 걸릴 수 있습니다)"
    sudo docker run -d -p 8080:8080 \
        -e KC_BOOTSTRAP_ADMIN_USERNAME="${KC_ADMIN}" \
        -e KC_BOOTSTRAP_ADMIN_PASSWORD="${KC_ADMIN_PW}" \
        -e KC_HOSTNAME="http://${PUBLIC_IP}:8080" \
        ${KC_IMAGE} start-dev >/dev/null || fail "Keycloak 기동 실패"
fi

KC=$(sudo docker ps -qf ancestor=${KC_IMAGE})
[ -n "$KC" ] || fail "Keycloak 컨테이너를 찾을 수 없습니다."
ok "컨테이너 ID: ${KC}"

kcadm() { sudo docker exec "$KC" /opt/keycloak/bin/kcadm.sh "$@"; }

#############################################################
# 4. kcadm 인증 (기동 완료까지 대기)
#############################################################
step "4. Keycloak 기동 대기 및 관리자 인증"

info "Keycloak 기동을 기다립니다. 최대 3분 대기합니다."
for i in $(seq 1 36); do
    if kcadm config credentials --server http://localhost:8080 \
        --realm master --user "${KC_ADMIN}" --password "${KC_ADMIN_PW}" >/dev/null 2>&1; then
        ok "관리자 인증 완료"
        AUTH_OK=1
        break
    fi
    printf "."
    sleep 5
done
echo
[ "${AUTH_OK:-0}" = "1" ] || fail "Keycloak 기동 또는 인증에 실패했습니다. 'sudo docker logs ${KC}' 로 확인하십시오."

#############################################################
# 5. master Realm HTTPS 강제 해제
#############################################################
step "5. master Realm sslRequired 해제"

kcadm update realms/master -s sslRequired=NONE || fail "master Realm 설정 실패"
ok "master Realm 의 HTTPS 강제를 해제했습니다."

#############################################################
# 6. Realm 생성
#############################################################
step "6. Realm 생성 : ${REALM}"

if kcadm get "realms/${REALM}" >/dev/null 2>&1; then
    warn "Realm '${REALM}' 이 이미 존재합니다. sslRequired 만 갱신합니다."
    kcadm update "realms/${REALM}" -s sslRequired=NONE
else
    kcadm create realms -s realm="${REALM}" -s enabled=true -s sslRequired=NONE \
        || fail "Realm 생성 실패"
    ok "Realm '${REALM}' 생성 완료"
fi

#############################################################
# 7. 사용자 생성
#############################################################
step "7. 사용자 생성 : ${KC_USER}"

USER_ID=$(kcadm get users -r "${REALM}" -q username="${KC_USER}" --fields id --format csv --noquotes 2>/dev/null | tr -d '\r' | head -1)

if [ -n "$USER_ID" ]; then
    warn "사용자 '${KC_USER}' 가 이미 존재합니다. 비밀번호만 재설정합니다."
else
    # SAML 인증에는 username 만 사용되므로 이메일 / 이름 / 성은 설정하지 않습니다.
    kcadm create users -r "${REALM}" \
        -s username="${KC_USER}" \
        -s enabled=true || fail "사용자 생성 실패"
    ok "사용자 생성 완료"
fi

# --temporary 는 값을 받지 않는 플래그입니다.
# 생략하면 영구 비밀번호로 설정되어 첫 로그인 시 변경 화면이 뜨지 않습니다.
kcadm set-password -r "${REALM}" --username "${KC_USER}" \
    --new-password "${KC_USER_PW}" || fail "비밀번호 설정 실패"
ok "비밀번호 설정 완료 (임시 비밀번호 아님)"

#############################################################
# 8. Role 생성 및 할당
#############################################################
step "8. Role 생성 및 사용자 할당 : ${ROLE_NAME}"

if kcadm get "roles/${ROLE_NAME}" -r "${REALM}" >/dev/null 2>&1; then
    warn "Role '${ROLE_NAME}' 이 이미 존재합니다."
else
    kcadm create roles -r "${REALM}" -s name="${ROLE_NAME}" || fail "Role 생성 실패"
    ok "Role 생성 완료"
fi

kcadm add-roles -r "${REALM}" --uusername "${KC_USER}" --rolename "${ROLE_NAME}" 2>/dev/null \
    && ok "사용자에게 Role 할당 완료" \
    || warn "Role 이 이미 할당되어 있습니다."

#############################################################
# 9. 상태 저장
#############################################################
step "9. 설정값 저장"

cat > "${STATE_FILE}" <<EOF
# idp_keycloak_install.sh 가 생성한 파일입니다.
# idp_keycloak_config.sh 가 기본값으로 사용합니다.
PUBLIC_IP=${PUBLIC_IP}
KC_ADMIN=${KC_ADMIN}
REALM=${REALM}
KC_USER=${KC_USER}
ROLE_NAME=${ROLE_NAME}
EOF
chmod 600 "${STATE_FILE}"
ok "설정값을 ${STATE_FILE} 에 저장했습니다. (비밀번호는 저장하지 않습니다)"

#############################################################
# 완료 안내
#############################################################
step "설치 완료 - 다음 작업 안내"

cat <<EOF

  Keycloak 기본 구성이 끝났습니다.
  이제 로컬 PC 에서 아래 작업을 진행하십시오.

  ---------------------------------------------------------
  [A] SAML 메타데이터 내려받기 (로컬 PC 의 PowerShell)
  ---------------------------------------------------------

  curl.exe -f -o keycloak-metadata.xml http://${PUBLIC_IP}:8080/realms/${REALM}/protocol/saml/descriptor

  * PowerShell 에서는 curl 이 Invoke-WebRequest 의 별칭이므로 반드시 curl.exe 로 실행하십시오.

  브라우저로 직접 열어 저장해도 됩니다.
  http://${PUBLIC_IP}:8080/realms/${REALM}/protocol/saml/descriptor

  ---------------------------------------------------------
  [B] SCP 콘솔에서 자격 증명 공급자 등록
  ---------------------------------------------------------

  IAM > 자격 증명 공급자 > 생성
    - 자격 증명 공급자명 : ${REALM}
    - 유형               : SAML
    - 메타데이터         : keycloak-metadata.xml 첨부

  등록 후 상세 화면에서 아래 두 값을 기록하십시오.

    (1) SP Entity ID
        '로그인 URL' 경로의 마지막 값입니다.
        https://console.<region>.<offering>.samsungsdscloud.com/<account_id>/saml/acs/SAMLSP..........
                                                                                       ^^^^^^^^^^^^^^ 이 부분

    (2) 자격 증명 공급자 SRN
        srn:e::<account_id>:::iam:saml-provider/SAML-PROVIDER-..........

  ---------------------------------------------------------
  [C] SCP 콘솔에서 역할 생성
  ---------------------------------------------------------

  IAM > 역할 > 생성
    - 수행 주체 구분 : 자격 증명 공급자
    - Value          : ${REALM}
    - 정책           : 실습에 필요한 정책 연결

  생성 후 상세 화면에서 역할 SRN 을 기록하십시오.

    (3) 역할 SRN
        srn:e::<account_id>:::iam:role/..........

  ---------------------------------------------------------
  [D] 이 서버로 돌아와 설정 스크립트 실행
  ---------------------------------------------------------

  ./idp_keycloak_config.sh

  위 (1)(2)(3) 과 SCP Account ID 를 입력하면 나머지 설정이 완료됩니다.

EOF

ok "설치가 완료되었습니다."
