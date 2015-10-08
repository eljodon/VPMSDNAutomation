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

# select Azure subscription
$subscriptionName = "Visual Studio Premium with MSDN"
Select-AzureSubscription –SubscriptionName $subscriptionName

# start the sql server backend service
$cloudServiceName = "iiswebsvc" 
StartOrStop-VMs -AzureSubscriptionName $subscriptionName -TargetService $cloudServiceName -RequestedAction "Start"