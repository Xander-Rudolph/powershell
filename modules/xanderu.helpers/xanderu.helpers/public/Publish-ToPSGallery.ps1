Function Publish-ToPSGallery
{
    <#
    .SYNOPSIS
    .DESCRIPTION
        This is a simple helper script to publish scripts to PSGallery
    .EXAMPLE
    .NOTES
    #>
    
    Param([Parameter(Mandatory=$true)]
          [String] 
          $PSGalleryKey  # Name of secure Repo for PSRepository
        , [String] $secureRepoName = 'N/A' # Name for secure Repo in powershell
        , [String] $secureRepopublishApiKey = 'N/A' # API URI for secure Repo
        , [String] $secureRepopublishApiURL = 'N/A' # API URI for secure Repo
        , [String] $secureRepoUser = 'N/A' # Repo credentials
        , [String] $secureRepoPass = 'N/A' # Repo credentials
        , [String] $codePath
        )

    # ==============================================================
    # INIT
    # ==============================================================
    if ($codePath -eq "" -or -not $codePath)
	{
        $codePath = Get-Location
	}
    If (-not (Test-Path $codePath)){Write-Error "Unable to find the local path for processing scripting";continue}

    $secureRepoParams = @{
        Name                      = $secureRepoName
        SourceLocation            = $secureRepopublishApiURL
        ScriptSourceLocation      = "$secureRepopublishApiURL/"
        PublishLocation           = $secureRepopublishApiURL
        Credential                = [PSCredential]::New($secureRepoUser, ($secureRepoPass | ConvertTo-SecureString -AsPlainText -Force))
        InstallationPolicy        = 'Trusted'
        PackageManagementProvider = 'NuGet'
        Verbose                   = $true
    }

    $publicRepoParams = @{
        Name                      = 'PSGallery'
        SourceLocation            = 'https://www.powershellgallery.com/api/v2'
        ScriptSourceLocation      = 'https://www.powershellgallery.com/api/v2/'
        InstallationPolicy        = 'Trusted'
        PackageManagementProvider = 'NuGet'
        Verbose                   = $true
        PublishApiKey             = $PSGalleryKey
    }

    # ==============================================================
    # MAIN
    # ==============================================================
    If ($secureRepoName -ne 'N/A')
    {
        # This needs to be done each time for some reason... when you register a repo with credentials, the credentials are not reserved session to session
        "Registering PSRepository..."

        Unregister-PSRepository -Name $secureRepoParams.Name -WarningAction silentlycontinue -ErrorAction silentlycontinue
        Register-PSRepository @secureRepoParams
        
        # force the nuget credential because publish module doesn't honor the creds passthru for publishing to AzDo (PowerShellGet v2.2.5)
        & nuget sources update -Name $secureRepoParams.Name -UserName $secureRepoParams.Credential.UserName -Password $secureRepoParams.Credential.GetNetworkCredential().Password

        # This needs to be added after registering the repo to recycle the splat params
        $secureRepoParams.PublishApiKey = $secureRepopublishApiKey
    }

    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

    $currentPath = $PWD
    "Switching to  '$codePath' from $currentPath..."
    Set-Location $codePath

    $modules = Get-ChildItem ./modules/ -Directory
    ForEach($module in $modules)
    {
        $moduleName = $module.basename
        "Processing '$moduleName'..."

        #create paths
        $PublishModulePath = Join-Path $module.FullName /$moduleName
        $UserModulePath = ($env:PSModulePath -split ";")[0]

        $null = Get-Content -Path "$PublishModulePath/$moduleName.psd1" | Where-Object { $_ -match 'ModuleVersion =(.*)' }
        $thisVersion = Invoke-Expression -Command $matches[1]

        $null = Get-Content -Path "$PublishModulePath/$moduleName.psd1" | Where-Object { $_ -match 'Tags =(.*)' }
        $Tags = Invoke-Expression -Command $matches[1]
        If ($tags -contains 'Private')
        {
            $moduleParams = @{
                Name            = $moduleName
                Repository      = $secureRepoParams.Name
                Credential      = $secureRepoParams.Credential
                NuGetApiKey     = $secureRepopublishApiKey
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

        if ([version]$thisVersion -gt [version]$pubVersion)
        {
            "  Published version is older than this version. Publishing '$moduleName' to repo $($moduleParams.Repository)..."
            "copy from $PublishModulePath to $UserModulePath..."
            copy-item $PublishModulePath $UserModulePath -force -Recurse
            Publish-Module @moduleParams -RequiredVersion $thisVersion
            Remove-Item (Join-Path $UserModulePath /$moduleName) -Force -Recurse
        }
        else
        {
            "  Published version is not older than this version. module '$moduleName' will not be published."
        }
    }

    $scripts = Get-ChildItem ./scripts -File -Recurse -Filter "*.ps1"
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
                NuGetApiKey     = $secureRepopublishApiKey 
            }
        }
        elseif ($tags -contains 'Public')
        {
            $scriptParams = @{
                LiteralPath     = $script.FullName
                Repository      = $publicRepoParams.Name
                NuGetApiKey     = $PSGalleryKey
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
}