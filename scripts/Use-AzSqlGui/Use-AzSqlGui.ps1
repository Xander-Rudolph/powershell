<#PSScriptInfo
.VERSION 0.0.3
.GUID
    4c3a3f4b-1351-488d-88f4-fcda52e93278
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
    This script is designed to use powershell to call azure using your azure credentials and SSO. Some prerequisite configurations are needed.
.EXAMPLE
.NOTES
    To allow pulling credentials from KV make sure that the context for the KV is set prior to executing the script as well as update the Get-Auth call in in the "Globals" section of the script.
#>
#requires -version 5.1

# ==============================================================
# FUNCTIONS
# ==============================================================
#this is here because using .Requiredmodules can be a little hinky
If(-not $installedModules){Write-Host "Getting installed modules"; $installedModules = Get-InstalledModule}

Write-Host "Validating existing modules and installing missing modules"
If(-not ($installedModules | Where-Object {$_.Name -eq "Az"})){Install-Module Az -force}

Write-Host "Importing required modules"
Import-Module Az

Function Get-AllSqlServers
{
    Write-Verbose "Loading SQL Servers"
    $Global:SQLServerList = @()
    $Contexts = Get-AzContext -ListAvailable
    ForEach($Context in $Contexts)
    {
        Write-Verbose "Checking subscription $($Context.Name)"
        $Context | Select-AzContext | out-null
        $temp = Get-AzSqlServer | Select-Object ServerName, ResourceGroupName 
        $temp | Add-Member -MemberType NoteProperty "Subscription" -Value $Context.Name
        $Global:SQLServerList += $temp
        Remove-Variable temp
    }
    $Global:selServer.Items.AddRange(($Global:SQLServerList.ServerName | Sort-Object))
}

Function Get-AllSqlDbs
{
    $Global:selDatabase.Clear()

    $subscription = $Global:SQLServerList | Where-Object {$_.ServerName -eq $Global:SelectedServer}
    Write-Verbose "Selecting subscription $($subscription.subscription)"
    #Get-AzSubscription -SubscriptionName $subscription | Select-AzSubscription
    Get-AzContext -name $subscription.Subscription | Set-AzContext

    $ResourceGroupName = ($Global:SQLServerList | Where-Object {$_.ServerName -eq $Global:SelectedServer.ToString()}).ResourceGroupName
    Write-Verbose "Checking $ResourceGroupName"

    $Global:SQLDBList = (Get-AzSqlDatabase -ServerName $Global:SelectedServer -ResourceGroupName $ResourceGroupName).DatabaseName
 
    $Global:DBColumn = $Global:selDatabase.Columns.Add('Database',205)
    $Global:selDatabase.Items.AddRange(($Global:SQLDBList))
}

Function User-Selector
{
    $userList = Get-AzADUser | Out-GridView -PassThru -Title "User Selection"
    Return $UserList
}

Function AAD-Selector
{
    $GroupList = Get-AzADGroup | Out-GridView -PassThru -Title "Group Selection"
    Return $GroupList
}

Function Add-AzSqlPermission
{
    Param($users)
    
    If($users.count -gt 0)
    {
        If($users.UserPrincipalName){$Looper = $users.UserPrincipalName}
        ElseIf($users.DisplayName){$Looper = $users.DisplayName}
        ForEach($user in $Looper)
        {
            $UserQuery = "IF not exists(select name from sys.database_principals where name = '$user')`r`n CREATE USER [$user] FROM EXTERNAL PROVIDER;"
            $splatParams = @{
                ServerInstance = "$($Global:SelectedServer).database.windows.net"
                Database = 'master'
                Query = $UserQuery
                Credential = $Global:cred
                UseADAuth = $true
            }
            $QueryObject = Invoke-AzSqlcmd @splatParams

            $splatParams.Query +="`r`nALTER ROLE db_datareader ADD MEMBER [$user];"
            $splatParams.Database = $Global:SelectedDatabase
            $QueryObject = Invoke-AzSqlcmd @splatParams
        }
        Set-UserList
    }
    Else
    {
        write-Verbose "nothing select... moving on..."
    }
}

