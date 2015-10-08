function New-AzureVNet {
<#
.SYNOPSIS
New-AzureVNet provisions new Azure Virtual Networks in an existing Azure Subscription
.DESCRIPTION
New-AzureVNet defines new Azure Virtual Network and DNS Server information, 
merges with an existing Azure Virtual Network configuration, 
and then provisions the resulting final configuration in an existing Azure subscription.
For demonstration purposes only. 
No support or warranty is supplied or inferred. 
Use at your own risk.
.PARAMETER newDnsServerName
The name of a new DNS Server to provision
.PARAMETER newDnsServerIP
The IPv4 address for the new DNS Server
.PARAMETER newVNetName
The name of a new Azure Virtual Network to provision
.PARAMETER newVNetLocation
The name of the Azure datacenter region in which to provision the new Azure Virtual Network
.PARAMETER newVNetAddressRange
The IPv4 address range for the new Azure Virtual Network in CIDR format. Ex) 10.1.0.0/16
.PARAMETER newSubnetName
The name of a new subnet within the Azure Virtual Network
.PARAMETER newSubnetAddressRange
The IPv4 address range for the subnet in the new Azure Virtual Network in CIDR format. Ex) 10.1.0.0/24
.PARAMETER configFile
Specify file location for writing finalized Azure Virtual Network configuration in XML format.
.INPUTS
Parameters above.
.OUTPUTS
Final Azure Virtual Network XML configuration that was successfully provisioned.
.NOTES
Version: 1.0
Creation Date: Aug 1, 2014
Author: Keith Mayer ( http://KeithMayer.com )
Change: Initial function development
.EXAMPLE
New-AzureVNet -Verbose
Provision a new Azure Virtual Network using default values.
.EXAMPLE
New-AzureVNet -newDnsServerName labdns01 -newDnsServerIP 10.1.0.5 -newVNetName labnet01 -newVNetLocation "West US"
Provision a new Azure Virtual Network using specific values.
#>

[CmdletBinding()]
param 
(
[string]$newDnsServerName = 'dns01',
[string]$newDnsServerIP = '10.1.0.4',
[string]$newVNetName = 'VNet01',
[string]$newVNetLocation = 'West US',
[string]$newVNetAddressRange = '10.1.0.0/16',
[string]$newSubnetName = 'Subnet-1',
[string]$newSubnetAddressRange = '10.1.0.0/24',
[string]$configFile = "c:\Temp\AzureVNetConfig.XML"
)
begin {

    Write-Verbose "Deleting $configFile if it exists"
    Del $configFile -ErrorAction:SilentlyContinue

}

process {

    Write-Verbose "Build generic XML template for new Virtual Network"

    $newVNetConfig = [xml] '
        <NetworkConfiguration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration">
          <VirtualNetworkConfiguration>
            <Dns>
              <DnsServers>
                <DnsServer name="" IPAddress="" />
              </DnsServers>
            </Dns>
            <VirtualNetworkSites>
              <VirtualNetworkSite name="" Location="">
                <AddressSpace>
                  <AddressPrefix></AddressPrefix>
                </AddressSpace>
                <Subnets>
                  <Subnet name="">
                    <AddressPrefix></AddressPrefix>
                  </Subnet>
                </Subnets>
                <DnsServersRef>
                  <DnsServerRef name="" />
                </DnsServersRef>
              </VirtualNetworkSite>
            </VirtualNetworkSites>
          </VirtualNetworkConfiguration>
        </NetworkConfiguration>
        '

    Write-Verbose "Add DNS attribute values to XML template"

    $newDnsElements = $newVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers.DnsServer
    $newDnsElements.SetAttribute('name', $newDnsServerName)
    $newDnsElements.SetAttribute('IPAddress', $newDnsServerIP)

    Write-Verbose "Add VNet attribute values to XML template"

    $newVNetElements = $newVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite
    $newVNetElements.SetAttribute('name', $newVNetName)
    $newVNetElements.SetAttribute('Location', $newVNetLocation)
    $newVNetElements.AddressSpace.AddressPrefix = $newVNetAddressRange
    $newVNetElements.Subnets.Subnet.SetAttribute('name', $NewSubNetName)
    $newVNetElements.Subnets.Subnet.AddressPrefix = $newSubnetAddressRange
    $newVNetElements.DnsServersRef.DnsServerRef.SetAttribute('name', $newDnsServerName)

    Write-Verbose "Get existing VNet configuration from Azure subscription"

    $existingVNetConfig = [xml] (Get-AzureVnetConfig).XMLConfiguration

    Write-Verbose "Merge existing DNS servers into new VNet XML configuration"

    $existingDnsServers = $existingVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers
    if ($existingDnsServers.HasChildNodes) {
        ForEach ($existingDnsServer in $existingDnsServers.ChildNodes) { 
            if ($existingDnsServer.name -ne $newDnsServerName) {
                $importedDnsServer = $newVNetConfig.ImportNode($existingDnsServer,$True)
                $newVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers.AppendChild($importedDnsServer) | Out-Null
            }
        }
    }

    Write-Verbose "Merge existing VNets into new VNet XML configuration"

    $existingVNets = $existingVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites
    if ($existingVNets.HasChildNodes) {
        ForEach ($existingVNet in $existingVNets.ChildNodes) { 
            if ($existingVNet.name -ne $newVNetName) {
                $importedVNet = $newVNetConfig.ImportNode($existingVNet,$True)
                $newVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.AppendChild($importedVNet) | Out-Null
            }
        }
    }

    Write-Verbose "Merge existing Local Networks into new VNet XML configuration"

    $existingLocalNets = $existingVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.LocalNetworkSites
    if ($existingLocalNets.HasChildNodes) {
        $dnsNode = $newVNetConfig.NetworkConfiguration.VirtualNetworkConfiguration.Dns
        $importedLocalNets = $newVNetConfig.ImportNode($existingLocalNets,$True)
        $newVnetConfig.NetworkConfiguration.VirtualNetworkConfiguration.InsertAfter($importedLocalNets,$dnsNode) | Out-Null
    }

    Write-Verbose "Saving new VNet XML configuration to $configFile"

    $newVNetConfig.Save($configFile)

    Write-Verbose "Provisioning new VNet configuration from $configFile"

    Set-AzureVNetConfig -ConfigurationPath $configFile | Out-Null

}

end {

    Write-Verbose "Deleting $configFile if it exists"
    Del $configFile -ErrorAction:SilentlyContinue

    Write-Verbose "Returning the final VNet XML Configuration"
    (Get-AzureVnetConfig).XMLConfiguration

}
}

