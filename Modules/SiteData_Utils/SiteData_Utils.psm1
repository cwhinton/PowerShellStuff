
function get-siteDataWebApp {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]
        [string]$webAppURL
    )
    $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $webAppURL
    $script:sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
    $junk = " "
    $x = $script:sdProxy.GetContent("VirtualServer",$nil,$webAppURL,$ni,$true,$false,[ref]$junk)
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
#        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $webAppURL
#        $script:sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $script:sdProxy.URL = "{0}/_vti_bin/sitedata.asmx" -f $webAppURL
        $junk = " "
    }
    Process {
        $x = $script:sdProxy.GetContent("ContentDatabase",$contentDBID,$webAppURL,$ni,$true,$false,[ref]$junk)
        [xml]$x
    }
    end {
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
 #       $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $URL
 #       $script:sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $script:sdProxy.URL = "{0}/_vti_bin/sitedata.asmx" -f $URL
    }
    Process {
        $x = $script:sdProxy.GetContent("SiteCollection",$nil,$nil,$ni,$true,$false,[ref]$junk)
        [xml]$x
    }
    end {
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
#        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $URL
#        $script:sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $script:sdProxy.URL = "{0}/_vti_bin/sitedata.asmx" -f $URL
    }
    Process {
        $x = $script:sdProxy.GetContent("Site",$nil,$nil,$ni,$true,$false,[ref]$junk)
        [xml]$x
    }
    end {
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
#        $sdURL = "{0}/_vti_bin/sitedata.asmx" -f $URL
#        $script:sdProxy = New-WebServiceProxy -Uri $sdURL -UseDefaultCredential
        $script:sdProxy.URL = "{0}/_vti_bin/sitedata.asmx" -f $URL
    }
    Process {
        $x = $script:sdProxy.GetContent("List",$listID,$nil,$ni,$true,$false,[ref]$junk)
        [xml]$x
    }
    end {
    }
}
        
Export-ModuleMember -function "get-siteData*"
