workflow start
{
	
    Param 
    ( 
        	[parameter(Mandatory=$true)]
        	[String]$vnetResourceGroup
		
    ) 
        
    $currentTime = (Get-Date).ToUniversalTime() 
    Write-Output "Runbook started" 
    Write-Output "Current UTC/GMT time [$($currentTime.ToString("dddd, yyyy MMM dd HH:mm:ss"))] will be checked against schedules" 
     
    # Retrieve credential name from variable asset 
	$CredentialAssetName = 'CredentialAsset'
        $Cred = Get-AutomationPSCredential -Name $CredentialAssetName 
        if($Cred -eq $null) 
        { 
            Write-Output "ERROR: Failed to get credential with name [$CredentialAssetName]" 
            Write-Output "Exiting runbook due to error" 
            return 
        } 
     
 
    # Connect to Azure using credential asset 
    $addAccountResult = Login-AzureRmAccount -Credential $Cred  
    Write-Output "Authentication result:" 
    Write-Output $addAccountResult 
     
 
 
 
 
    # Validate subscription 
    #$targetSubscriptionId = "554269c5-41f7-49ad-9bdd-563a22ca3f5c"
    #$targetSubscriptionName = "Visual Studio Enterprise med MSDN"     
     
	 # Connect to Azure using credential asset
    $errorCollection = New-Object -Type System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]
    $addAccountResult = Add-AzureAccount -Credential $Cred 2>&1
    Write-Output "Authentication result:"
    Write-Output $addAccountResult
    


    # Retrieve subscription name from variable asset if not specified
    if($AzureSubscriptionName -eq "Use *Default Azure Subscription* Variable Value")
    {
        $AzureSubscriptionName = Get-AutomationVariable -Name "Default Azure Subscription"
        if($AzureSubscriptionName.length -eq 0)
        {
            Write-Output "ERROR: No subscription name was specified, and no variable asset with name 'Default Azure Subscription' was found. Either specify an Azure subscription name or define the default using a variable setting"
            Write-Output "Exiting runbook due to error"
            return
        }
    }

    # Validate subscription
    $targetSubscriptionId = InlineScript 
    {
        $subscriptions = Get-AzureSubscription
        $subscription = $subscriptions | where {$_.SubscriptionName -eq $Using:AzureSubscriptionName -or $_.SubscriptionId -eq $Using:AzureSubscriptionName}
        
        if($subscription.Count -eq 1)
        {
            # Return the matching subscription Id
            $subscription.SubscriptionId
        }
        else
        {
            if($subscription.Count -eq 0)
            {
                Write-Output "ERROR: No accessible subscription found with name or ID [$Using:AzureSubscriptionName]. Check the runbook parameters and ensure user is a co-administrator on the target subscription."
            }
            else
            {
                Write-Output "ERROR: More than one accessible subscription found with name or ID [$Using:AzureSubscriptionName]. Please ensure your subscription names are unique, or specify ID instead"
            }
        }
    }
    
    # Exit if an error message returned instead of ID
    if($targetSubscriptionId -like "*ERROR*")
    {
        Write-Output $targetSubscriptionId
        Write-Output "Exiting runbook due to error"
        return
    }
    
    # Select the Azure subscription we will be working against
    $subscriptionResult = Select-AzureSubscription -SubscriptionId $targetSubscriptionId
    $currentSubscription = Get-AzureSubscription -Current
    Write-Output "Targeting subscription [$($currentSubscription.SubscriptionName)] ($targetSubscriptionId)"
	 
	 
    # Select the Azure subscription we will be working against 
    #$subscriptionResult = Select-AzureSubscription -SubscriptionName $targetSubscriptionName -SubscriptionId $targetSubscriptionId 
    #$currentSubscription = Get-AzureRmSubscription -SubscriptionName $targetSubscriptionName -SubscriptionId $targetSubscriptionId
    #Write-Output "Targeting subscription [$($currentSubscription.SubscriptionName)] ($targetSubscriptionId)" 
   
     
    InlineScript
        {
                # Define function to check current time against specified range
            function CheckScheduleEntry ([string]$TimeRange)
            {  
                # Initialize variables
                $rangeStart, $rangeEnd, $parsedDay = $null
                $currentTime = (Get-Date).ToUniversalTime()
            $midnight = $currentTime.AddDays(1).Date           
 
                try
                {
                    # Parse as range if contains '->'
                    if($TimeRange -like "*->*")
                    {
                        $timeRangeComponents = $TimeRange -split "->" | foreach {$_.Trim()}
                        if($timeRangeComponents.Count -eq 2)
                        {
                            $rangeStart = Get-Date $timeRangeComponents[0]
                            $rangeEnd = Get-Date $timeRangeComponents[1]
       
                            # Check for crossing midnight
                            if($rangeStart -gt $rangeEnd)
                            {
                            # If current time is between the start of range and midnight tonight, interpret start time as earlier today and end time as tomorrow
                            if($currentTime -ge $rangeStart -and $currentTime -lt $midnight)
                            {
                                $rangeEnd = $rangeEnd.AddDays(1)
                            }
                            # Otherwise interpret start time as yesterday and end time as today  
                            else
                            {
                                $rangeStart = $rangeStart.AddDays(-1)
                            }
                            }
                        }
                        else
                        {
                            Write-Error "`tWARNING: Invalid time range format. Expects valid .Net DateTime-formatted start time and end time separated by '->'"
                        }
                    }
                    # Otherwise attempt to parse as a full day entry, e.g. 'Monday' or 'December 25'
                    else
                    {
                        # If specified as day of week, check if today
                        if([System.DayOfWeek].GetEnumValues() -contains $TimeRange)
                        {
                            if($TimeRange -eq (Get-Date).DayOfWeek)
                            {
                                $parsedDay = Get-Date "00:00"
                            }
                            else
                            {
                                # Skip detected day of week that isn't today
                            }
                        }
                        # Otherwise attempt to parse as a date, e.g. 'December 25'
                        else
                        {
                            $parsedDay = Get-Date $TimeRange
                        }
           
                        if($parsedDay -ne $null)
                        {
                            $rangeStart = $parsedDay # Defaults to midnight
                            $rangeEnd = $parsedDay.AddHours(23).AddMinutes(59).AddSeconds(59) # End of the same day
                        }
                    }
                }
                catch
                {
                    # Record any errors and return false by default
                    Write-Error "`tWARNING: Exception encountered while parsing time range. Details: $($_.Exception.Message). Check the syntax of entry, e.g. '<StartTime> -> <EndTime>', or days/dates like 'Sunday' and 'December 25'"  
                    return $false
                }
       
                # Check if current time falls within range
                if($currentTime -ge $rangeStart -and $currentTime -le $rangeEnd)
                {
                    return $true
                }
                else
                {
                    return $false
                }
       
            } # End function CheckScheduleEntry
         
        # Get resource groups that are tagged for automatic shutdown of resources 
      
        #$taggedResourceGroup = Get-AzureRmResourceGroup -Name $vnetResourceGroup
         
    	$taggedResourceGroups = @()  
        $taggedResourceGroups +=  Get-AzureRmResourceGroup | where {$_.Tags.Count -gt 0 -and $_.Tags.Name -contains "AutoShutdownSchedule"} 
         
                # Process each group, building a table of desired VM state
                $targetVMState = @{}
                foreach($group in $taggedResourceGroups)
                {
                        # Get the shutdown time ranges definition tag and extract the value
                    $shutdownTag =  $group.Tags | where Name -eq "AutoShutdownSchedule"
                    $shutdownTimeRangesDefinition = $shutdownTag.Value
                   
                    Write-Output "Found resource group [$($group.ResourceGroupName)] with 'AutoShutdownSchedule' tag with value [$shutdownTimeRangesDefinition]. Checking schedules..."
               
                    # Parse the ranges in the Tag value. Expects a string of comma-separated time ranges, or a single time range
                    $timeRangeList = @()
                    $timeRangeList += $shutdownTimeRangesDefinition -split "," | foreach {$_.Trim()}
               
                    # Check each range against the current time to see if any schedule is matched
                    $scheduleMatched = $false
                    foreach($entry in $timeRangeList)
                    {
                        if((CheckScheduleEntry -TimeRange $entry) -eq $true)
                        {
                            $scheduleMatched = $true
                            break
                        }
                    }
					
                    # Record desired state for group resources based on result. If schedule is matched, shut down the VM if it is running. Otherwise start the VM if stopped.
                    if($scheduleMatched)
                    {
                        Write-Output "Current time falls within the range [$entry]"
                       
                        # Set target state as stopped
                        $targetState = "deallocated"
                    }
                    else
                    {
                        Write-Output "Current time is outside of all shutdown schedule ranges for resource group [$($group.ResourceGroupName)]"
                       
                        # Set target state as stopped
                        $targetState = "starting"
                    }
               
                    # Get VM resources in group and record target state for each in table
                    $taggedVMs = $group | Get-AzureRmVM
                    foreach($vmResource in $taggedVMs)
                    {
                        $targetVMState.Add($vmResource.Name, $targetState)
					
                    }
					
                }
               
                Write-Output "Checking all virtual machines for desired power state"
               
         
        # Get list of Azure VMs 
        $vmList = Get-AzureRmVM 
        Write-Output "Number of Virtual Machines found in subscription: [$($vmList.Count)]" 
         
        # Ensure each of the VMs is in the desired state 
        foreach($entry in $targetVMState.GetEnumerator()) 
        {     
            # Get the VM matching this configuration entry 
            $vm =  $vmList | where Name -eq $entry.Name 
         
            # Check for unmatched name case 
            if($vm.Count -eq 0) 
            { 
                Write-Output "WARNING: No virtual machine found with name from resource [$($entry.Name)]" 
                continue 
            } 
         
            # Check for duplicate name case 
            if($vm.Count -gt 1) 
            { 
                Write-Output "WARNING: More than one virtual machine found with name [$($entry.Name)]. Please ensure all VM names are unique in subscription. Skipping these VMs." 
                continue 
            } 
         
            # If should be started and isn't, start VM 
            if($entry.Value -eq "starting" -and $vm.Statuses | where Code -ne "PowerState/running") 
            { 
                Write-Output "Starting VM [$($entry.Name)]" 
                $vm | Start-AzureRmVM 
            } 
         
            # If should be stopped and isn't, stop VM 
            if($entry.Value -eq "deallocated" -and $vm.Statuses | where Code -ne "PowerState/deallocated") 
            { 
                Write-Output "Stopping VM [$($entry.Name)]" 
                $vm | Stop-AzureRmVM -Force 
            } 
        } 
         
        Write-Output "All VMs configured for correct power state based on current time" 
    } 
       
    Write-Output "Runbook completed" 
     
    # End of runbook 
}