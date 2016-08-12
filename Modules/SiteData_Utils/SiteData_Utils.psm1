function get-siteDataWebApp {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]
        [string]$webAppURL
    )
    $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $webAppURL
    $sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
    $junk = " "
    $x = $sdProxy.GetContent("VirtualServer",$nil,$webAppURL,$ni,$true,$false,[ref]$junk)
    $sdProxy.Dispose()
    [xml]$x
}

function get-siteDataContentDB {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        [string]$contentDBID,

        [parameter(Mandatory=$true)]
        [string]$webAppURL

    )
    begin {
        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $webAppURL
        $sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $junk = " "
    }
    Process {
        [xml]($sdProxy.GetContent("ContentDatabase",$contentDBID,$webAppURL,$ni,$true,$false,[ref]$junk))
    }
    end {
        $sdProxy.Dispose()
    }
}

function get-siteDataSiteCollection {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$URL
    )
    begin {
        $junk = " "
        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $URL
        $sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $sdProxy.URL = $sdURL
    }
    Process {
        [xml]($sdProxy.GetContent("SiteCollection",$nil,$nil,$ni,$true,$false,[ref]$junk))
    }
    end {
        $sdProxy.Dispose()
    }
        
}

function get-siteDataSite {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$URL
    )
    begin {
        $junk = " "
        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $URL
        $sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $sdProxy.URL = $sdURL
    }
    Process {
        [xml]($sdProxy.GetContent("Site",$nil,$nil,$ni,$true,$false,[ref]$junk))
    }
    end {
        $sdProxy.Dispose()
    }
}

function get-siteDataList {
    [cmdletbinding()]
    param(
        [parameter(Manadatory=$true)]
        [string]$URL,

        [parameter(Manadatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$listID
    )
    begin {
        $junk = " "
        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $URL
        $sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $sdProxy.URL = $sdURL
    }
    Process {
        [xml]($sdProxy.GetContent("List",$listID,$nil,$ni,$true,$false,[ref]$junk))
    }
    end {
        $sdProxy.Dispose()
    }
}
        
Export-ModuleMember -function "get-siteData*"
