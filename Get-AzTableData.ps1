#region Globals

Import-Module Az.Storage

$resourceGroup = "rgLinkPortal"
$storageAccount = "salinkportal"
$tableName = "Links"

$saContext = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
$table = Get-AzStorageTable -Name $tableName -Context $saContext
$cloudTable = $table.CloudTable

$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

[string]$startHTML = @'
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.0-beta2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-BmbxuPwQa2lc/FVzBcNJ7UAyJxM6wuqIj61tLrc4wSX0szH/Ev+nYRRuWlolflfl" crossorigin="anonymous">
<link href="https://cdn.datatables.net/1.10.23/css/jquery.dataTables.min.css" rel="stylesheet">
<title>Link Portal - seharper</title>
<style>
fieldset {
  background-color: #eeeeee;
}

legend {
  background-color: gray;
  color: white;
  padding: 5px 10px;
}

table, th, td {
    border: 1px solid black;
}

table {
    justify-content: center;
    width: 98%;
    margin: auto;
}

</style>
</head>
<body>
<!-- jQuery first, then Popper.js, then Bootstrap JS -->
<script src="https://code.jquery.com/jquery-3.5.1.js" integrity="sha256-QWo7LDvxbWT2tbbQ97B53yJnYU3WhH/C8ycbRAkjPDc=" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.6.0/dist/umd/popper.min.js" integrity="sha384-KsvD1yqQ1/1+IA7gi3P0tyJcT3vR+NdBTt13hSJ2lnve8agRGXTTyNaBYmCR/Nwi" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.0-beta2/dist/js/bootstrap.min.js" integrity="sha384-nsg8ua9HAw1y0W1btsyWgBklPnCUAFLuTMS2G72MMONqmOymq585AcH49TLBQObG" crossorigin="anonymous"></script>
<script src="https://cdn.datatables.net/1.10.23/js/jquery.dataTables.min.js"></script>
<script>
$(document).ready(function() {
    $('table.display').DataTable();
} );
</script>
'@

[string]$endHTML = '</body></html>'


#endregion Globals

#region Enums
enum Category {
    AAA_Start_Pages
    AADConnect
    Accreditations
    ADCS
    ADDS
    ADFS
    Azure
    CE_General
    Microsoft
    Personal
    PowerShell
    Search
    Security
    Uncategorized
    Windows
}

#endregion Enums

#region Functions

#region Resolve
function Resolve-Title {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]$ResolveTitle
    )

    if ($ResolveTitle.Length -eq 0) { return $false }
    else { return $true }
}

function Resolve-Description {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]$ResolveDescription
    )

    if ($ResolveDescription.Length -eq 0) { return $false }
    else { return $true }
}

function Resolve-URI {
    [CmdletBinding()]
    param (
        [Parameter()][string]$URIToCheck
    )
    $dupCheck = Get-AllFromLinkPortal
    if ($dupCheck.URI -contains $URIToCheck) {
        return $($dupCheck | Where-Object { $_.URI -eq $URIToCheck }).RowKey
    }
    else { return 0 }
}
#endregion Resolve

#region Optimize

function Optimize-URL {
    $results = Get-AllFromLinkPortal
    foreach ($result in $results) {
        $Error.Clear()
        $webResult = Invoke-WebRequest -Uri $result.Uri
        if ($Error.Count -gt 0) {
            $wasError = Read-Host "An error occurred reaching $($result.Uri) :  Would you like to delete it? (Y/N)"
            if ($wasError -ieq "y") {
                Remove-LinkPortalRow -URI $result.URI
            }
        }
        elseif ($webResult.BaseResponse.StatusCode -ine "OK") {
            $wasError = Read-Host "An error occurred reaching $($result.Uri):  Would you like to delete it? (Y/N)"
            if ($wasError -ieq "y") {
                Remove-LinkPortalRow -URI $result.URI
            }
        }
        elseif ($webResult.BaseResponse.ResponseURI -like "*404*") {
            $wasError = Read-Host "An error occurred reaching $($result.Uri):  Would you like to delete it? (Y/N)"
            if ($wasError -ieq "y") {
                Remove-LinkPortalRow -URI $result.URI
            }
        }
        else {
            $finalCheck = Read-Host "$($result.URI) looks OK.  Shall I view this page in Edge? (Y/N)"
            if ($finalCheck -ieq "y") {
                Start-Process -FilePath $edgePath -ArgumentList $result.URI
            }
        }
    }
}


function Optimize-Description {
    $results = Get-AllFromLinkPortal
    foreach ($result in $results) {
        if ($result.Description -ilike "Imported from *") {
            # What now?  Report?  Open and change?  Automation?
        }
    }
}

#endregion Optimize

#region Get

function Get-AllFromLinkPortal {
    [CmdletBinding()]
    param (
        [Parameter()][switch]$AsTable
    )

    $results = Get-AzTableRow -table $cloudTable
    if ($AsTable) {
        $results | Format-Table -Property Title, URI, Description, Category, Keywords -AutoSize -Wrap -GroupBy Category
    }
    else { return $results }
}