function Get-AzureAutoScale {
	<#
	.SYNOPSIS
	Get-AzureAutoScale retrieves the AutoScale settings of a cloude service
	.DESCRIPTION
	Get-AzureAutoScale retrieves the AutoScale settings of a cloude service,
	it requires the caller to pass the OAuth2 data to be used to authenticate against the Azure Service Management REST API.
   	.PARAMETER subscriptionName
	The name of the Azure subscription
	.PARAMETER cloudServiceName
	The cloud service name to read the auto scale settings from
	.PARAMETER availabilitySetName
	The name of the availability set containing the VMs
	.PARAMETER oauth
	The OAuth2 data to be used for authentication purposes against the Azure Service Management API
	.INPUTS
	Parameters above.
	.OUTPUTS
	Auto scale settings XML.
	.NOTES
	Version: 1.0
	Creation Date: Oct 7, 2015
	Author: Ricky Jimenez
	Change: Initial function development
	.EXAMPLE
	Get-AzureAutoScale -subscriptionName "some subscription" -cloudServiceName "service name" -availabilitySetName "set name" -oauth <object> -Verbose
	#>
    [CmdletBinding()]
    param 
    (
    [string]$subscriptionName = '',
    [string]$cloudServiceName = '',
    [string]$availabilitySetName = '',
    [object]$oauth
    )

    begin {


    }

    process {

        Write-Verbose "Read the subscription Id"

        $null = Select-AzureSubscription -SubscriptionName $subscriptionName
	    $subscriptionId = (Get-AzureSubscription -Current).SubscriptionId

        Write-Verbose "Prepare the request headers"

        $requestHeader  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)";'x-ms-version'="2013-10-01";}
        $azureMgmtUri = "https://management.core.windows.net/$subscriptionId/services/monitoring/autoscalesettings?resourceId=/virtualmachines/$cloudServiceName/availabilitySets/$availabilitySetName"
    }

    end {

        Write-Verbose "Returning the AutoScale Settings"
        Invoke-RestMethod -Uri $azureMgmtUri -Method Get -Headers $requestHeader
 
    }
}


