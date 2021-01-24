<#PSScriptInfo
.VERSION 0.1.1
.GUID
    dc844bcd-4c98-4021-9878-6a5ad473ce44
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
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
.DESCRIPTION
    This is a simple helper script to publish scripts to PSGallery
.EXAMPLE
.NOTES
#>
#requires -version 5.1

Param([Parameter(Mandatory=$true)]
      [String] $PSGalleryKey
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

if ($PSScriptRoot)
{
    $scriptPath = (Get-Item $PSScriptRoot).parent.parent.FullName
}
else
{
    $scriptPath = Get-Location
}

$publicRepo = @{
    Name          = 'PSGallery'
    URI           = 'https://www.powershellgallery.com/api/v2'
    publishApiKey = $PSGalleryKey
}

$secureRepo = @{
    Name          = 'N/A' # Name of secure Repo for PSRepository
    URI           = 'N/A' # API URI for secure Repo
    publishApiKey = 'N/A' # Publish API key from secure repo
    repoUser      = 'N/A' # Repo credentials
    repoPass      = 'N/A' # Repo credentials
}

$secureRepoParams = @{
    Name                      = $secureRepo.Name
    SourceLocation            = $secureRepo.URI
    ScriptSourceLocation      = ($secureRepo.URI + '/')
    InstallationPolicy        = 'Trusted'
    PackageManagementProvider = 'NuGet'
    Verbose                   = $true
    PublishApiKey             = $secureRepo.publishApiKey
}

$publicRepoParams = @{
    Name                      = $publicRepo.Name
    SourceLocation            = $publicRepo.URI
    ScriptSourceLocation      = ($publicRepo.URI + '/')
    InstallationPolicy        = 'Trusted'
    PackageManagementProvider = 'NuGet'
    Verbose                   = $true
    PublishApiKey             = $publicRepo.publishApiKey
}

# ==============================================================
# MAIN
# ==============================================================
If ($secureRepo.Name -ne 'N/A')
{
    # This needs to be done each time for some reason... when you register a repo with credentials, the credentials are not reserved session to session
    "Registering PSRepository..."
    $secureRepoParams.Credential = [PSCredential]::New($secureRepo.repoUser, ($secureRepo.repoPass | ConvertTo-SecureString -AsPlainText -Force))

    Unregister-PSRepository -Name $secureRepoParams.Name -WarningAction silentlycontinue -ErrorAction silentlycontinue
    Register-PSRepository @secureRepoParams
}

Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

$currentPath = $PWD
Set-Location $scriptPath

$modules = Get-ChildItem .\modules\ -Directory
ForEach($module in $modules)
{
    $moduleName = $module.basename
    "Processing '$moduleName'..."

    #create paths
    $PublishModulePath = Join-Path $module.FullName \$moduleName
    $UserModulePath = Join-Path $env:USERPROFILE \Documents\WindowsPowerShell\Modules

    $null = Get-Content -Path "$PublishModulePath\$moduleName.psd1" | Where-Object { $_ -match 'ModuleVersion =(.*)' }
    $thisVersion = Invoke-Expression -Command $matches[1]

    $null = Get-Content -Path "$PublishModulePath\$moduleName.psd1" | Where-Object { $_ -match 'Tags =(.*)' }
    $Tags = Invoke-Expression -Command $matches[1]
    If ($tags -contains 'Private')
    {
        $moduleParams = @{
            Name            = $moduleName
            Repository      = $secureRepoParams.Name
            Credential      = $secureRepoParams.Credential
            NuGetApiKey     = $secureRepoParams.PublishApiKey
        }
    }
    elseIf ($tags -contains 'Public')
    {
        $moduleParams = @{
            Name            = $moduleName
            Repository      = $publicRepoParams.Name
            NuGetApiKey     = $publicRepoParams.PublishApiKey
        }
    }
    Else
    {
        " No public or private flag found for $moduleName... moving to next module"
        Continue
    }

    $pubModule = Find-Module -Name $moduleParams.Name -Repository $moduleParams.Repository -ErrorAction Ignore -WarningAction Ignore
    if ($pubmodule)
    {
        $pubVersion = $pubModule | Select-Object -Expand version
    }
    else
    {
        $pubVersion = '0.0.0'
    }
    "  Published version of '$moduleName': $($pubVersion)"
    "  This version of '$moduleName':      $($thisVersion)"

    if ($thisVersion -gt $pubVersion)
    {
        "  Published version is older than this version. Publishing '$moduleName' to repo $($moduleParams.Repository)..."
        copy-item $PublishModulePath $UserModulePath -force -Recurse
        Publish-Module @moduleParams -RequiredVersion $thisVersion
    }
    else
    {
        "  Published version is not older than this version. module '$moduleName' will not be published."
    }
}

Set-Location $scriptPath
$scripts = Get-ChildItem .\scripts\ -File -Recurse -Filter "*.ps1"
ForEach($script in $scripts)
{
    $scriptName = $script.BaseName

    "Processing $scriptName..."

    $thisVersion = Test-ScriptFileInfo -Path $script.FullName | Select-Object -Expand version
    $Tags = Test-ScriptFileInfo -Path $script.FullName | Select-Object -Expand Tags

    If ($tags -contains 'Private')
    {
        $scriptParams = @{
            LiteralPath     = $script.FullName
            Repository      = $secureRepoParams.Name
            Credential      = $secureRepoParams.Credential
            NuGetApiKey     = $secureRepo.publishApiKey 
        }
    }
    elseif ($tags -contains 'Public')
    {
        $scriptParams = @{
            LiteralPath     = $script.FullName
            Repository      = $publicRepoParams.Name
            NuGetApiKey     = $publicRepo.publishApiKey 
        }
    }
    Else
    {
        " No public or private flag found for $scriptName... moving to next script"
        Continue
    }

    $pubscript = Find-script -Name $scriptName -Repository $scriptParams.Repository -ErrorAction Ignore -WarningAction Ignore
    if ($pubscript)
    {
        $pubVersion = $pubscript | Select-Object -Expand version
    }
    else
    {
        $pubVersion = '0.0.0'
    }
    "  Published version of '$scriptName': $($pubVersion)"
    "  This version of '$scriptName':      $($thisVersion)"

    if ($thisVersion -gt $pubVersion)
    {
        "  Published version is older than this version. Publishing '$scriptName' to repo $($scriptParams.Repository)..."
        Publish-script @scriptParams
    }
    else
    {
        "  Published version is not older than this version. script '$scriptName' will not be published."
    }
}
Set-location $currentPath