Function Remove-AzSqlPermission
{
    $splatParams = @{
        ServerInstance = "$($Global:SelectedServer).database.windows.net"
        Database = $Global:SelectedDatabase
        Query = "IF exists(select name from sys.database_principals where name = '$global:SelectedUser')`r`n DROP USER [$global:SelectedUser];"
        Credential = $Global:cred
        UseADAuth = $true
    }

    If($Global:selUser.SelectedItems.count -gt 1)
    {
        ForEach($item in $Global:selUser.SelectedItems)
        {
            $splatParams.Query = "`r`nDROP USER [$($item.Text)];"
            $QueryObject = Invoke-AzSqlcmd @splatParams
        }
    }
    Else
    {
        $QueryObject = Invoke-AzSqlcmd @splatParams
    }

    Set-UserList
}

Function Get-AzSqlPermission
{
    $UserQuery = "Select * from sys.database_principals where type not in ('A', 'G', 'R') and type_desc in ('EXTERNAL_USER','EXTERNAL_GROUP') and name not in ('dbo','guest','sys','INFORMATION_SCHEMA') order by name;"
    $splatParams = @{
        ServerInstance = "$($Global:SelectedServer).database.windows.net"
        Database = $Global:SelectedDatabase
        Query = $UserQuery
        Credential = $Global:cred
        UseADAuth = $true
    }

    $QueryObject = Invoke-AzSqlcmd @splatParams
    $PermissionsObjs += $QueryObject.dataset.tables[0]
    
    return $PermissionsObjs
}

Function Set-UserList
{
    $Global:selUser.Clear()

    $users = Get-AzSqlPermission

    if(-not $users)
    {
        [System.Windows.MessageBox]::Show('No assigned permissions found')
    }

    $Global:selUser.Columns.Add('UserName',400)
    $Global:selUser.Items.AddRange(($users.name))
}

Function Get-KeyVaultSQLCredentials
{
    <#
    .EXAMPLE
        Get-KeyVaultSQLCredentials -keyVaultName ExampleKeyVault -sqlKeyName sqlUserName -passKeyName sqlPassword
    #>	

	Param
	(
		[Parameter(Mandatory=$true)]
        $keyVaultName,
		[Parameter(Mandatory=$true)]
		$sqlKeyName,
		[Parameter(Mandatory=$true)]
		$passKeyName
	)

	[string]$SQLuser = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $sqlKeyName).SecretValueText
	[string]$SQLpass = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $passKeyName).SecretValueText

    #generate random 
    #$Key = Get-RandomExtended -length 20 -type "Hex"

	#build PS Credential
	$secpasswd = ConvertTo-SecureString $SQLpass -AsPlainText -Force
	$SqlCred = New-Object System.Management.Automation.PSCredential ($SQLuser, $secpasswd)
	
    $return = @{cred = $sqlCred; String = $Key; UN = $SQLuser; PW = $SQLpass}

	return $return
}


