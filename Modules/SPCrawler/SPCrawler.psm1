import-module SiteData_Utils
import-module poshrsjob
import-module adolib

function getSQLConnection {
    New-Connection -server '(LocalDb)\MSSQLLocalDB' -database 'SDDisco'
}

function start-webappDiscovery {
    [cmdletbinding()]
    param (
        [string]$webAppURL
    )
    $script:DiscoID = invoke-webappDiscovery -webAppURL $webAppURL
    push-discoveredURL -url $webAppURL -discoveryID $script:DiscoID -urlType 'WebApp' -parentURLID ([System.DBNull]::Value)
    search-DiscoveryQueue -discoveryID $script:DiscoID
    complete-webappDiscovery -discoveryID $script:DiscoID
}

function search-DiscoveryQueue {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $discoveryID
    )

    do {
        $sqlConn = getSQLConnection
        $tsql = 'select top 100 DQ_ID, DQ_DCID,DQ_URL,DQ_URLType,DQ_ListID from DiscoveryQueue where DQ_Crawled = 0 and DQ_DCID =@DQ_DCID'
        $crawlQueue = invoke-query -sql $tsql -connection $sqlConn -parameters @{DQ_DCID=$discoveryID}
        $sqlConn.close()
        $crawlQueue | import-discoveredURL | pop-discoveredURL
    } until ($crawlQueue.count -eq 0)
} 


function import-discoveredURL {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $discovery
    )
    begin {
        $sqlConn = getSQLConnection
    }
    process {
        switch ($discovery.DQ_URLType) {
            'WebApp' {discover-SiteCollections $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'SiteCollection' { discover-SiteCollectionContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'Site' { discover-SiteContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'List' {}
        }
        $discovery.DQ_ID
    }
    end {
        $sqlConn.close()
    }
}

function invoke-webappDiscovery {
    [cmdletbinding()]
    param (
        [string]$webAppURL
    )

    begin {
        $sqlConn = getSQLConnection
    }
    process {
        $tsql = 'insert into DiscoveryCrawls(DC_StartDT,DC_URL) values (getdate(),@DC_URL);select scope_identity() scope_identity'
        $x = Invoke-Query -sql $tsql -connection $sqlConn -parameters @{dc_URL=$webAppURL}
        $x.scope_identity
    }
    end {
        $sqlConn.close()
    }
}

function complete-webappDiscovery {
    [cmdletbinding()]
    param (
        $discoveryID
    )

    begin {
        $sqlConn = getSQLConnection
    }
    process {
        $tsql = 'update DiscoveryCrawls set DC_EndDt = getdate() where dc_id = @discoveryID'
        $x = Invoke-sql -sql $tsql -connection $sqlConn -parameters @{discoveryID=$discoveryID}
    }
    end {
        $sqlConn.close()
    }
}

function push-discoveredURL {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        [string]$url,
        $discoveryID,
        [string]$urlType,
        $parentURLID
    )
    begin {
        $sqlConn = getSQLConnection
        $sqlTran = $sqlConn.beginTransaction()
    }
    process {
        $tsql = 'insert into DiscoveryQueue(DQ_ParentID,DQ_DCID,DQ_URL,DQ_URLType) values (@DQ_ParentID,@DQ_DCID,@DQ_URL,@DQ_URLType)'
        $result = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran `
            -parameters @{DQ_ParentID=$parentURLID;DQ_DCID=$discoveryID;DQ_URL=$url;DQ_URLType=$urlType}
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
    }
}

function push-discoveredList {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $ListID,
        [string]$url,
        $discoveryID,
        [string]$urlType,
        $parentURLID
    )
    begin {
        $sqlConn = getSQLConnection
        $sqlTran = $sqlConn.beginTransaction()
    }
    process {
        $tsql = 'insert into DiscoveryQueue(DQ_ParentID,DQ_DCID,DQ_URL,DQ_URLType,DQ_ListID) values (@DQ_ParentID,@DQ_DCID,@DQ_URL,@DQ_URLType,@DQ_ListID)'
        $result = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran `
            -parameters @{DQ_ParentID=$parentURLID;DQ_DCID=$discoveryID;DQ_URL=$url;DQ_URLType=$urlType;DQ_ListID=$ListID}
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
    }
}

function pop-discoveredURL {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $URLID
    )
    begin {
        $sqlConn = getSQLConnection
        $sqlTran = $sqlConn.beginTransaction()
    }
    process {
        $tsql = 'update DiscoveryQueue set DQ_Crawled = 1 where DQ_ID = @DQ_ID'
        $result = invoke-sql -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{DQ_ID=$URLID}
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
    }
}
    

