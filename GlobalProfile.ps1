Function Set-ModulePath
{
    $env:PSModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules;$($env:ProgramFiles)\WindowsPowerShell\Modules;$(${env:ProgramFiles(x86)})\WindowsPowerShell\Modules;$env:windir\system32\WindowsPowerShell\v1.0\Modules;$($env:USERPROFILE)\.vscode\extensions\ms-vscode.powershell-2020.6.0\modules"
}

Function Set-AllProfileScripts
{
    Switch ($profile)
    {
        $profile.AllUsersAllHosts       {New-Item -ItemType SymbolicLink -Path $profile.AllUsersAllHosts -Target $MyInvocation.PSCommandPath -Force}
        $profile.AllUsersCurrentHost    {New-Item -ItemType SymbolicLink -Path $profile.AllUsersCurrentHost -Target $MyInvocation.PSCommandPath -Force}
        $profile.CurrentUserAllHosts    {New-Item -ItemType SymbolicLink -Path $profile.CurrentUserAllHosts -Target $MyInvocation.PSCommandPath -Force}
        $profile.CurrentUserCurrentHost {New-Item -ItemType SymbolicLink -Path $profile.CurrentUserCurrentHost -Target $MyInvocation.PSCommandPath -Force}
    }
}

Function Install-XanderScripts
{
    Install-Module -Name xanderu.helpers -Force
}

#Set-ModulePath
Set-AllProfileScripts
Install-XanderScripts