Function Invoke-AzSqlRunAsUser
{
    $sUsername = $Global:SelectedUser

    [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

    $title = "Running as $sUsername"
    $msg   = 'Enter your Query:'

    $text = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

    If (-not $text){Return}

    $UserQuery = "EXECUTE AS USER = '$sUsername'; $text;"
    $splatParams = @{
        ServerInstance = "$($Global:SelectedServer).database.windows.net"
        Database = $Global:SelectedDatabase
        Query = $UserQuery
        Credential = $Global:cred
        UseADAuth = $true
    }

    $QueryObject = Invoke-AzSqlcmd @splatParams
    $PermissionsObjs += $QueryObject.dataset.tables[0]
    
    $PermissionsObjs | Out-GridView -Title "Results for $sUsername"
}



Function Invoke-AzSqlGetUserPermissions
{
    $sUsername = $Global:SelectedUser
    $UserQuery = "EXECUTE AS USER = '$sUsername'; SELECT * FROM fn_my_permissions (NULL, 'DATABASE');"
    $splatParams = @{
        ServerInstance = "$($Global:SelectedServer).database.windows.net"
        Database = $Global:SelectedDatabase
        Query = $UserQuery
        Credential = $Global:cred
        UseADAuth = $true
    }

    $QueryObject = Invoke-AzSqlcmd @splatParams
    $PermissionsObjs += $QueryObject.dataset.tables[0]
    
    $PermissionsObjs | Out-GridView -Title "Permissions for $sUsername"
}

Function Invoke-AzSqlCmd
{
    Param (
           $Query,
           $Credential,
           $SecureKey,
           $Database,
           $ServerInstance,
           $Port = 1433,
           $connectionTimeout = 30,
           $CommandTimeout = 120,
           [switch]$UseADAuth,
           [switch]$persistConnection,
           $cxn,
           $forceRetry = $true,
           $ErrorAction = "Continue"
          )

    #modded from invoke-sqlcmd because of AAD login
    #reference https://social.msdn.microsoft.com/Forums/vstudio/en-US/15686e28-293b-4150-805f-1c25d2432d9a/invokesqlcmd-fails-with-quotcannot-open-server-quotdomaincomquot-requested-by-the-login?forum=ssdsgetstarted
    $Error.Clear()

    If($Credential.GetType().Name -eq 'PSCredential')
    {
        $Username = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
    }

    If(-not $Password){$Password=$global:PlainPWD}

    If(-not $Username -or -not $Password)
    {
        Write-Error "Unable to return username from credential"
        Exit
    }

    If(-not $cxn)
    {
    
        #MultipleActiveResultSets=true is because of the error "There is already an open DataReader associated with this Command which must be closed first"
        #$cxnString = "Server=tcp:$ServerInstance,$Port;Database=$Database;UID='$UserName';PWD='$Password';Trusted_Connection=False;Encrypt=True;Connection Timeout=$connectionTimeout;MultipleActiveResultSets=true"
        #https://stackoverflow.com/questions/6062192/there-is-already-an-open-datareader-associated-with-this-command-which-must-be-c
        
        $cxnString = "Server=tcp:$ServerInstance,$Port;Database=$Database;UID='$UserName';PWD='$Password';Trusted_Connection=False;Encrypt=True;Connection Timeout=$connectionTimeout;"
        Write-Verbose "Connection string: `n $cxnString"

        If($UseADAuth)
        {
            $cxnString += "Authentication=Active Directory Password;"
        }

        $cxn = New-Object System.Data.SqlClient.SqlConnection($cxnString)

        Try
        {
            $cxn.Open()
        }
        Catch
        {
            $Err = $_
            switch ($ErrorAction)
            {
                {'SilentlyContinue','Ignore' -contains $_} {}
                'Stop' {     Throw $Err }
                'Continue' { Throw $Err; Continue}
                Default {    Throw $Err; Continue}
            }
        }
    }

    Write-Verbose "SQL Query: `n$Query"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $cxn)
    $cmd.CommandTimeout = $CommandTimeout
    Try
    {
        $cmd.ExecuteReader()
    }
    Catch
    {
        $Err = $_
        switch ($ErrorAction)
        {
            {'SilentlyContinue','Ignore' -contains $_} {}
            'Stop' {     Throw $Err }
            'Continue' { Throw $Err; Continue}
            Default {    Throw $Err; Continue}
        }
    }

    $ds = New-Object system.Data.DataSet
    $da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd)

    #this intermittently fails... not sure why. Put a microsleep in there for the time being
    Start-Sleep -Milliseconds 150

    Try
    {
        [void]$da.fill($ds)
    }
    Catch [System.Data.SqlClient.SqlException] # For SQL exception
    {
        $Err = $_

        Write-Verbose "Capture SQL Error"

        if ($PSBoundParameters.Verbose) {Write-Verbose "SQL Error:  $Err"} #Shiyang, add the verbose output of exception

        switch ($ErrorAction)
        {
            {'SilentlyContinue','Ignore' -contains $_} {}
            'Stop' {     Throw $Err }
            'Continue' { Throw $Err}
            Default {    Throw $Err}
        }
    }
    Catch # For other exception
    {
        Write-Verbose "Capture Other Error"  

        $Err = $_
        Write-Verbose $Err.Exception
        If($Err.Exception -like "*There is already an open DataReader associated with this Command which must be closed first*")
        {   
            If($forceRetry){$retry = 0}Else{$retry = 5}
            Do
            {
                Start-Sleep -Seconds 1
                $Error.Clear()
                Try
                {
                    $PassthruSplat = @{
	                    Query = $Query
	                    Credential = $Credential
	                    SecureKey = $SecureKey
	                    Database = $Database
	                    ServerInstance = $ServerInstance
	                    Port = $Port
	                    connectionTimeout = $connectionTimeout
	                    CommandTimeout = $CommandTimeout
	                    UseADAuth = $UseADAuth
	                    persistConnection = $persistConnection
	                    cxn = $cxn
                        forceRetry = $false
                    }
                    $results = Invoke-AzSqlCmd @PassthruSplat
                    Return $results
                }
                Catch 
                {

                }
                $retry += 1
            }
            Until ($retry -eq 5 -or -not $Error)
            
            If(-not $error)
            {
                Continue
            }
            Else
            {
                Write-Verbose 'A timeout occoured due to a previously open connection. Please try again.'
            }
        }

        if ($PSBoundParameters.Verbose) {Write-Verbose "Other Error:  $Err"} 

        switch ($ErrorAction)
        {
            {'SilentlyContinue','Ignore' -contains $_} {}
            'Stop' {     Throw $Err}
            'Continue' { Throw $Err}
            Default {    Throw $Err}
        }
    }


    If(-not $persistConnection)
    {
        Write-Verbose "   Cleaning up connection..."
        $cxn.Close()
        $results = @{dataset = $ds; connection = $null}
        remove-variable ds,da,cxn,cmd
    }
    Else
    {
        Write-Verbose "   Persisting connection..."
        $results = @{dataset = $ds; connection = $cxn}
        remove-variable ds,da,cmd
    }

    Return $results
}

