Function New-ScriptTemplate
{
    PARAM([Parameter(Mandatory=$true)]
          [string]$processName
        , [string]$description
        , [Parameter(Mandatory=$true,position=0)] 
          [AllowNull()] 
          [AllowEmptyCollection()] 
          [Tags[]] $tags
        , [string]$orgName
        , [string]$codePath)

    if ($codePath)
    {
        $newPath = Join-Path $codePath -ChildPath "scripts\$ProcessName"
    }
    else 
    {
        $newPath = Join-Path (Get-item $PSScriptRoot).parent.parent.parent.Fullname -ChildPath $ProcessName
    }

    Write-Verbose "Creating the folder $newPath..."

    If (Test-path -Path $newpath)
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

    Write-Verbose "Script created! Check the following path: $newPath"
}