function Set-AzureAutoScale {
[CmdletBinding()]
param 
(
[string]$subscriptionName = '',
[string]$cloudServiceName = '',
[string]$availabilitySetName = '',
[string]$minInstances = 2,
[string]$maxInstances = 3,
[string]$defaultInstances = 2,
[string]$cpuScaleOut = 80,
[string]$cpuScaleIn = 20,
[object]$oauth
)
begin {


}

process {

    Write-Verbose "Build generic autoscale configuration Json template for the web request body"

    $jsonBody = @"
    {
    "Profiles": [
    {
      "Name": "Week Day",
      "Capacity": {
        "Minimum": "$minInstances",
        "Maximum": "$maxInstances",
        "Default": "$defaultInstances"
      },
      "Rules": [
        {
          "MetricTrigger": {
            "MetricName": "Percentage CPU",
            "MetricNamespace": "",
            "MetricSource": "/VirtualMachinesAvailabilitySet/$cloudServiceName/$availabilitySetName",
            "TimeGrain": "PT5M",
            "Statistic": "Average",
            "TimeWindow": "PT45M",
            "TimeAggregation": "Average",
            "Operator": "GreaterThanOrEqual",
            "Threshold": "$cpuScaleOut"
          },
          "ScaleAction": {
            "Direction": "Increase",
            "Type": "ChangeCount",
            "Value": "1",
            "Cooldown": "PT20M"
          }
        },
        {
          "MetricTrigger": {
            "MetricName": "Percentage CPU",
            "MetricNamespace": "",
            "MetricSource": "/VirtualMachinesAvailabilitySet/$cloudServiceName/$availabilitySetName",
            "TimeGrain": "PT5M",
            "Statistic": "Average",
            "TimeWindow": "PT45M",
            "TimeAggregation": "Average",
            "Operator": "LessThanOrEqual",
            "Threshold": "$cpuScaleIn"
          },
          "ScaleAction": {
            "Direction": "Decrease",
            "Type": "ChangeCount",
            "Value": "1",
            "Cooldown": "PT20M"
          }
        }
      ],
      "Recurrence": {
        "Frequency": "Week",
        "Schedule": {
          "TimeZone": "US Mountain Standard Time",
          "Days": [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" ],
          "Hours": [ 8 ],
          "Minutes": [ 0 ]
        }
      }
    },
    {
      "Name": "Week Night",
      "Capacity": {
        "Minimum": "$defaultInstances",
        "Maximum": "$defaultInstances",
        "Default": "$defaultInstances"
      },
      "Rules": [ ],
      "Recurrence": {
        "Frequency": "Week",
        "Schedule": {
          "TimeZone": "US Mountain Standard Time",
          "Days": [ "Monday", "Tuesday", "Wednesday", "Thursday" ],
          "Hours": [ 20 ],
          "Minutes": [ 0 ]
        }
      }
    },
    {
      "Name": "Week End",
      "Capacity": {
        "Minimum": "$defaultInstances",
        "Maximum": "$defaultInstances",
        "Default": "$defaultInstances"
      },
      "Rules": [ ],
      "Recurrence": {
        "Frequency": "Week",
        "Schedule": {
          "TimeZone": "US Mountain Standard Time",
          "Days": [ "Friday" ],
          "Hours": [ 20 ],
          "Minutes": [ 0 ]
        }
      }
    }
  ],
  "Enabled": true
}
"@

    Write-Verbose "Read the subscription Id"

    $null = Select-AzureSubscription -SubscriptionName $subscriptionName
	$subscriptionId = (Get-AzureSubscription -Current).SubscriptionId

    Write-Verbose "Prepare the request headers"

    $requestHeader  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)";'x-ms-version'="2013-10-01";}
    $azureMgmtUri = "https://management.core.windows.net/$subscriptionId/services/monitoring/autoscalesettings?resourceId=/virtualmachines/$cloudServiceName/availabilitySets/$availabilitySetName"

    Write-Verbose "Encode the JSON body"

    [byte[]]$requestBody = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $contentType = "application/json;charset=utf-8"

    Write-Verbose "Call Azure Service Management REST API to add Autoscale settings"

    $response = Invoke-RestMethod -Uri $azureMgmtUri -Method Put -Headers $requestHeader -Body $requestBody -ContentType $contentType
}

    end {

        Write-Verbose "Returning the AutoScale Settings"
        Invoke-RestMethod -Uri $azureMgmtUri -Method Get -Headers $requestHeader
    }
}


