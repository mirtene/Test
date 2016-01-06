workflow StopEnvironment
{
	#Parameters
	Param (
			[parameter(Mandatory=$true)]
        	[String]$vnetResourceGroup	
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
	
	 # Get a list of Azure VMs
	$vmList = Get-AzureRmVM -ResourceGroupName $Using:vnetResourceGroup
    Write-Output "Number of Virtual Machines found in RG: [$($vmList.Count)] Name(s): [$($vmList.name)]"
	foreach -parallel($inlineVm in $vmList)
    {	
		InlineScript
		{
			$vm = $using:inlineVm		
		    # Stop all running VMs in ResourceGroup
	        $vmStatus = Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
		
           if($vmStatus.Statuses | where Code -match "PowerState/running") 
           {
                Write-Output "Stopping VM [$($vm.Name)]"
                $vm | Stop-AzureRmVM -Force
           }
           else 
		   {
                Write-Output "VM [$($vm.Name)] is already deallocated!"
           }
		}
	}          
	Write-Output "All Running VMs were stopped!"
}