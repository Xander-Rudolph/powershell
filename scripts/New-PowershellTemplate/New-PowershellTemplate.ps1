<#PSScriptInfo
.VERSION 0.1.0
.GUID
    63db8dbf-ee95-4492-abf3-a9dd6d8672af
.AUTHOR
    alex.rudolph.1987@gmail.com
.COMPANYNAME
.COPYRIGHT
    (c) 2021 Alex Rudolph. All rights reserved.
.TAGS
    Public
.LICENSEURI
.PROJECTURI
.ICONURI
.REQUIREDMODULES
.EXTERNALMODULEDEPENDENCIES
    xanderu.helpers
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
.DESCRIPTION
    This script is designed to create quick frames for powershell scripts. Feel free to leave me feedback @ http://rudolphhome.privatedns.org/.
.EXAMPLE
.NOTES
#>
#requires -version 5.1
#requires -modules xanderu.helpers

param (
    [Parameter()]
    [string]
    $type,
    [string]
    $processName,
    [string]
    $description
)
# ==============================================================
# FUNCTIONS
# ==============================================================

# ==============================================================
# GLOBALS
# ==============================================================
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# ==============================================================
# INIT
# ==============================================================
$error.Clear()
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# ==============================================================
# MAIN
# ==============================================================
if ($PSScriptRoot)
{
    $scriptPath = $PSScriptRoot
}
else
{
    $scriptPath = Get-Location
}

If (-not (Test-Path $scriptPath)){Write-Error "Unable to find the local path for processing scripting"}

If (-not $type){$type = Read-Host -Prompt "Are you creating a Script or a Module?"}
If ($type.ToUpper() -ne 'MODULE' -and $type.ToUpper() -ne 'SCRIPT')
{
    Write-Error "$type is not valid selection";
    Write-Host "Press any key to continue...";
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    Exit
}

If (-not $processName){$processName = Read-Host -Prompt "Enter a name for the new $type"}
If (-not $description){$description = Read-Host -Prompt "Enter a description for the new $type`, $processName"}

If ($type.ToUpper() -eq 'MODULE')
{
    New-ModuleTemplate -processName $processName -description $description -tags $tags -codepath (Get-item $scriptPath).parent.parent.Fullname
}
ElseIf ($type.ToUpper() -eq 'SCRIPT')
{
    New-ScriptTemplate -processName $processName -description $description -tags $tags -codepath (Get-item $scriptPath).parent.parent.Fullname
}

Write-Host "Process Complete! `nPress any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
