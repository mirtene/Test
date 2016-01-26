workflow EnvironmentDeployment
{ 
	#Parameters
		Param (
			[parameter(Mandatory=$true)]
        	[String]$vnetResourceGroup,
	
			[parameter(Mandatory=$true)]
			[String]$prefix,
        
        	[parameter(Mandatory=$true)]
        	[String]$adminPassword,

        	[parameter(Mandatory=$true)]
        	[Int]$GenAppServerCount,
        
        	[parameter(Mandatory=$true)]
        	[Int]$GenISServerCount
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
		$RG = Get-AzureRMResourceGroup | where -$ResourceGroupName -eq $vnetResourceGroup
			if(!$RG) {
				Write-Output "Creating Resource Group '$vnetResourceGroup'.."
				New-AzureRMResourceGroup -Name $vnetResourceGroup -Location "West Europe" -Force
				}
			else {
				Throw "Resource Group already exist!" ### Virker ikke som ønsket
			}
   
		$VMAdminPassword = $adminPassword | ConvertTo-SecureString -AsPlainText -Force	


        $automationAccount = 'Automation1'
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
			-ResourceGroupName $vnetResourceGroup `
			-TemplateUri "https://meriksstorage.blob.core.windows.net/public/InvoicingExample2.json" `
			-prefix $prefix `
			-adminPassword $VMAdminPassword `
			-GENAppServerCount $GenAppServerCount `
			-GENISServerCount $GenISServerCount `
            -registrationKey $useKey `
            -registrationUrl $useUrl
	
		Write-Output "Environment Deployed!"

}