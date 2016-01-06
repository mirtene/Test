workflow DeleteRG
{
	Param
	(
		[parameter(Mandatory=$true)]
        [String]$vnetResourceGroup
	)
	
		#Authenticate Runbook to Subscription
	Write-Output "Authenticating Runbook to Subscription.."
		$CredentialAssetName = 'CredentialAsset'
		$Cred = GetAutomationPSCredential -Name $CredentialAssetName
		if(!$Cred) 
		{
			Throw "Could not find an Automation Credential Asset named '$CredentialAssetName'. Make sure you have created one in this Automation Account."
		}

	#Connect to AzureRM Account
	Write-Output "Connecting to AzureRM Account.."
		$ARMAccount = Login-AzureRMAccount -Credential $Cred
		if(!$ARMAccount) 
		{
			Throw "Could not authenticate AzureRM Account. Check username and password."
		}
	
	#Delete Resource Group	
	Write-Output "Deleting Resource Group '$vnetResourceGroup'.."
		Remove-AzureRMResourceGroup -Name $vnetResourceGroup -Force
	Write-Output "Deleted Resource Group '$vnetResourceGroup'.."
}