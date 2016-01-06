workflow Schedule
{
   # Param 
   # ( 
   #     	[parameter(Mandatory=$true)]
   #     	[String]$vnetResourceGroup
   # ) 
        
    $currentTime = (Get-Date).ToUniversalTime() 
    Write-Output "Runbook started" 
    Write-Output "Current UTC/GMT time [$($currentTime.ToString("dddd, yyyy MMM dd HH:mm:ss"))] will be checked against schedules" 
     
    # Retrieve credential name from variable asset 
	$CredentialAssetName = 'CredentialAssetName'
    $Cred = Get-AutomationPSCredential -Name $CredentialAssetName 
    if($Cred -eq $null) 
    { 
        Write-Output "ERROR: Failed to get credential with name [$CredentialAssetName]" 
        Write-Output "Exiting runbook due to error" 
        return 
    } 
     
 
    # Connect to Azure using credential asset 
    $addAccount = Login-AzureRmAccount -Credential $Cred  

    # Validate subscription 
    #$targetSubscriptionId = "554269c5-41f7-49ad-9bdd-563a22ca3f5c"
    #$targetSubscriptionName = "Visual Studio Enterprise med MSDN"     
         
     
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
			}
            # End function CheckScheduleEntry
         
        # Get resource groups that are tagged for automatic shutdown of resources  
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
        $vmList = Get-AzureRmVM #-ResourceGroupName $group.ResourceGroupName -Name $taggedVMs.Name -Status
        Write-Output "Virtual Machines found in subscription: [$($vmList.Name)]"
        # Ensure each of the VMs is in the desired state 
        foreach($entry in $targetVMState.GetEnumerator()) 
        {    
			
            # Get the VM matching this configuration entry 
            $vm =  Get-AzureRmVM -ResourceGroupName $group.ResourceGroupName -Name $entry.Name -Status # where Name -match $entry.Name 
        
            # If should be started and isn't, start VM 
            if($entry.Value -match "starting" -and $vm.Statuses | where Code -match "PowerState/deallocated") 
            { 
                Write-Output "Starting VM [$($entry.Name)]" 
                $vm | Start-AzureRmVM 
            } 
       
            # If should be stopped and isn't, stop VM 
            if($entry.Value -match "deallocated" -and $vm.Statuses | where Code -match "PowerState/running") 
            { 
                Write-Output "Stopping VM [$($entry.Name)]" 
                $vm | Stop-AzureRmVM -Force 
            }
        } 
    }     
    Write-Output "All VMs configured for correct power state based on current time" 
}
