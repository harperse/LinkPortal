#docker login azure
#docker login linkportal.azurecr.io --username linkportal --password Kop3KU0uV6FxUFIJDamm7bFbPoAX7G2/
#docker context create aci acilinkportal
#docker --context acilinkportal run -p 80:80 --volume salinkportal/bclinkportal-web:/usr/local/apache2/htdocs/linkportal --name salinkportal-containers --detach --domainname salinkportal httpd


$rg = "rgLinkPortal"
$lp = "acrLinkPortal"
$sa = "saLinkPortal"
$con = "$sa-containers"
#$pip = "pipLinkPortal"
$loc = "eastus"

if ($(Get-AzContext).Count -ne 1) {
    Connect-AzAccount
}

Connect-AzContainerRegistry -Name $lp -UserName $lp -Password 'QYdLp5I1ZUA7=51cu9/WZJmQTIbfttwz'
if (Import-AzContainerRegistryImage -ResourceGroupName $rg -RegistryName $lp -SourceImage 'library/httpd:latest' -SourceRegistryUri docker.io) {
    Write-Output "Pull succeeded"
}
#$secureKey = $($(Get-AzStorageAccountKey -ResourceGroupName $rg -Name $sa).Value[0] | ConvertTo-SecureString -AsPlainText)

Get-AzContainerGroup -ResourceGroupName $rg -Name $con | Remove-AzContainerGroup
#$azContainerPIP = New-AzPublicIpAddress -Name $pip -ResourceGroupName $rg -Location $loc -AllocationMethod Static -Sku Basic -IpAddressVersion IPv4
#$azContainerVolumeObject = New-AzContainerGroupVolumeObject -Name 'acgvolume01' -AzureFileShareName 'afslinkportal' -AzureFileStorageAccountName $sa -AzureFileStorageAccountKey $secureKey
$port80 = New-AzContainerGroupPortObject -Port 80 -Protocol TCP
$container = New-AzContainerInstanceObject -Image httpd -Name 'con1'
New-AzContainerInstanceInitDefinitionObject -Name "initDefinition" -Command "$(Get-Content .\index.html) > /usr/local/apache2/htdocs/index.html" -Image httpd
New-AzContainerGroup -ResourceGroupName $rg -Name $con -Location $loc -Container $container -Volume $azContainerVolumeObject -IPAddressType Public -IPAddressPort $port80 -OSType Linux -RestartPolicy Never