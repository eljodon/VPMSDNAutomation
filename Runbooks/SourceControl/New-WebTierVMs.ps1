# dot-source the function script for New-AzureVNet
. .\VPAzureLibrary.ps1

# name of the Automation Credential Asset this runbook will use to authenticate to Azure.
$credentialAssetName = "AzureDefaultCredential"

# get the credential with the above name from the Automation Asset store
$cred = Get-AutomationPSCredential -Name $credentialAssetName
if(!$cred) {
    Throw "Could not find an Automation Credential Asset named '${AutomationServiceCredentials}'. Make sure you have created one in this Automation Account."
}

# connect to your Azure Account
$account = Add-AzureAccount -Credential $cred
if(!$account) {
    Throw "Could not authenticate to Azure using the credential asset '${AutomationServiceCredentials}'. Make sure the user name and password are correct."
}

# select Azure subscription, if more than one
$subscriptionName = 'Visual Studio Premium with MSDN'
Select-AzureSubscription –SubscriptionName $subscriptionName

# provision a new VNet using our new function
[xml]$newAzureVNet = New-AzureVNet -Verbose

# show resulting XML
$newAzureVNet.InnerXml

# show new provisioned VNet
Get-AzureVNetSite

# storage account where the blob disks are going to be located
$storageAccountName = "azurepracticedemos"

# attempt to acquire it
$storageAccount = Get-AzureStorageAccount -StorageAccountName $storageAccountName

# create it if it does not exists
if(!$storageAccount)
{
    # create the storage account
    New-AzureStorageAccount -StorageAccountName $storageAccountName -Location "West US"  -ErrorAction Stop
}

# set the storage account as the current in the subscription
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccountName

# OS image to be installed in the VM
$img = (Get-AzureVMImage | where {$_.Label -like "Windows Server 2012 R2 Datacenter*"} | sort PublishedDate -Descending)[0].ImageName

$subnetName = 'Subnet-1'

# configure VM1
$serverIp = '10.1.0.5'
$vm1 = New-AzureVMConfig -Name "iisvm1" -InstanceSize Small -ImageName $img -AvailabilitySetName 'IIS-AVSET' 
$vm1 | Add-AzureProvisioningConfig -Windows -AdminUsername 'iisadmin' -Password 'some@pass1'
$vm1 | Set-AzureSubnet -SubnetNames $subnetName
$vm1 | Set-AzureStaticVNetIP -IPAddress $serverIp 
$vm1 | Add-AzureEndpoint -Name 'web' -LocalPort 80 -PublicPort 80 -Protocol tcp -LBSetName 'lbweb' -DefaultProbe

# configure VM2
$serverIp = '10.1.0.6'
$vm2 = New-AzureVMConfig -Name "iisvm2" -InstanceSize Small -ImageName $img -AvailabilitySetName 'IIS-AVSET'
$vm2 | Add-AzureProvisioningConfig -Windows -AdminUsername 'iisadmin' -Password 'some@pass1'
$vm2 | Set-AzureSubnet -SubnetNames $subnetName
$vm2 | Set-AzureStaticVNetIP -IPAddress $serverIp
$vm2 | Add-AzureEndpoint -Name 'web' -LocalPort 80 -PublicPort 80 -Protocol tcp -LBSetName 'lbweb' -DefaultProbe

# configure VM3
$serverIp = '10.1.0.7'
$vm3 = New-AzureVMConfig -Name "iisvm3" -InstanceSize Small -ImageName $img -AvailabilitySetName 'IIS-AVSET'
$vm3 | Add-AzureProvisioningConfig -Windows -AdminUsername 'iisadmin' -Password 'some@pass1'
$vm3 | Set-AzureSubnet -SubnetNames $subnetName
$vm3 | Set-AzureStaticVNetIP -IPAddress $serverIp
$vm3 | Add-AzureEndpoint -Name 'web' -LocalPort 80 -PublicPort 80 -Protocol tcp -LBSetName 'lbweb' -DefaultProbe
 
# Create all VMs
New-AzureVM -ServiceName 'iiswebsvc' -VNetName 'VNet01' -Location 'West US' -VMs $vm1,$vm2,$vm3