function discover-SiteCollections {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID
    )

    $wa = get-siteDataWebApp -webAppURL $webAppURL

    save-WebApp -webAppSDXML $wa -discoveryQueueID $parentURLID

    $siteCollections = $wa.VirtualServer.ContentDatabases.ContentDatabase | 
        select -ExpandProperty ID  | 
        get-siteDataContentDB -webAppURL $webAppURL
    
    $siteCollections | 
        foreach {
            $_.ContentDatabase.Sites.Site | select -ExpandProperty URL
        } | 
        push-discoveredURL -discoveryID $discoID -urlType 'SiteCollection' -parentURLID $parentURLID

    $siteCollections | 
        Save-SiteCollection -discoveryQueueID $parentURLID
}

function discover-SiteCollectionContents {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID
    )

    $sc = get-siteDataSiteCollection -URL $url

    $webs = $sc.site.Web.Webs.Web | select -ExpandProperty URL

    $webs |  push-discoveredURL -discoveryID $discoID -urlType 'Site' -parentURLID $parentURLID

    $sc.site.Web.Lists.List | select -ExpandProperty id| push-discoveredList -discoveryID $discoID -urlType 'List' -parentURLID $parentURLID -url $URL

}

function discover-SiteContents {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID
    )

    $sc = get-siteDataSite -URL $url

    $webs = $sc.Web.Webs.Web | select -ExpandProperty URL
    
    $webs |  push-discoveredURL -discoveryID $discoID -urlType 'Site' -parentURLID $parentURLID

    $sc.Web.Lists.List | select -ExpandProperty id| push-discoveredList -discoveryID $discoID -urlType 'List' -parentURLID $parentURLID -url $URL

}

