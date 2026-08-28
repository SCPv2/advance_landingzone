# Samsung Cloud Platform v2 Open API - Virtual Server 상태 조회
#
# 사용법
#   .\Invoke-ScpApi.ps1                                    # 전체 서버 목록
#   .\Invoke-ScpApi.ps1 -ServerId "44701793-..."           # 단건 상세
#   .\Invoke-ScpApi.ps1 -AccessKey "..." -SecretKey "..."  # 임시키로 조회
#
# 인증키를 생략하면 %USERPROFILE%\.scpconf\credentials.json 에서 읽습니다.

param(
    [string]$Url,
    [string]$Method = 'GET',
    [string]$ServerId,
    [string]$Region = 'kr-west1',
    [string]$AccessKey,
    [string]$SecretKey,
    [string]$ClientType = 'Openapi',
    [hashtable]$ExtraHeaders,
    [switch]$SecretVault,
    [switch]$ShowSignature
)

function Invoke-ScpApi {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Method = 'GET',
        [string]$Body,
        [string]$AccessKey,
        [string]$SecretKey,
        [string]$ClientType = 'Openapi',
        [hashtable]$ExtraHeaders,
        [switch]$SecretVault,
        [switch]$ShowSignature
    )

    if (-not $AccessKey -or -not $SecretKey) {
        $credPath = Join-Path $env:USERPROFILE '.scpconf\credentials.json'
        if (-not (Test-Path $credPath)) {
            throw "credentials.json 을 찾을 수 없습니다: $credPath"
        }
        $cred = Get-Content $credPath -Raw | ConvertFrom-Json
        if (-not $AccessKey) { $AccessKey = $cred.'access-key' }
        if (-not $SecretKey) { $SecretKey = $cred.'secret-key' }
    }

    $clientType = $ClientType
    $timestamp  = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

    # 서명 대상 문자열은 실제 전송되는 URL 과 정확히 일치해야 합니다.
    $message = "$Method$Url$timestamp$AccessKey$clientType"

    $hmac = [System.Security.Cryptography.HMACSHA256]::new(
        [System.Text.Encoding]::UTF8.GetBytes($SecretKey))
    $signature = [Convert]::ToBase64String(
        $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($message)))

    if ($ShowSignature) {
        Write-Host "message   : $message"      -ForegroundColor DarkGray
        Write-Host "timestamp : $timestamp"    -ForegroundColor DarkGray
        Write-Host "signature : $signature"    -ForegroundColor DarkGray
    }

    # Secret Vault 계열 API 는 Sv* 헤더를, 그 외 서비스는 Scp-* 헤더를 사용합니다.
    if ($SecretVault) {
        $headers = @{
            'Svaccesskey'     = $AccessKey
            'SvSignature'     = $signature
            'Svtimestamp'     = $timestamp
            'Svclienttype'    = $clientType
            'Accept-Language' = 'ko-KR'
        }
    }
    else {
        $headers = @{
            'Scp-Accesskey'   = $AccessKey
            'Scp-Signature'   = $signature
            'Scp-Timestamp'   = $timestamp
            'Scp-ClientType'  = $clientType
            'Accept-Language' = 'ko-KR'
        }
    }

    # 임시키 등에서 추가 헤더(세션 토큰 등)가 필요한 경우
    if ($ExtraHeaders) {
        foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }
        if ($ShowSignature) {
            Write-Host "extra     : $($ExtraHeaders.Keys -join ', ')" -ForegroundColor DarkGray
        }
    }

    $params = @{
        Method      = $Method
        Uri         = $Url
        Headers     = $headers
        ContentType = 'application/json'
    }
    if ($Body) { $params['Body'] = $Body }

    Invoke-RestMethod @params
}

########################################################
# Virtual Server 상태 조회
########################################################

if ($Url) {
    # 임의 URL 직접 호출 (임시키 발급 등)
    $targetUrl = $Url
}
else {
    $baseUrl   = "https://virtualserver.$Region.e.samsungsdscloud.com/v1/servers"
    $targetUrl = if ($ServerId) { "$baseUrl/$ServerId" } else { $baseUrl }
}

Write-Host "$Method $targetUrl" -ForegroundColor Cyan

try {
    $result = Invoke-ScpApi -Url $targetUrl -Method $Method -AccessKey $AccessKey -SecretKey $SecretKey `
        -ClientType $ClientType -ExtraHeaders $ExtraHeaders `
        -SecretVault:$SecretVault -ShowSignature:$ShowSignature
}
catch {
    Write-Host "요청 실패: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
    return
}

if ($Url) {
    # 임의 URL 호출 결과는 원본 그대로
    $result | Format-List
}
elseif ($ServerId) {
    # 단건 상세
    $result | Format-List
}
else {
    # 목록 - 상태 확인에 필요한 항목만 표로 출력
    $servers = if ($result.servers) { $result.servers } else { $result }

    $servers | Select-Object `
        name,
        id,
        state,
        zone,
        @{ n = 'ip'; e = { ($_.addresses | ForEach-Object { $_.ip_address }) -join ', ' } },
        @{ n = 'type'; e = { if ($_.server_type -is [string]) { $_.server_type } else { $_.server_type.name } } } |
        Format-Table -AutoSize
}