function Remove-AzureAutoScale {
[CmdletBinding()]
param 
(
[string]$subscriptionName = '',
[string]$cloudServiceName = '',
[string]$availabilitySetName = '',
[string]$defaultInstances = 3,
[object]$oauth
)
begin {


}

process {

    Write-Verbose "Build generic autoscale configuration Json template for the web request body"

    $jsonBody = @"
    {
        "Profiles": [{
            "Name": "No scheduled times",
            "Capacity": {
                "Minimum": "$defaultInstances",
                "Maximum": "$defaultInstances",
                "Default": "$defaultInstances"
            },
            "Rules": [],
            "Recurrence": {
                "Frequency": "Week",
                "Schedule": {
                    "TimeZone": "US Mountain Standard Time",
                    "Days": [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" ],
                    "Hours": [ 8 ],
                    "Minutes": [ 0 ]
                }
            }
        }],
        "Enabled": false
    }
"@

    Write-Verbose "Read the subscription Id"

    $null = Select-AzureSubscription -SubscriptionName $subscriptionName
	$subscriptionId = (Get-AzureSubscription -Current).SubscriptionId

    Write-Verbose "Prepare the request headers"

    $requestHeader  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)";'x-ms-version'="2013-10-01";}
    $azureMgmtUri = "https://management.core.windows.net/$subscriptionId/services/monitoring/autoscalesettings?resourceId=/virtualmachines/$cloudServiceName/availabilitySets/$availabilitySetName"

    Write-Verbose "Encode the JSON body"

    [byte[]]$requestBody = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $contentType = "application/json;charset=utf-8"

    Write-Verbose "Call Azure Service Management REST API to set Autoscale settings"

    $response = Invoke-RestMethod -Uri $azureMgmtUri -Method Put -Headers $requestHeader -Body $requestBody -ContentType $contentType
}

    end {

        Write-Verbose "Returning the AutoScale Settings"
        Invoke-RestMethod -Uri $azureMgmtUri -Method Get -Headers $requestHeader
    }
}


