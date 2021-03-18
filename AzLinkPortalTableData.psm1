#Requires -Module "AzTable"


function Initialize-LinkPortalCmdlets {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$resourceGroup,
        [Parameter(Mandatory=$true)][string]$storageAccount,
        [Parameter(Mandatory=$true)][string]$tableName
    )
    $htVars = {
        resourceGroup = $resourceGroup
        storageAccount = $storageAccount
        tableName = $tableName
        saContext = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
        table = Get-AzStorageTable -Name $tableName -Context $saContext
        linkPortalIsInitialized = $true
    }
    return $htVars
}
function Get-AllFromLinkPortal {
    [CmdletBinding()]
    param (
        [Microsoft.Azure.Commands.Management.Storage.Models.PSStorageAccount]$table,
        [Parameter()][switch]$AsTable
    )
    if ($htVars.linkPortalIsInitialized) {
        $results = Get-AzStorageTableRowAll -table $table
        if ($AsTable) {
            $results | Format-Table -Property Title, URI, Description, Category, Keywords -AutoSize -Wrap -GroupBy Category
        }
        else { return $results }
    }
    else { Initialize-LinkPortalCmdlets; Get-AllFromLinkPortal  }
}

Get-Process