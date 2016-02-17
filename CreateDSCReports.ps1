workflow CreateDSCReports
{
	   param 
        ( 
            [Parameter (Mandatory=$true)]             
            [String] 
            $AutomationAccountName = "EnviromentAutomation",
 
            [Parameter (Mandatory=$true)]             
            [String] 
            $ResourceGroupName = "Eriksen"
        ) 

 		#Authenticate Runbook to Subscription
		Write-Output "Authenticating Runbook to Azure Subscription"
		$CredentialAssetName = 'CredentialAssetName'
		$Cred = GetAutomationPSCredential -Name $CredentialAssetName
		if(!$Cred) {
			Throw "Could not find an Automation Credential Asset named '$CredentialAssetName'. Make sure you have created one in this Automation Account."
		}

		#Connect to AzureRM Account
		Write-Output "Connecting to AzureRM Account"
		$ARMAccount = Login-AzureRMAccount -Credential $Cred
    
	 	#define HTML 
	    $a = "<style>"
	    $a += "body {
	              background: #fafafa url(http://jackrugile.com/images/misc/noise-diagonal.png);
	              color: #444;
	              font: 100%/30px 'Helvetica Neue', helvetica, arial, sans-serif;
	              text-shadow: 0 1px 0 #fff;
	            }"
	    $a += "strong {
	                font-weight: bold;
	            }"
	    $a += "table {
	                    background: #f5f5f5;
	                    border-collapse: separate;
	                    box-shadow: inset 0 1px 0 #fff;
	                    font-size: 12px;
	                    line-height: 24px;
	                    margin: 30px auto;
	                    text-align: left;
	                    width: 1300px;
	                }"
	    $a += "th {
	                  background: url(http://jackrugile.com/images/misc/noise-diagonal.png), linear-gradient(#777, #444);
	                  border-left: 1px solid #555;
	                  border-right: 1px solid #777;
	                  border-top: 1px solid #555;
	                  border-bottom: 1px solid #333;
	                  box-shadow: inset 0 1px 0 #999;
	                  color: #fff;
	                  font-weight: bold;
	                  padding: 10px 15px;
	                  position: relative;
	                  text-shadow: 0 1px 0 #000;
	                }"
	    $a += "th:after {
	                  background: linear-gradient(rgba(255, 255, 255, 0), rgba(255, 255, 255, .08));
	                  content: '';
	                  display: block;
	                  height: 25%;
	                  left: 0;
	                  margin: 1px 0 0 0;
	                  position: absolute;
	                  top: 25%;
	                  width: 100%;
	                }"
	    $a += "th:first-child {
	                    border-left: 1px solid #777;
	                    box-shadow: inset 1px 1px 0 #999;
	                }"
	    $a += "th:last-child {
	                  box-shadow: inset -1px 1px 0 #999;
	                }"
	    $a += "td {
	                  border-right: 1px solid #fff;
	                  border-left: 1px solid #e8e8e8;
	                  border-top: 1px solid #fff;
	                  border-bottom: 1px solid #e8e8e8;
	                  padding: 10px 15px;
	                  position: relative;
	                  transition: all 300ms;
	                }"
	   $a += "tr#COMPLIANT { 
	                 
	                  color: green;  
	                }"
	    $a += "tr#NOTCOMPLIANT { 
	                
	                  color: red;   
	                }"
	    $a += "</style>"
	    
	    #table headers
	    $b = ""
	    $b += "<tr>"
	    $b += "<th>Role</th>"
	    $b += "<th>Node Name</th>"
	    $b += "<th>Resource Group</th>"
	    $b += "<th>Node Status</th>"
	    $b += "<th>Last Status Update</th>"
	    $b += "<th>Information</th>"
	    $b += "</tr>"

	  #FUNCTION: Report
	  InlineScript
	    {
			$AutomationAccountName = "EnviromentAutomation"
	        $ResourceGroupName = "Eriksen"
			
			function Report 
	    	{                                                                                                                                                                                                                                 

				$allVMs = @()
		        $getRGs = Get-AzureRmResourceGroup | select ResourceGroupName
		
		        foreach($rg in $getRGs)
		        {
		            $rgName = $rg.ResourceGroupName
		            $vmInfo = Get-AzureRmVM -ResourceGroupName $rgName
		            foreach($vm in $vmInfo)
		            {
		                $allVMs += [pscustomobject]@{ResourceGroup=$rgName;Servername=$vm.Name} 
		            }
		        }
		
		        #Get DSC nodes in automation account and their latest status 
		        $nodeList = Get-AzureRmAutomationDscNode -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName 
			    $getNodeName = $nodeList.Name
		    
		        #loop nodenames in order to generate reports and obtain "health check"
		        foreach ($nodeName in $getNodeName)
		        {    	
		            $getNodeInfo = Get-AzureRmAutomationDscNode -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $nodeName 
		            $getNodeStatus = $getNodeInfo.Status
		            $getNodeConfigName = $getNodeInfo.NodeConfigurationName
		            
		            #get nodes and export reports for each node	
		            $report = Get-AzureRmAutomationDscNodeReport -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -NodeId $getNodeInfo.Id -Latest 
		           
					
					$tempPath = [System.IO.Path]::GetTempPath()
		            $expReport = Export-AzureRmAutomationDscNodeReportContent -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -NodeId $getNodeInfo.Id -ReportId $report.Id -OutputFolder $tempPath -Force
		            
		            #get content from each node report and output compliance info to object      
		            $fileName = "$($report.NodeId)_$($report.Id).txt"
					$lines = Get-Content "$tempPath\$fileName"
		            $lines | ForEach-Object {
		                $json = ConvertFrom-Json $_
		                 
		                    if($json.ConfigurationVersion)
		                    {
		                        $getFullTime = $json.EndTime  
		                        $getReportTime = $getFullTime.Substring(0,19)
		                        $statusData = $json.StatusData | ConvertFrom-Json
		                                               
	                        foreach($status in $statusData.ResourcesInDesiredState)
	                        {
	                                $compliantNodeInfo = $status.ResourceId
	                                $vmResourceGroupName = ($allVMs | where Servername -eq $nodeName).ResourceGroup
	                                if ($html.Contains($nodeName))
	                                {
	                                    $Script:html += ("<tr ID={6}><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td><ul><li><span>{5}</span></li></ul></td></tr>" -f "","","","","",$compliantNodeInfo,"COMPLIANT")
	                                }
	                                else
	                                {
	                                    $Script:html += ("<tr ID={6}><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td><ul><li><span>{5}</span></li></ul></td></tr>" -f $getNodeConfigName,$nodeName,$vmResourceGroupName,$getNodeStatus,$getReportTime,$compliantNodeInfo,"COMPLIANT")
	                                }    
	                        }
	                        foreach($status in $statusData.ResourcesNotInDesiredState)
	                        {
                                $notCompliantNodeInfo = $status.ResourceId
                                $vmResourceGroupName = ($allVMs | where Servername -eq $nodeName).ResourceGroup
                                if ($html.Contains($nodeName))
                                {
                                    $Script:html += ("<tr ID={6}><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td><ul><li><span>{5}</span></li></td></tr>" -f "","","","","",$notCompliantNodeInfo,"NOTCOMPLIANT")
                                }
                                else
                                {
                                	$Script:html += ("<tr ID={6}><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td><ul><li><span>{5}</span></li></ul></td></tr>" -f $getNodeConfigName,$nodeName,$vmResourceGroupName,$getNodeStatus,$getReportTime,$notCompliantNodeInfo,"NOTCOMPLIANT")
	                            }    
		                        }      
		                    }
		                }
			        }  
				}# end function 
    #report variables
    $reportTime = Get-Date
    $StorageAccountName = "meriksstorage"
    $ContainerName = "html"
    $BlobName = "DSCReports.html" 
    $htmlFileName = "DSCReports.html" 
    
    #connect to azure storage blob and create a context 
    $Account = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction:Stop
    $StorageAccountKey = ($Account | Get-AzureRmStorageAccountKey).Key1
    $Context  = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey


    #main: html report
    $html = ""
    Report 

    #createHTMLinput
    $html = "<html><head>" + $Using:a + "</head><table>" + $Using:b + $html + "</table>" +"Time Stamp: " + $reportTime + "</html>"
    #generateHTMLfile
    New-Item -Path $htmlFileName -Value $html -ItemType File -Force 

    # Upload the file contents  to Azure Storage
    Set-AzureStorageBlobContent -Blob $BlobName -Container $ContainerName -File $htmlFileName -BlobType Block -Context $Context -Force
        

        # Config
        $Username = "dscreportstellier\vmreportscred"
        $Password = "@zur3@dm1n"
        $LocalFile = $htmlFileName 
        $RemoteFile = "ftp://waws-prod-am2-053.ftp.azurewebsites.windows.net/site/wwwroot/hostingstart.html"

		# Create FTP Rquest Object
		$FTPRequest = [System.Net.FtpWebRequest]::Create("$RemoteFile")
		$FTPRequest = [System.Net.FtpWebRequest]$FTPRequest
		$FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
		$FTPRequest.Credentials = new-object System.Net.NetworkCredential($Username, $Password)
		$FTPRequest.UseBinary = $true
		$FTPRequest.UsePassive = $true
		# Read the File for Upload
		$FileContent = gc -en byte $LocalFile
		$FTPRequest.ContentLength = $FileContent.Length
		# Get Stream Request by bytes
		$Run = $FTPRequest.GetRequestStream()
		$Run.Write($FileContent, 0, $FileContent.Length)
		# Cleanup
		$Run.Close()
		$Run.Dispose()

     

}#end InlineScript
 
	
}#end Runbook