Function Get-Auth
{
    Param($sqlUserKeyName, $sqlKeyPassword)
#    Add-Type -AssemblyName PresentationFramework
    $error.Clear()
    If((Get-AzContext)){Disconnect-AzAccount}
    Do
    {
        $Global:cred = Get-Credential -Message "Please enter your Azure Credentials"
        If(-not $Global:Cred)
        {
            If($forceAzLogin)
            {
                $msgBoxInput =  [System.Windows.Forms.MessageBox]::Show('You did not specify the credentials. The Servers and Databases will use your local CLI Connect-AzAccount so the credentials are required.','Missing credentials','OkCancel','Error')
            }
            Else
            {
                $msgBoxInput =  [System.Windows.Forms.MessageBox]::Show('You did not specify the credentials. Would you like to try again? Select no if you would like to use keyvault.','Missing credentials','YesNoCancel','Error')
            }
            switch  ($msgBoxInput) {
                'Yes' {}
                'Ok' {}
                'No' {$continue = $true}
                'Cancel' {exit}
            }
        }
    }
    Until($continue -or $Global:cred)

    $Global:PlainPWD = $Global:cred.GetNetworkCredential().Password

    If($Global:cred)
    {
        Write-Verbose "Forcing Connect-AzAccount..."
        Connect-AzAccount -Credential $Global:cred -ErrorAction Stop | Out-null
    }
    
    If($Global:cred){Write-Verbose "Manual credential created"; return}
    [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    $title = 'Keyvault'
    $msg   = 'Enter your Keyvault Name:'
    $text = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)
    If($text -eq ""){Write-Error -Message "No Keyvault specified... exiting" ;Exit}
    $Global:cred = (Get-KeyVaultSQLCredentials -keyVaultName $text -sqlKeyName $sqlUserKeyName -passKeyName $sqlKeyPassword).cred
    if($Error){Write-Error -Message $Error.Exception; exit}
}

# ==============================================================
# GLOBALS
# ==============================================================
#$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$error.Clear()
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()


Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

Get-Auth

# ==============================================================
# INIT
# ==============================================================

$Global:Form                            = New-Object system.Windows.Forms.Form
$Global:Form.Icon                       = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)
$Global:Form.ClientSize                 = New-Object System.Drawing.Point(724,441)
$Global:Form.text                       = "Azure SQL User Manager"
$Global:Form.TopMost                    = $false

$labServer                              = New-Object system.Windows.Forms.Label
$labServer.text                         = "Server:"
$labServer.AutoSize                     = $true
$labServer.width                        = 25
$labServer.height                       = 10
$labServer.location                     = New-Object System.Drawing.Point(6,9)
$labServer.Font                         = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$Global:selServer                       = New-Object system.Windows.Forms.ComboBox
$Global:selServer.width                 = 372
$Global:selServer.height                = 20
$Global:selServer.location              = New-Object System.Drawing.Point(56,5)
$Global:selServer.Font                  = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$Global:selDatabase                     = New-Object system.Windows.Forms.ListView
$Global:selDatabase.View                = "Details"
$Global:selDatabase.width               = 206
$Global:selDatabase.height              = 371
$Global:selDatabase.location            = New-Object System.Drawing.Point(13,57)

# Add items to the ListView
Get-AllSqlServers

$Global:selUser                         = New-Object system.Windows.Forms.ListView
$Global:selUser.View                    = "Details"
$Global:selUser.width                   = 477
$Global:selUser.height                  = 332
$Global:selUser.location                = New-Object System.Drawing.Point(235,57)

