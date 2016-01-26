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
   
		$VMAdminPassword = $adminPassword | ConvertTo-SecureString -AsPlainText -Force	


        $automationAccount = 'EnvironmentDeployment'
		$RGName	= 'Eriksen'
	    $key = 'registrationKey'
		$getKey = Get-AzureRMAutomationVariable -ResourceGroupName $RGName -AutomationAccountName $automationAccount -Name $key
		$useKey = $getkey.Value | ConvertTo-SecureString -AsPlainText -Force
		Write-Output "$useKey-----"	
		
		$url = 'registrationUrl'
		$getUrl = Get-AzureRMAutomationVariable -ResourceGroupName $RGName -AutomationAccountName $automationAccount -Name $url
		$useUrl = $getUrl.Value 
	
		
		Write-Output "Creating Genapp and GenIS Virtual Machines.."
	
		New-AzureRMResourceGroupDeployment `
			-Name "Deployment" `
			-ResourceGroupName $ResourceGroup `
			-TemplateUri "https://meriksstorage.blob.core.windows.net/public/InvoicingExample2.json" `
			-prefix $prefix `
			-adminPassword $VMAdminPassword `
			-GENAppServerCount $GenAppServers `
			-GENISServerCount $GenISServers `
            -registrationKey $useKey `
            -registrationUrl $useUrl
	
		Write-Output "Environment Deployed!"

}