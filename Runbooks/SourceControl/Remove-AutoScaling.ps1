# dot-source the function script for New-AzureVNet
. .\VPAzureLibrary.ps1

# name of the Automation Credential Asset this runbook will use to authenticate to Azure.
$credentialAssetName = "AzureDefaultCredential"

# get the credential with the above name from the Automation Asset store
$cred = Get-AutomationPSCredential -Name $credentialAssetName
if(!$cred) {
    Throw "Could not find an Automation Credential Asset named '${AutomationServiceCredentials}'. Make sure you have created one in this Automation Account."
}

# read the username and passwrod in clear text
$userName = $cred.GetNetworkCredential().UserName
$password = $cred.GetNetworkCredential().Password

# connect to your Azure Account
$account = Add-AzureAccount -Credential $cred
if(!$account) {
    Throw "Could not authenticate to Azure using the credential asset '${AutomationServiceCredentials}'. Make sure the user name and password are correct."
}

# select Azure subscription
$subscriptionName = "Visual Studio Premium with MSDN"
Select-AzureSubscription –SubscriptionName $subscriptionName

# This script will require the Web Application and permissions setup in Azure Active Directory
$clientID = Get-AutomationVariable -Name "AzurePowerShellClientID"	# Identifies application in Azure AD

# Get an Oauth 2 access token based on client id, secret and tenant domain
$loginURL      = "https://login.windows.net"
$tenantdomain  = "rickyjimenezlive.onmicrosoft.com"
$resource = "https://management.core.windows.net/"
$body  = @{grant_type="password";resource=$resource;client_id=$clientID;username=$userName;password=$password}
$oauth = (Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body)

# Check if the token was acquired
if ($oauth.access_token -ne $null)
{
	# Initialize variables
	$cloudServiceName = "iiswebsvc"
	$availabilitySetName = "IIS-AVSET"
		
    # Set the AutoScale settings using our function
    [xml]$autoScaleSettings = Remove-AzureAutoScale -subscriptionName $subscriptionName -cloudServiceName $cloudServiceName -availabilitySetName $availabilitySetName -oauth $oauth -Verbose


    # Show the resulting settings
    $autoScaleSettings.InnerXml
}
else
{
    Write-Error("Unable to acquire OAuth2 access token")
}