$btnAdd                                 = New-Object system.Windows.Forms.Button
$btnAdd.Enabled                         = $false
$btnAdd.text                            = "Add User"
$btnAdd.width                           = 90
$btnAdd.height                          = 30
$btnAdd.location                        = New-Object System.Drawing.Point(237,399)
$btnAdd.Font                            = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$btnAddGrp                              = New-Object system.Windows.Forms.Button
$btnAddGrp.Enabled                      = $false
$btnAddGrp.text                         = "Add Group"
$btnAddGrp.width                        = 90
$btnAddGrp.height                       = 30
$btnAddGrp.location                     = New-Object System.Drawing.Point(337,399)
$btnAddGrp.Font                         = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$btnTest                                 = New-Object system.Windows.Forms.Button
$btnTest.Enabled                         = $true
$btnTest.text                            = "Test"
$btnTest.width                           = 60
$btnTest.height                          = 30
$btnTest.location                        = New-Object System.Drawing.Point(400,399)
$btnTest.Font                            = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$btnUserPermissions                      = New-Object system.Windows.Forms.Button
$btnUserPermissions.Enabled              = $false
$btnUserPermissions.text                 = "Permissions"
$btnUserPermissions.width                = 90
$btnUserPermissions.height               = 30
$btnUserPermissions.location             = New-Object System.Drawing.Point(488,399)
$btnUserPermissions.Font                 = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$btnRunAsUser                            = New-Object system.Windows.Forms.Button
$btnRunAsUser.Enabled                    = $false
$btnRunAsUser.text                       = "RunAs"
$btnRunAsUser.width                      = 65
$btnRunAsUser.height                     = 30
$btnRunAsUser.location                   = New-Object System.Drawing.Point(580,399)
$btnRunAsUser.Font                       = New-Object System.Drawing.Font('Microsoft Sans Serif',10)


$btnRemove                              = New-Object system.Windows.Forms.Button
$btnRemove.Enabled                      = $false
$btnRemove.text                         = "Remove"
$btnRemove.width                        = 65
$btnRemove.height                       = 30
$btnRemove.location                     = New-Object System.Drawing.Point(647,399)
$btnRemove.Font                         = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$Global:Form.controls.AddRange(@($labServer,$selServer,$selDatabase,$selUser,$btnAdd,$btnAddGrp,$btnRemove,$btnUserPermissions,$btnRunAsUser))

$btnRunAsUser.Add_Click({ If(-not $Global:SelectedUser){[System.Windows.Forms.MessageBox]::Show('Please select a user to run as first')}Else{Invoke-AzSqlRunAsUser} })
$btnUserPermissions.Add_Click({ If(-not $Global:SelectedUser){[System.Windows.Forms.MessageBox]::Show('Please select a user to get permissions first')}Else{Invoke-AzSqlGetUserPermissions} })
$btnRemove.Add_Click({ If(-not $Global:SelectedUser){[System.Windows.Forms.MessageBox]::Show('Please select a user to remove first')}Else{Remove-AzSqlPermission} })
$btnAdd.Add_Click({ $ADUsers=User-Selector; If(-not $ADUsers){[System.Windows.Forms.MessageBox]::Show('No user selected')}Else{Add-AzSqlPermission -Users $ADUsers} })
$btnAddGrp.Add_Click({ $ADGroups=AAD-Selector; If(-not $ADGroups){[System.Windows.Forms.MessageBox]::Show('No group selected')}Else{Add-AzSqlPermission -Users $ADGroups} })
If($debugEnabled){ $Global:Form.controls.Add($btnTEST) ;$btnTEST.Add_Click({ If(-not $Global:SelectedUser){[System.Windows.Forms.MessageBox]::Show('Please select a user to remove first')}Else{TESTFUNCTION} }) }
$Global:selServer.Add_SelectedValueChanged({ $Global:SelectedServer = $Global:selServer.SelectedItem; Get-AllSqlDbs; write-host $SelectedServer })
$Global:selDatabase.Add_Click({ $Global:SelectedDatabase = $Global:selDatabase.SelectedItems[0].Text; $btnAdd.Enabled=$True; $btnAddGrp.Enabled=$True; Set-UserList})
$Global:selUser.Add_Click({ $Global:SelectedUser = $Global:selUser.SelectedItems[0].Text; $btnRemove.Enabled=$True; $btnRunAsUser.Enabled=$True; $btnUserPermissions.Enabled=$True;  })

$Global:Form.ShowDialog()