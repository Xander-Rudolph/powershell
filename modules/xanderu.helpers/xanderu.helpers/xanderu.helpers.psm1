#Requires -Version 3.0
[CmdletBinding()]
Param()

#Set-StrictMode -Version Latest

####################################################################################
## Dynamic module loader - can be used without changes for any PowerShell module
## All function files must be in 'public' or 'private' child directories.
####################################################################################

Write-Verbose "Loading production scripts from public and private module directories..."

if ($PSScriptRoot)
{
    $scriptPath = $PSScriptRoot
}
else
{
    $scriptPath = Get-Location
}

if(!("Tags" -as [Type])){
    Add-Type -TypeDefinition @'
       public enum Tags{
           Public
          ,Private
          ,Azure
          ,Template
          ,Alpha
          ,Beta
       }
'@
}
# Dot-source each private and public script file to load it (must not have '.Test*' in the name)
$privatePath = (Join-Path -Path $scriptPath -ChildPath 'private')
$publicPath  = (Join-Path -Path $scriptPath -ChildPath 'public')

if (Test-Path -Path $privatePath -PathType Container)
{
	$privateScriptFiles = (Get-ChildItem -Path $privatePath -Filter *.ps1 -Recurse) |
		Where-Object { $_.name -NotLike '*.Test*.ps1' }

	$privateScriptFiles | ForEach-Object {
			Write-Verbose ('Loading private function {0}' -f $_.basename)
			. $_.FullName
		}
}

if (Test-Path -Path $publicPath -PathType Container)
{
	$publicScriptFiles = (Get-ChildItem -Path $publicPath -Filter *.ps1 -Recurse) |
		Where-Object { $_.name -NotLike '*.Test*.ps1' }

	$publicScriptFiles | ForEach-Object {
			Write-Verbose ('Loading public function {0}' -f $_.basename)
			. $_.FullName
		}
}
else
{
	Write-Error "Damaged module: 'public' directory is missing from the script install directory '$scriptPath'"
}

# Export only public module functions
foreach ($publicScriptFile in $publicScriptFiles) { Export-ModuleMember -Function $publicScriptFile.basename }