function Get-UncategorizedLinks {
    param (
        [Parameter()][switch]$AsTable
    )
    $results = Get-AllFromLinkPortal | Where-Object { $_.category -eq "Uncategorized" }
    if ($AsTable) {
        $results | Select-Object -Property Title, URI, Description, Category, Keywords | Out-Gridview
    }
    else { return $results }
    
}

function Get-LinksWithoutKeywords {

}

#endregion Get

#region New
function New-LinkPortalRow {
    [CmdletBinding()]
    param (
        #Parameter help description
        [Parameter(Mandatory = $true)][string]$Title,        
        [Parameter(Mandatory = $true)][string]$URI,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $false)][Category]$category,
        [Parameter(Mandatory = $false)][string]$Keywords,
        [Parameter(Mandatory = $false)][switch]$Resolved
    )

    if (-not $Resolved) {
        if (Resolve-Title -ResolveTitle $Title) { $SetTitle = $Title }
        else { $SetTitle = Read-Host "Please enter a title" }

        if (Resolve-Description -ResolveDescription $Description) { $SetDescription = $Title }
        else { $SetDescription = Read-Host "Please enter a description" }
    }
    
    if ($(Resolve-URI -URIToCheck $URI) -ne 0) { Write-Output "Link already exists"; Get-FromLinkPortal -rowKey $(Resolve-URI -URIToCheck $URI); continue }
    
    else {
        $SetTitle = $Title
        $SetURI = $URI
        $SetDescription = $Description
    }

    if ($category.Length -gt 0 ) { $SetCategory = $category.ToString() }
    else { $SetCategory = [category]::Uncategorized.ToString() }

    if ($Keywords.Length -gt 0 ) { $SetKeywords = $Keywords.ToString() }
    else { $SetKeywords = [string]::Empty }

    $linkProperties = @{
        URI         = [string]$SetURI
        Title       = [string]$SetTitle
        Description = [string]$SetDescription
        Category    = [string]$SetCategory
        Keywords    = [string]$SetKeywords
    }
    
    Add-AzTableRow -table $cloudTable -partitionKey 1 -rowKey $([guid]::NewGuid()) -property $linkProperties | Out-Null
    
}

function New-LinkPortalRowJustURI {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$URI,
        [Parameter(Mandatory = $false)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Description,
        [Parameter(Mandatory = $false)][Category]$category,
        [Parameter(Mandatory = $false)][string]$Keywords
    )

    [string]$SetTitle = [string]::Empty
    [string]$SetDescription = [string]::Empty

    $webResult = Invoke-WebRequest -Uri $URI

    $HTMLResult = $webResult.ParsedHtml.childNodes | Where-Object { $_.nodename -eq 'HTML' }
    $HEADResult = $HTMLResult.childNodes | Where-Object { $_.nodename -eq 'HEAD' }
    $METAResult = $HEADResult.childNodes | Where-Object { $_.nodename -eq 'META' }

    $descMeta = $METAResult.outerHTML | Where-Object { $_ -like '*name=description*' }
    $($descMeta -match 'content=\"(?<descMatch>[\s\S]*)\"') | Out-Null

    $keywordMeta = $METAResult.outerHTML | Where-Object { $_ -like '*name=*keywords*' }
    $($keywordMeta -match 'content=\"(?<keywordMatch>[\s\S]*)\"') | Out-Null

    if (Resolve-Title -ResolveTitle $Title) { $SetTitle = $Title }
    elseif (Resolve-Title -ResolveTitle $webResult.ParsedHtml.Title) { $SetTitle = $webResult.ParsedHtml.Title }
    else { $SetTitle = Read-Host "Please enter a title" }

    if (Resolve-Description -ResolveDescription $Description) { $SetDescription = $Description }
    elseif (Resolve-Description -ResolveDescription $($Matches.descMatch -as [string])) { $SetDescription = $Matches.descMatch }
    else { $SetDescription = Read-Host "Please enter a description" }

    if ($category.Length -gt 0 ) { $SetCategory = $category.ToString() }
    else { $SetCategory = [category]::Uncategorized.ToString() }

    if ($Keywords.Length -gt 0 ) { $SetKeywords = $Keywords.ToString() }
    elseif ($Matches.keywordMeta.Count -gt 0) { $SetKeywords = $Matches.keywordMeta -as [string] }
    else { $SetKeywords = [string]::Empty }

    New-LinkPortalRow -Title $SetTitle -URI $webResult.BaseResponse.ResponseUri -Description $SetDescription -category $SetCategory -Keywords $SetKeywords -Resolved
}
#endregion New

