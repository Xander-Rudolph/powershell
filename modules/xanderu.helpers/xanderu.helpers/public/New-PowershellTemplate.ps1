Function New-PowershellTemplate
{
<#
    .SYNOPSIS
    .DESCRIPTION
        This script is designed to create quick frames for powershell scripts. Feel free to leave me feedback @ http://rudolphhome.privatedns.org/.
    .EXAMPLE
    .NOTES
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Script','Module')]
        [string]
        $type,
        [Parameter(Mandatory)]
        [string]
        $processName,
        [Parameter(Mandatory)]
        [string]
        $description,
        [string]
        $codePath
    )

    # ==============================================================
    # MAIN
    # ==============================================================
    if ($codePath -eq "" -or -not $codePath)
	{
        $codePath = $MyInvocation.PSScriptRoot
        try {
            test-path $codePath
        }
        catch {
            Write-Warning -Message "Unable to find codepath or myinvocation.psscriptroot variables. Defaulting to current path."
            $codePath = Get-Location
        }
	}
    If (-not (Test-Path $codePath)){Write-Error "Unable to find the local path for processing scripting";continue}

    If ($type.ToUpper() -eq 'MODULE')
    {
        New-ModuleTemplate -processName $processName -description $description -tags $tags -codepath $codePath
    }
    ElseIf ($type.ToUpper() -eq 'SCRIPT')
    {
        New-ScriptTemplate -processName $processName -description $description -tags $tags -codepath $codePath
    }

    Write-Host "Process Complete! `n$type created at $codepath.`nPress any key to continue...";
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}