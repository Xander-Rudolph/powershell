Function Invoke-AzSqlCmd
{
    Param($serverInstance
         ,$dbName
         ,$Query
         ,$context
    )
    # Build off this article https://thomasthornton.cloud/2020/10/06/query-azure-sql-database-using-service-principal-with-powershell/

    $ConnectionString="Data Source=$serverInstance; Initial Catalog=$dbName;"

    $dexResourceUrl='https://database.windows.net/'
    $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, `
                                    $context.Environment, 
                                    $context.Tenant.Id.ToString(),
                                    $null, 
                                    [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, 
                                    $null, $dexResourceUrl).AccessToken
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection                
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    try 
    {
        $SqlConnection.ConnectionString = $ConnectionString
        if ($token)
        {
            $SqlConnection.AccessToken = $token
        }
        $SqlConnection.Open()
         
        $SqlCmd.Connection = $SqlConnection 
        
        $SqlCmd.CommandText = $Query
        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd
        $DataSet = New-Object System.Data.DataSet
        $SqlAdapter.Fill($DataSet)

        # based on https://www.stefanroth.net/2018/04/11/powershell-create-clean-customobjects-from-datatable-object/
        $result = @()
        ForEach ($Row in $DataSet.Tables[0])
        {
            $Properties = @{}
            For($i = 0;$i -le $Row.ItemArray.Count - 1;$i++)
            {
                $Properties.Add($DataSet[0].Tables[0].Columns[$i], $Row.ItemArray[$i])
            }
            $result += New-Object -TypeName PSObject -Property $Properties  
        }
    }
    finally
    {
        $SqlAdapter.Dispose()
        $SqlCmd.Dispose()
        $SqlConnection.Dispose()
    }
    return $result
}