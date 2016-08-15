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
    process {
        switch ($discovery.DQ_URLType) {
            'WebApp' {discover-SiteCollections $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'SiteCollection' { discover-SiteCollectionContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'Site' { discover-SiteContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'List' {}
        }
        $discovery.DQ_ID
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
    
    Save-discoveredXML -XML $wa -DQID $parentURLID

    $siteCollections = $wa.VirtualServer.ContentDatabases.ContentDatabase | 
        select -ExpandProperty ID  | 
        get-siteDataContentDB -webAppURL $webAppURL
    
    $siteCollections | 
        foreach {
            $_.ContentDatabase.Sites.Site | select -ExpandProperty URL
        } | 
        push-discoveredURL -discoveryID $discoID -urlType 'SiteCollection' -parentURLID $parentURLID

}

function discover-SiteCollectionContents {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID
    )

    $sc = get-siteDataSiteCollection -URL $url
    push-discoveredURL -discoveryID $discoID -urlType 'Site' -parentURLID $parentURLID -url $URL
    Save-discoveredXML -XML $sc -DQID $parentURLID
}

function discover-SiteContents {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID
    )

    $sc = get-siteDataSite -URL $url

    Save-discoveredXML -XML $sc -DQID $parentURLID

    $webs = $sc.Web.Webs.Web | select -ExpandProperty URL
    
    $webs |  push-discoveredURL -discoveryID $discoID -urlType 'Site' -parentURLID $parentURLID

    $sc.Web.Lists.List | select -ExpandProperty id| push-discoveredList -discoveryID $discoID -urlType 'List' -parentURLID $parentURLID -url $URL

}

function Save-discoveredXML {
    [cmdletbinding()]
    param (
        $XML,
        $DQID
    )
    $sqlConn = getSQLConnection
    $tsql = "update DiscoveryQueue set DQ_SiteDataXML=@DQ_SiteDataXML where DQ_ID=@DQ_ID"
    $result = Invoke-Sql -sql $tsql -connection $sqlConn -parameters @{DQ_SiteDataXML=$xml.outerxml;DQ_ID=$DQID}
    $sqlConn.close()
}


Export-ModuleMember -function start-webappDiscovery