#region Set
function Update-LinkPortalRow {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$URI,
        [Parameter(Mandatory = $false)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Description,
        [Parameter(Mandatory = $false)][Category]$category,
        [Parameter(Mandatory = $false)][string]$Keywords
    )

    $updates = Get-AllFromLinkPortal | Where-Object { $_.URI -eq $URI }
    
    if ($Title.Length -eq 0) {
        $rowToUpdate_Title = Read-Host "`r`nEnter updated title here, or hit Enter not to change"
        if ($rowToUpdate_Title.Length -gt 0) {
            $updates.Title = $rowToUpdate_Title
        }
    }
    else { $updates.Title = $Title }
    
    if ($Description.Length -eq 0) {
        $rowToUpdate_Description = Read-Host "`r`nEnter updated description here, or hit Enter not to change"
        if ($rowToUpdate_Description.Length -gt 0) {
            $updates.Description = $rowToUpdate_Description
        }
    }
    else { $updates.Description = $Description }

    if ($category -in [category]) {
        Write-Output "`r`nValid categories: $([category].GetEnumValues() -as [string] -replace " ", ", ")"
        $rowToUpdate_Category = Read-Host "Enter updated category here, or hit Enter not to change"
        if (($rowToUpdate_Category.Length -gt 0) -and ($rowToUpdate_Category -in [category]::GetNames([category]))) {
            $updates.Category = $rowToUpdate_Category
        }
        else {
            Write-Output "Category does not match, choose from one of the following"
            Write-Output "`r`nValid categories: $([category].GetEnumValues() -as [string] -replace " ", ", ")"
            $rowToUpdate_Category = Read-Host "Enter updated category here, or hit Enter not to change"
            if (($rowToUpdate_Category.Length -gt 0) -and ($rowToUpdate_Category -in [category]::GetNames([category]))) {
                $updates.Category = $rowToUpdate_Category
            }
            else { continue }
        }
    }
    else { $updates.Category = $category.ToString() }

    if ($Keywords.Length -gt 0) {
        $rowToUpdate_Keywords = Read-Host "`r`nEnter updated keywords here, or hit Enter not to change"
        if ($rowToUpdate_Keywords.Length -gt 0) {
            $updates.Keywords = $rowToUpdate_Keywords
        }
    }
    else { $updates.Keywords = $Keywords }

    Update-AzTableRow -Table $table -entity $updates
}

function Update-CategoryAutomagically {
    
}
#endregion Set

#region Remove

function Remove-LinkPortalRow {
    [CmdletBinding()]
    param (
        [Parameter()][string]$URI
    )

    $rowToRemove = Get-AllFromLinkPortal | Where-Object { $_.URI -eq $URI }
    Remove-AzTableRow -Table $table -entity $rowToRemove

    if ($(Get-AllFromLinkPortal | Where-Object { $_.URI -eq $URI }).Count -eq 0) {
        Write-Output "$URI successfully deleted"
    }
    else {
        Write-Output "Unable to delete $URI"
    }


}
#endregion Remove

#region Export
function Export-LinksToHTML {

    $links = Get-AllFromLinkPortal
    [string[]]$categories = $links.Category | Sort-Object -Unique

    Set-Content -Path .\index.html -Value $startHTML
    ForEach ($linkCategory in $categories) {
        Add-Content -Path .\index.html -Value "<fieldset title=`"$($linkCategory, "fieldset" -join "_")`"><legend>$($linkCategory)</legend><table id=`"$($linkCategory)`" class=`"display`"><thead><th>Title</th><th>URI</th><th>Description</th><th>Keywords</th></thead>"
        $links.Where( { $_.category -eq $linkCategory }).foreach( { Add-Content -Path .\index.html -Value "<tr><td>$($_.Title)</td><td><a target=`"_blank`" href=$($_.URI)>$($_.URI)</a></td><td>$($_.Description)</td><td>$($_.Keywords)</td></tr>" } )
        Add-Content -Path .\index.html -Value "</table></fieldset><p/>"
        #Add-Content -Path .\index.html -Value $(Insert-ScriptForSorting -linkCategory $linkCategory)
    }
    Add-Content -Path .\index.html -Value $endHTML
    Set-AzStorageBlobContent -File index.html -Context $saContext -Force -BlobType Block -Properties @{"ContentType" = "text/html" } -Container '$web'

}

function Export-LinksToHTMLOnePage {

    $links = Get-AllFromLinkPortal
    Set-Content -Path .\indexone.html -Value $startHTML
    Add-Content -Path .\indexone.html -Value "<fieldset title=`"Link Portal One Page`"><legend>Link Portal One Page</legend><table id=`"Table1`" class=`"display`"><thead><th>Title</th><th>URI</th><th>Description</th><th>Category</th><th>Keywords</th></thead>"
    $links.foreach( { Add-Content -Path .\indexone.html -Value "<tr><td>$($_.Title)</td><td><a target=`"_blank`" href=$($_.URI)>$($_.URI)</a></td><td>$($_.Description)</td><td>$($_.Category)</td><td>$($_.Keywords)</td></tr>" } )
    Add-Content -Path .\indexone.html -Value "</table></fieldset><p/>"
    Add-Content -Path .\indexone.html -Value $endHTML
    Set-AzStorageBlobContent -File indexone.html -Context $saContext -Force -BlobType Block -Properties @{"ContentType" = "text/html" } -Container '$web'

}
#endregion Export

#endregion Functions

#Export-ModuleMember -Function @("Get-AllFromLinkPortal")

Export-LinksToHTMLOnePage