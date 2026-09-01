#!/bin/bash
#############################################################
# Samsung Cloud Platform v2 자격 증명 공급자(SAML) SSO 실습
# [설정] SAML Client 및 Mapper 설정          (Virtual Server 에서 실행)
#
# 사전 조건
#   - idp_keycloak_install.sh 실행 완료
#   - SCP 콘솔에 자격 증명 공급자 등록 및 역할 생성 완료
#   - SP Entity ID / 자격 증명 공급자 SRN / 역할 SRN 확보
#
# 사용법
#   chmod +x idp_keycloak_config.sh
#   ./idp_keycloak_config.sh
#
# 수행 내용
#   1) SAML Client 생성
#   2) Client Scope 에 Role 할당
#   3) Protocol Mapper 3종 생성
#   4) 설정 검증
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
# 0. 설치 단계 설정값 불러오기
#############################################################
step "0. 설치 단계 설정값 불러오기"

if [ -f "${STATE_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${STATE_FILE}"
    ok "${STATE_FILE} 에서 설정값을 불러왔습니다."
else
    warn "${STATE_FILE} 을 찾을 수 없습니다. 값을 직접 입력하십시오."
fi

#############################################################
# 1. 입력값 수집
#############################################################
step "1. 설정값 입력"

# 실습 표준값 (설치 스크립트와 동일해야 합니다)
REALM="creative-energy"
ROLE_NAME="scp-admin"
SCP_REGION="kr-west1"
SCP_OFFERING="e"
SSO_URL_NAME="scp"

# Public NAT IP 와 관리자 ID 는 설치 스크립트가 저장한 값을 사용합니다.
# 상태 파일이 없을 때만 직접 입력받습니다.
if [ -z "${PUBLIC_IP}" ] || [ -z "${KC_ADMIN}" ]; then
    echo
    echo "  Keycloak 정보 (설치 단계 설정값을 찾지 못했습니다)"
    [ -n "${PUBLIC_IP}" ] || ask PUBLIC_IP "Public NAT IP[ceweb]"
    [ -n "${KC_ADMIN}"  ] || ask KC_ADMIN  "Keycloak 관리자 ID"
fi

echo
echo "  Samsung Cloud Platform 정보"
echo "  (콘솔의 IAM > 자격 증명 공급자 / 역할 상세 화면에서 확인)"
echo
ask SCP_ACCOUNT_ID "SCP Account ID"
ask SP_ENTITY_ID   "SP Entity ID (로그인 URL 마지막 경로, SAMLSP...)"
ask PROVIDER_SRN   "자격 증명 공급자 SRN (srn:...:iam:saml-provider/...)"
ask ROLE_SRN       "역할 SRN (srn:...:iam:role/...)"

# 파생 값
CONSOLE_HOST="console.${SCP_REGION}.${SCP_OFFERING}.samsungsdscloud.com"
ACS_BASE="https://${CONSOLE_HOST}/${SCP_ACCOUNT_ID}/saml/acs"
ATTR_ROLE="https://${CONSOLE_HOST}/SAML/Attributes/Role"
ATTR_SESSION="https://${CONSOLE_HOST}/SAML/Attributes/RoleSessionName"
NEW_ROLE_NAME="${ROLE_SRN},${PROVIDER_SRN}"

echo
step "입력값 확인"
cat <<EOF

  Realm             : ${REALM}
  Keycloak Role     : ${ROLE_NAME}

  SP Entity ID      : ${SP_ENTITY_ID}
  ACS URL           : ${ACS_BASE}/${SP_ENTITY_ID}
  Role 속성명       : ${ATTR_ROLE}
  Session 속성명    : ${ATTR_SESSION}
  Role 속성값       : ${NEW_ROLE_NAME}
  IdP-initiated URL : http://${PUBLIC_IP}:8080/realms/${REALM}/protocol/saml/clients/${SSO_URL_NAME}

EOF

confirm "위 내용으로 진행하시겠습니까?" || fail "취소되었습니다."

#############################################################
# 2. Keycloak 접속
#############################################################
step "2. Keycloak 관리자 인증"

KC_IMAGE="quay.io/keycloak/keycloak:latest"
KC=$(sudo docker ps -qf ancestor=${KC_IMAGE})
[ -n "$KC" ] || fail "실행 중인 Keycloak 컨테이너가 없습니다. idp_keycloak_install.sh 를 먼저 실행하십시오."
ok "컨테이너 ID: ${KC}"

kcadm()       { sudo docker exec    "$KC" /opt/keycloak/bin/kcadm.sh "$@"; }
kcadm_stdin() { sudo docker exec -i "$KC" /opt/keycloak/bin/kcadm.sh "$@"; }

# 설치 단계에서 만든 kcadm 세션이 살아 있으면 재사용하고,
# 만료된 경우에만 관리자 비밀번호를 입력받습니다.
if kcadm get realms/master --fields realm >/dev/null 2>&1; then
    ok "설치 단계에서 생성한 관리자 세션을 재사용합니다."
else
    info "관리자 세션이 만료되었습니다. 비밀번호를 입력하십시오."
    ask_secret KC_ADMIN_PW "Keycloak 관리자 비밀번호 (${KC_ADMIN})"
    kcadm config credentials --server http://localhost:8080 \
        --realm master --user "${KC_ADMIN}" --password "${KC_ADMIN_PW}" >/dev/null 2>&1 \
        || fail "관리자 인증 실패. 비밀번호를 확인하십시오."
    ok "관리자 인증 완료"
fi

kcadm get "realms/${REALM}" >/dev/null 2>&1 \
    || fail "Realm '${REALM}' 이 존재하지 않습니다. idp_keycloak_install.sh 를 먼저 실행하십시오."

ROLE_ID=$(kcadm get "roles/${ROLE_NAME}" -r "${REALM}" --fields id --format csv --noquotes 2>/dev/null | tr -d '\r' | head -1)
[ -n "$ROLE_ID" ] || fail "Role '${ROLE_NAME}' 을 찾을 수 없습니다. idp_keycloak_install.sh 를 먼저 실행하십시오."
ok "Role 확인 (id: ${ROLE_ID})"

#############################################################
# 3. SAML Client 생성
#############################################################
step "3. SAML Client 생성 : ${SP_ENTITY_ID}"

CID=$(kcadm get clients -r "${REALM}" -q clientId="${SP_ENTITY_ID}" --fields id --format csv --noquotes 2>/dev/null | tr -d '\r' | head -1)

if [ -n "$CID" ]; then
    warn "Client 가 이미 존재합니다. 삭제 후 다시 생성합니다."
    kcadm delete "clients/${CID}" -r "${REALM}" || fail "기존 Client 삭제 실패"
fi

kcadm_stdin create clients -r "${REALM}" -f - <<EOF
{
  "clientId"            : "${SP_ENTITY_ID}",
  "name"                : "Samsung Cloud Platform",
  "protocol"            : "saml",
  "enabled"             : true,
  "frontchannelLogout"  : true,
  "fullScopeAllowed"    : false,
  "redirectUris"        : [ "${ACS_BASE}/*" ],
  "adminUrl"            : "${ACS_BASE}/${SP_ENTITY_ID}",
  "defaultClientScopes" : [],
  "optionalClientScopes": [],
  "attributes": {
    "saml_idp_initiated_sso_url_name"       : "${SSO_URL_NAME}",
    "saml_name_id_format"                   : "username",
    "saml_force_name_id_format"             : "false",
    "saml.force.post.binding"               : "true",
    "saml.authnstatement"                   : "true",
    "saml.server.signature"                 : "true",
    "saml.assertion.signature"              : "true",
    "saml.client.signature"                 : "false",
    "saml.signature.algorithm"              : "RSA_SHA256",
    "saml_signature_canonicalization_method": "http://www.w3.org/2001/10/xml-exc-c14n#",
    "saml.server.signature.keyinfo.xmlSigKeyInfoKeyNameTransformer": "NONE"
  }
}
EOF
[ $? -eq 0 ] || fail "Client 생성 실패"

CID=$(kcadm get clients -r "${REALM}" -q clientId="${SP_ENTITY_ID}" --fields id --format csv --noquotes | tr -d '\r' | head -1)
[ -n "$CID" ] || fail "생성한 Client 를 찾을 수 없습니다."
ok "Client 생성 완료 (id: ${CID})"

#############################################################
# 4. Client Scope 에 Role 할당
#############################################################
step "4. Client Scope 에 Role 할당"

# fullScopeAllowed=false 이므로, 여기에 할당한 역할만 Assertion 에 포함됩니다.
# 이 단계를 생략하면 Role 속성이 통째로 누락됩니다.
printf '[{"id":"%s","name":"%s"}]' "${ROLE_ID}" "${ROLE_NAME}" \
    | kcadm_stdin create "clients/${CID}/scope-mappings/realm" -r "${REALM}" -f - \
    || fail "Scope 할당 실패"
ok "Scope 에 '${ROLE_NAME}' 할당 완료"

#############################################################
# 5. Protocol Mapper 생성
#############################################################
step "5. Protocol Mapper 3종 생성"

# (1) Role list - 역할을 SCP 가 요구하는 속성명으로 출력
kcadm_stdin create "clients/${CID}/protocol-mappers/models" -r "${REALM}" -f - <<EOF
{
  "name"          : "Session Role",
  "protocol"      : "saml",
  "protocolMapper": "saml-role-list-mapper",
  "config": {
    "attribute.name"      : "${ATTR_ROLE}",
    "attribute.nameformat": "Basic",
    "friendly.name"       : "Session Role",
    "single"              : "false"
  }
}
EOF
[ $? -eq 0 ] || fail "Session Role 매퍼 생성 실패"
ok "Session Role (Role list) 생성"

# (2) User Property - 사용자명을 RoleSessionName 으로 전달
kcadm_stdin create "clients/${CID}/protocol-mappers/models" -r "${REALM}" -f - <<EOF
{
  "name"          : "Session Name",
  "protocol"      : "saml",
  "protocolMapper": "saml-user-property-mapper",
  "config": {
    "user.attribute"      : "username",
    "attribute.name"      : "${ATTR_SESSION}",
    "attribute.nameformat": "Basic",
    "friendly.name"       : "Session Name"
  }
}
EOF
[ $? -eq 0 ] || fail "Session Name 매퍼 생성 실패"
ok "Session Name (User Property) 생성"

# (3) Role Name Mapper - Keycloak Role 이름을 SCP SRN 쌍으로 변환
kcadm_stdin create "clients/${CID}/protocol-mappers/models" -r "${REALM}" -f - <<EOF
{
  "name"          : "SCP Role SRN",
  "protocol"      : "saml",
  "protocolMapper": "saml-role-name-mapper",
  "config": {
    "role"         : "${ROLE_NAME}",
    "new.role.name": "${NEW_ROLE_NAME}"
  }
}
EOF
[ $? -eq 0 ] || fail "SCP Role SRN 매퍼 생성 실패"
ok "SCP Role SRN (Role Name Mapper) 생성"

#############################################################
# 6. 설정 검증
#############################################################
step "6. 설정 검증"

echo
info "Client Scope 에 할당된 Role (비어 있으면 안 됩니다)"
kcadm get "clients/${CID}/scope-mappings/realm" -r "${REALM}" --fields name

echo
info "생성된 Protocol Mapper (3개여야 합니다)"
kcadm get "clients/${CID}/protocol-mappers/models" -r "${REALM}" --fields name,protocolMapper

#############################################################
# 완료 안내
#############################################################
step "설정 완료"

cat <<EOF

  [1] SSO 로그인 테스트 (브라우저에서 접속)

      http://${PUBLIC_IP}:8080/realms/${REALM}/protocol/saml/clients/${SSO_URL_NAME}

      로그인 계정 : ${KC_USER:-<설치 단계에서 만든 사용자>} / (설치 단계에서 입력한 비밀번호)

  [2] Keycloak 관리 콘솔

      http://${PUBLIC_IP}:8080

  [3] 로그인이 실패하면

      개발자 도구(F12) > Network > Preserve log 체크 후 로그인
      Filter 에 'acs' 입력 > POST 요청 > Payload 의 SAMLResponse 를 복사
      아래 명령으로 디코딩하여 속성 이름과 값을 확인하십시오. (로컬 PC PowerShell)

      [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("<붙여넣기>"))

EOF

ok "설정이 완료되었습니다."
