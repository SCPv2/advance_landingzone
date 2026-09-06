# Landing Zone 구성


## Cloud Control 생성

**&#128906; Cloud Control 콘솔**

- 기본 조직 단위: `Security`
- 추가 조직 단위: `Sandbox`
- 공유 Account 구성
  - Log Account
    - Log Account 명: `Log Archive`
    - 이메일: ID+#@Domain
  - Audit Account
    - Audit Account 명: `Audit`
    - 이메일: ID+#@Domain
- Account 액세스 구성: `ID Center를 통한 Account 액세스`
- 탐지 가드레일: 탐지 가드레일 활성 체크

## Cloud Control 관리
-  조직 단위 생성
  - 조직 단위 생성: `Creative Project`

- Account 생성
  - Account명: `CE_Production`
  - 이메일: ID+#@Domain
  - ID Center 사용자 ID: `Jeff.Creative`
  - 사용자 실명: `Jeff Creative`
  - 이메일 ID+#@Domain

## 가드레일 적용
- 예방 가드레일 검토
- 탐지 가드레일 적용: `CE_Production`

## ID Center 사용자 설정 
**&#128906; ID Center 콘솔**

- Account 할당
  - Account: `CE_Production`
  - 사용자: `Jeff.Creative`
  - 권한세트: `SCPAdministratorAccess`

- Account 할당
  - Account: `Audit`
  - 사용자: `Audrey`
  - 사용자 그룹: `SCPReadOnlyAccess`

- Account 할당
  - Account: `Log Archive`
  - 사용자: `Audrey`
  - 권한세트: `SCPReadOnlyAccess`

## 공유 Account 확인

**&#128906; Jeff.Creative Access Portal 로그인**
- CE_Production Account 확인
  
**&#128906; Jeff.Creative Access Portal 로그인**
- Audit Account: Config Inspection 확인
- Log Analytics Account: Object Storage 확인 
