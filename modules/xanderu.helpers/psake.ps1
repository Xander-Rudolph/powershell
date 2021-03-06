<#
.DESCRIPTION
psake 'make' file to pull all module requirements together and run all required tests.
#>
Properties {
	$projectRoot = $PSScriptRoot
	"Project root: $projectRoot"

    $moduleRoot = Split-Path (Resolve-Path "$projectRoot\*\*.psm1")
	$moduleName = Split-Path $moduleRoot -Leaf

	$timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
	$PSVersion = $PSVersionTable.PSVersion.Major
	$testFile = "TestResults_PS$PSVersion`_$timeStamp.xml"
	$separator = '----------------------------------------------------------------------'
	$verbose = @{Verbose = $True}
}

Task Default -Depends HelpTests

Task Init {
	$separator
	Set-Location $projectRoot
	"`n"
}

Task ProjectTests -Depends Init {
	$separator
	"STATUS: Testing with PowerShell $PSVersion`n"

	$testResults = Invoke-Pester -Path "$projectRoot\tests\*project*" -PassThru -Tag Build

	if ($testResults.FailedCount -gt 0) {
		$testResults | Format-List
		Write-Error "Failed '$($testResults.FailedCount)' tests, build failed"
	}
	"`n"
}

Task UnitTests -Depends ProjectTests {
	$separator

	$testResults = Invoke-Pester -Path "$projectRoot\tests\*unit*" -PassThru -Tag Build

	if ($testResults.FailedCount -gt 0) {
		$testResults | Format-List
		Write-Error "Failed '$($testResults.FailedCount)' tests, build failed"
	}
	"`n"
}

Task HelpTests -Depends UnitTests {
	$separator

	$testResults = Invoke-Pester -Path "$projectRoot\tests\*help*" -PassThru -Tag Build

	if ($testResults.FailedCount -gt 0) {
		$testResults | Format-List
		Write-Error "Failed '$($testResults.FailedCount)' tests, build failed"
	}
	"`n"
}