function save-WebApp {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $webAppSDXML,
        $discoveryQueueID
    )
    begin {
        $sqlConn = getSQLConnection
        $sqlTran = $sqlConn.beginTransaction()
        $commit = $false
    }
    Process {
        $tsql = 'select SPWA_ID,SPWA_DQID,SPWA_SPID,SPWA_Version,SPWA_URL,SPWA_URLZone,SPWA_URLIsHostHeader from SPWebApp where SPWA_SPID = @SPWA_SPID'
        $result = Invoke-Query -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{SPWA_SPID=$webAppSDXML.VirtualServer.Metadata.ID}
        if ($result.count -eq 0) {
            $tsql = 'insert into SPWebApp(SPWA_SPID,SPWA_DQID,SPWA_Version,SPWA_URL,SPWA_URLZone,SPWA_URLIsHostHeader) values(@SPWA_SPID,@SPWA_DQID,@SPWA_Version,@SPWA_URL,@SPWA_URLZone,@SPWA_URLIsHostHeader);select scope_identity() scope_identity'
            $x = invoke-query -sql $tsql -connection $sqlConn -transaction $sqlTran `
                -parameters @{SPWA_SPID=$webAppSDXML.VirtualServer.Metadata.ID;
                              SPWA_DQID=$discoveryQueueID;
                              SPWA_Version=$webAppSDXML.VirtualServer.Metadata.Version;
                              SPWA_URL=$webAppSDXML.VirtualServer.Metadata.URL;
                              SPWA_URLZone=$webAppSDXML.VirtualServer.Metadata.URLZone;
                              SPWA_URLIsHostHeader=$webAppSDXML.VirtualServer.Metadata.URLIsHostHeader}
            $SPWA_ID = $x.scope_identity
        } else {
            $SPWA_ID = $result.SPWA_ID
            $tsql = 'update SPWebApp '
            $parameters = @{}

            $parameters.SPWA_DQID = $discoveryQueueID
            $tsql += "set SPWA_DQID = @SPWA_DQID"

            foreach ($attr in $webAppSDXML.VirtualServer.Metadata) {
                $paramName=""
                $attributeValue = $attr."#text"
                switch ($attr.Name) {
                    "Version" { $paramName="SPWA_Version"}
                    "URL" { $paramName="SPWA_URL"}
                    "URLZone" {$paramName="SPWA_URLZone"}
                    "URLIsHostHeader" {$paramName="SPWA_URLIsHostHeader"}
                }
                if ($paramName -ne "" -and $result.$paramName -ne $attributeValue) {
                    $parameters.$paramName = $attributeValue
                    $tsql += ", $paramName = @$paramName"
                }
            }
            $parameters.SPWA_ID = $SPWA_ID
            $tsql += " where SPWA_ID = @SPWA_ID"
            write-verbose "update SPWebApp SQL: $tsql"
            $x = invoke-SQL -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters $parameters
        }
        $sqlTran.Commit()
        save-webappPolicies -policyXML $webAppSDXML.VirtualServer.Policies -SPWebAppID $SPWA_ID
    }
    End {
        $sqlConn.close()
    }
}

function save-webappPolicies {
    [cmdletbinding()]
    param(
        $policyXML,
        $SPWebAppID
    )
    $currLoginNames = $policyXML.PolicyUser | select -ExpandProperty LoginName
    remove-webAppPoliciesNotIn -currLoginNames $currLoginNames -spWebAppID $SPWebAppID
    $policyXML.PolicyUser | save-webappPolicy -SPWebAppID $SPWebAppID
}

function save-webappPolicy {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $policy,
        $SPWebAppID
    )
    begin {
        $sqlConn = getSQLConnection
        $sqlTran = $sqlConn.beginTransaction()
    }
    Process {
        $tsql = 'select SPP_ID, SPP_LoginName, SPP_BinaryIdentifier,SPP_BinaryIdentifierType,SPP_GrantMask, SPP_DenyMask from SPWebAppPolicy join SPPolicy on SPP_ID = SPWAP_SPPID and SPP_LoginName = @SPP_LoginName and SPWAP_SPWAID = @SPWA_ID'
        $result = Invoke-Query -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{SPP_LoginName=$policy.LoginName;SPWA_ID=$SPWebAppID}
        if ($result.count -eq 0) {
            $tsql = 'insert into SPPolicy(SPP_LoginName, SPP_BinaryIdentifier,SPP_BinaryIdentifierType,SPP_GrantMask, SPP_DenyMask) values (@SPP_LoginName, @SPP_BinaryIdentifier,@SPP_BinaryIdentifierType,@SPP_GrantMask, @SPP_DenyMask);select scope_identity() scope_identity'
            $x = Invoke-Query -sql $tsql -connection $sqlConn -transaction $sqlTran `
                -parameters @{
                    SPP_LoginName=$policy.LoginName;
                    SPP_BinaryIdentifier=$policy.BinaryIdentifier;
                    SPP_BinaryIdentifierType=$policy.BinaryIdentifierType;
                    SPP_GrantMask=$policy.GrantMask;
                    SPP_DenyMask=$policy.DenyMask
                }
            $SPP_ID = $x.scope_identity
            $tsql = 'insert into SPWebAppPolicy(SPWAP_SPWAID,SPWAP_SPPID) values (@SPWAP_SPWAID,@SPWAP_SPPID)'
            $x = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran `
                -parameters @{SPWAP_SPWAID=$SPWebAppID;SPWAP_SPPID=$SPP_ID}
        } else {
            $SPP_ID = $result.SPP_ID
            $tsql = 'update SPPolicy '
            $parameters = @{}
            $needSet = $true
            foreach ($attr in $policy.Attributes) {
                $paramName=""
                $attributeValue = $attr."#text"
                switch ($attr.Name) {
                    "LoginName" { $paramName="SPP_LoginName"}
                    "BinaryIdentifier" { $paramName="SPP_BinaryIdentifier"}
                    "BinaryIdentifierType" {$paramName="SPP_BinaryIdentifierType"}
                    "GrantMask" {$paramName="SPP_GrantMask"}
                    "DenyMask" {$paramName="SPP_DenyMask"}
                }
                if ($paramName -ne "" -and $result.$paramName -ne $attributeValue) {
                    $parameters.$paramName = $attributeValue
                    if ($needSet) {
                        $tsql += "set $paramName = @$paramName"
                        $needSet = $false
                    } else {
                        $tsql += ", $paramName = @$paramName"
                    }
                }
            }
            if (!$needSet) {
                $parameters.SPA_ID = $SPP_ID
                $tsql += " where SPP_ID = @SPP_ID"
                write-verbose "update SPPolicy SQL: $tsql"
                $x = invoke-SQL -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters $parameters
            }
        }
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
    }
}

function remove-webAppPoliciesNotIn {
    [cmdletbinding()]
    param (
        $currLoginNames,
        $spWebAppID
    )
    $sqlConn = getSQLConnection
    $sqlTran = $sqlConn.beginTransaction()
    $tsql = 'select SPP_ID, SPP_LoginName, SPWAP_ID from SPWebAppPolicy join SPPolicy on SPP_ID = SPWAP_SPPID where SPWAP_SPWAID = @SPWA_ID'
    $x = Invoke-Query -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{SPWA_ID=$spWebAppID}
    $x | where {$currLoginNames -notcontains $_.SPP_LoginName} |
        foreach {
            $tsql = 'delete from SPWebAppPolicy where SPWAP_ID = @SPWAP_ID'
            $result = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{SPWAP_ID=$_.SPWAP_ID}
            $tsql = 'delete from SPPolicy where SPP_ID = @SPP_ID'
            $result = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{SPP_ID=$_.SPP_ID}
        }
    $sqlTran.Commit()
    $sqlConn.close()
}

function save-SiteCollection {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $siteCollectionSDXML,
        $discoveryQueueID
    )
    begin {}
    process {}
    end {}
}

Export-ModuleMember -function start-webappDiscovery
