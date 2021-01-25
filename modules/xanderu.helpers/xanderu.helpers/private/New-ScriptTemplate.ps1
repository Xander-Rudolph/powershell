Function New-ScriptTemplate
{
    PARAM([Parameter(Mandatory=$true)]
          [string]$processName
        , [string]$description
        , [Parameter(Mandatory=$true)] 
          [AllowNull()] 
          [AllowEmptyCollection()] 
          [Tags[]] $tags
        , [string]$orgName
        , [Parameter(Mandatory=$true)]
          [string]$codePath)

    $newPath = Join-Path $codePath "\scripts\$processName"
    If (Test-path -Path $newPath)
    {
        Write-Error "Module $processName already exists" -ErrorAction Stop
    }
    Else
    {
        $folders = @('schedules','tests','webhooks')
        $folders | ForEach-Object {New-Item -Path (Join-Path $newPath -ChildPath $_) -ItemType Directory -Force} | Out-Null
    }

    $TemplateScriptText = @"
<#PSScriptInfo
.VERSION 0.0.0
.GUID
    $((New-Guid).GUID)
.AUTHOR
    $($ENV:Username.ToUpper())
.COMPANYNAME
    $orgName
.COPYRIGHT
    (c) $(get-date -Format yyyy) $orgName. All rights reserved.
.TAGS
    $($Tags -join ",")
.LICENSEURI
.PROJECTURI
.ICONURI
.REQUIREDMODULES
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
.DESCRIPTION
    $description
.EXAMPLE
.NOTES
#>
#requires -version

# ==============================================================
# FUNCTIONS
# ==============================================================

# ==============================================================
# GLOBALS
# ==============================================================
`$ErrorActionPreference = 'Stop'
`$VerbosePreference = 'Continue'

# ==============================================================
# INIT
# ==============================================================
`$error.Clear()
`$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()


# ==============================================================
# MAIN
# ==============================================================
"@

    $TemplateScriptText | Out-File -FilePath (Join-Path $newPath -ChildPath "$processName.ps1") -Force | Out-Null
}