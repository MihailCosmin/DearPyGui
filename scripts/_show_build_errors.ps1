param([string]$LogFile = "build_wheel.log")

$skipPattern = 'CalledProcessError|ErrorRecovery|error_recovery|mvErrorCode|ConfigErrorRecovery'

Select-String -Path $LogFile -Pattern 'error' -CaseSensitive:$false `
    | Where-Object { $_.Line -notmatch $skipPattern } `
    | Select-Object -First 25 `
    | ForEach-Object { "L$($_.LineNumber): $($_.Line.Trim())" }