function Process-VM
{
	[CmdletBinding()]
	Param(
	#Service Name
	[Parameter(Mandatory = $true)]
	[String]$TargetServiceName,
	
	#VM Name
	[Parameter(Mandatory = $true)]
	[String]$TargetVMName,
	
	#VM Status
	[Parameter(Mandatory = $true)]
	[String]$InstanceStatus,

	#Requested Action (Start or Stop)
	[Parameter(Mandatory = $true)]
	[String]$RequestedAction
	)
	
	$timeStampFormat = "g"

    # Check whether to start or stop the instance
    if ($RequestedAction -eq "Stop")
    {
        #Write-Output "$(Get-Date -f $timeStampFormat) - Processing Virtual Machine named $targetVMName"

        if($InstanceStatus -ne "StoppedVM" -and $InstanceStatus -ne "StoppedDeallocated")
        {
            #Shutdown the Instance
            Write-Output "$(Get-Date -f $timeStampFormat) - Shutting Down Virtual Machine named $TargetVMName."
            try{$optCode = Azure\Stop-AzureVM -Name $TargetVMName -ServiceName $TargetServiceName -Force -ErrorAction Continue}
            catch{Write-Output "$(Get-Date -f $timeStampFormat) - FAILED to shutdown Virtual Machine $TargetVMName : $e"}
        }
		else
		{
           	Write-Output "$(Get-Date -f $timeStampFormat) - WARNING - Shutting Down Virtual Machine named $TargetVMName skipped - Instance not in the right state."
        }
    }
    else #Start VM
    {
        if($InstanceStatus -eq "StoppedVM" -or $InstanceStatus -eq "StoppedDeallocated")
        {
            #Start the Instance
            Write-Output "$(Get-Date -f $timeStampFormat) - Starting Virtual Machine named $targetVMName."
            try{$optCode = Azure\Start-AzureVM -Name $TargetVMName -ServiceName $TargetServiceName -ErrorAction Continue}
            catch{Write-Output "$(Get-Date -f $timeStampFormat) - FAILED to start Virtual Machine $TargetVMName : $e"}
		}
		else
		{
			Write-Output "$(Get-Date -f $timeStampFormat) - WARNING Starting Virtual Machine named $TargetVMName skipped - Instance was not in the right state."
		}
	}
}

function StartOrStop-VMs {
	[CmdletBinding()]
	Param(
	#Azure Subscription Name
	[Parameter(Mandatory = $true)]
	[String]$AzureSubscriptionName,

	#Azure Service
	[Parameter(Mandatory = $true)]
	[String]$TargetService,

	#Azure Service
	[Parameter(Mandatory = $false)]
	[String]$TargetVMList,

	#Requested Action (Start or Stop)
	[Parameter(Mandatory = $true)]
	[String]$RequestedAction
	)

	$timeStampFormat = "g"
		
	Write-Verbose "$(Get-Date -f $timeStampFormat) - $RequestedAction VMs script started."

	# select the subscription
	Azure\Select-AzureSubscription -SubscriptionName $AzureSubscriptionName

	Write-Verbose "$(Get-Date -f $timeStampFormat) - Signed-In into $AzureSubscriptionName."

	if($TargetVMList)
	{
    	Write-Verbose "$(Get-Date -f $timeStampFormat) - Target VMs specified: $TargetVMList"
		$targetVMs = $TargetVMList -Split','
    	foreach($targetVMName in $targetVMs)
    	{
        	# Get VM
        	$targetVM = Azure\Get-AzureVM -ServiceName $TargetService -Name $targetVMName

			# Process the VM
        	Process-VM -TargetServiceName $TargetService -TargetVMName $targetVM.InstanceName -InstanceStatus $targetVM.InstanceStatus -RequestedAction $RequestedAction
    	}
	}
	else
	{
    	Write-Verbose "$(Get-Date -f $timeStampFormat) - Reading all VMs in service: $TargetService"
    	# Get List of VMs in the service
    	$virtualMachines = Azure\Get-AzureVM -ServiceName $TargetService

    	foreach($targetVM in $virtualMachines)
    	{
			# Process the VM
			Process-VM -TargetServiceName $TargetService -TargetVMName $targetVM.InstanceName -InstanceStatus $targetVM.InstanceStatus -RequestedAction $RequestedAction
    	}
	}
}
