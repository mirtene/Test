workflow EnvironmentDeployment
{ 
	#Parameters
		Param (
			[parameter(Mandatory=$true)]
        	[String]$ResourceGroup,
	
			[parameter(Mandatory=$true)]
			[String]$prefix,
        
        	[parameter(Mandatory=$true)]
        	[String]$adminPassword,

        	[parameter(Mandatory=$true)]
        	[Int]$GenAppServers,
        
        	[parameter(Mandatory=$true)]
        	[Int]$GenISServers
		)
	
	#Authenticate Runbook to Subscription
	Write-Output "Authenticating Runbook to Subscription.."
		$CredentialAssetName = 'CredentialAssetName'
		$Cred = GetAutomationPSCredential -Name $CredentialAssetName
		if(!$Cred) {
			Throw "Could not find an Automation Credential Asset named '$CredentialAssetName'. Make sure you have created one in this Automation Account."
		}

	#Connect to AzureRM Account
	Write-Output "Connecting to AzureRM Account.."
		$ARMAccount = Login-AzureRMAccount -Credential $Cred
		if(!$ARMAccount) {
			Throw "Could not authenticate AzureRM Account. Check username and password."
		}
	
	#If Resource Group does not exist - Create Resource Group	
		$RG = Get-AzureRMResourceGroup | where -$ResourceGroupName -eq $ResourceGroup
			if(!$RG) {
				Write-Output "Creating Resource Group '$ResourceGroup'.."
				New-AzureRMResourceGroup -Name $ResourceGroup -Location "West Europe" -Force
				}
			else {
				Throw "Resource Group already exist!" ### Virker ikke som ønsket
			}

	$templateUri = "https://meriksstorage.blob.core.windows.net/public/InvoicingExample2.json"
	$useUrl = (Get-AutomationVariable -Name "regUrl").ToString()
	$useKey = (Get-AutomationVariable -Name "regKey").ToString()
	
	$params= @{
            prefix = $prefix 
			adminPassword = $adminPassword 
			GENAppServerCount = $GenAppServers 
			GENISServerCount = $GenISServers 
            registrationKey = $useKey 
            registrationUrl = $useUrl
     }
	
	Write-Output "Creating Genapp and GenIS Virtual Machines.."
	New-AzureRMResourceGroupDeployment -Name $prefix -ResourceGroupName $ResourceGroup -TemplateUri $templateUri -TemplateParameterObject $params
	Write-Output "Environment Deployed!"

}