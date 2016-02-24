workflow CreateUniqueVMReports
{
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
	                    width: 950px;
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
	    $a += "</style>"
	    #table headers
	    $b = ""
	    $b += "<tr>"
        $b += "<th>Resource Group</th>"
	    $b += "<th>Server Name</th>"
	    $b += "<th>VM Size</th>"
	    $b += "<th>IP Address</th>"
	    $b += "</tr>"

	  
	  InlineScript
	  {
		    #Function: Report
            function Report($rgName)
	    	{                                                                                                                                                                                                                                 
                $vmList = Get-AzureRmVM -ResourceGroupName $rgName

		        foreach($vm in $vmList)
	            {
				    $hardware = $vm.HardwareProfile.vmSize
		  	        $NIC = Get-AzureRmNetworkInterface –name "$($vm.Name)NIC" –ResourceGroupName $rgName
			        $IP = $NIC.IpConfigurations[0].PrivateIpAddress
	
	                if ($html.Contains($rgName))
		            {
		                $Script:html += ("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td></tr>" -f "",$vm.Name,$hardware,$IP)
		            }
		            else
		            {
	                    $Script:html += ("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td></tr>" -f $rgName,$vm.Name,$hardware,$IP) 
		            }    
			    }
	        }#End Function: Report 
		
        #for each RG: call "Report" function, create HTML report file for this RG and push to webapp 
       
	   	$WebAppCredName = Get-AutomationPSCredential -Name 'WebAppCredential'
		$WebAppPath = Get-AutomationVariable -Name 'WebAppFileLocation'
	   
	    $getRGs = Get-AzureRmResourceGroup | select ResourceGroupName 
        foreach($rg in $getRGs)
	    {	
            $rgName = $rg.ResourceGroupName
			$htmlFileName = "$($rgName).html"
       	 	$WebAppFileLocation = "$($WebAppPath)$($htmlFileName)"
			$reportTime = Get-Date
			
            if ($rgName -like "test*"){
                $html = ""
                #call function with RG Name as input
				Report $rgName
            
                #fillHTML
                $html = "<html><head>" + $Using:a + "</head><table>" + $Using:b + $html + "</table>" +"Time Stamp: " + $reportTime + "</html>"
                    
                #generateHTMLfile in tempStorage
                New-Item -Path $htmlFileName -Value $html -ItemType File -Force 

                # Create FTP Rquest Object
                $FTPRequest = [System.Net.FtpWebRequest]::Create("$WebAppFileLocation")
                $FTPRequest = [System.Net.FtpWebRequest]$FTPRequest
                $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
                $FTPRequest.Credentials = new-object System.Net.NetworkCredential($WebAppCredName.Username , $WebAppCredName.Password)
                $FTPRequest.UseBinary = $true
                $FTPRequest.UsePassive = $true
                # Read the File for Upload
                $FileContent = gc -en byte $htmlFileName
                $FTPRequest.ContentLength = $FileContent.Length
                # Get Stream Request by bytes
                $Run = $FTPRequest.GetRequestStream()
                $Run.Write($FileContent, 0, $FileContent.Length)
                # Cleanup
                $Run.Close()
                $Run.Dispose()
				Write-Output "$($htmlFileName).html has been transfered to Azure WebApp!"
            }    
      	}             
	}#end InlineScript
}#end runbook