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

    $sqlConn = getSQLConnection
    $tsql = 'select top 200 DQ_ID, DQ_DCID,DQ_URL,DQ_URLType,DQ_ListID from DiscoveryQueue where DQ_Crawled = 0 and DQ_DCID =@DQ_DCID'
    do {
        $crawlQueue = invoke-query -sql $tsql -connection $sqlConn -parameters @{DQ_DCID=$discoveryID}

        foreach ($discovery in $crawlQueue) {
            $dqID = import-discoveredURL -discovery $discovery
            pop-discoveredURL -URLID $dqID
        }
#            Start-RSJob -ScriptBlock {
#                import-discoveredURL -discovery $_ | pop-discoveredURL
#            } -ModulesToImport adolib,SiteData_Utils `
#                -FunctionsToLoad import-discoveredURL,discover-SiteCollections,discover-SiteCollectionContents,discover-SiteContents,Save-discoveredXML |
#            wait-rsjob -ShowProgress | 
#            remove-rsjob
    } until ($crawlQueue.count -eq 0)
    $sqlConn.close()
    $sqlConn.dispose()
} 


function import-discoveredURL {
    [cmdletbinding()]
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$true,Position=1)]
        $discovery
    )
    process {
        if ($discovery.DQ_URLType -eq "List") {
            Write-Verbose "test"
        }
        switch ($discovery.DQ_URLType) {
            'WebApp' {discover-SiteCollections $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'SiteCollection' { discover-SiteCollectionContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'Site' { discover-SiteContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID}
            'List' { discover-ListContents $discovery.DQ_URL $discovery.DQ_DCID $discovery.DQ_ID $discovery.DQ_ListID}
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
        $tsql = 'insert into DiscoveryCrawls(DC_StartDT,DC_URL) values (getdate(),@DC_URL);select scope_identity() scope_identity'
    }
    process {
        $x = Invoke-Query -sql $tsql -connection $sqlConn -parameters @{dc_URL=$webAppURL}
        $x.scope_identity
    }
    end {
        $sqlConn.close()
        $sqlConn.dispose()
    }
}

function complete-webappDiscovery {
    [cmdletbinding()]
    param (
        $discoveryID
    )

    begin {
        $sqlConn = getSQLConnection
        $tsql = 'update DiscoveryCrawls set DC_EndDt = getdate() where dc_id = @discoveryID'
    }
    process {
        $x = Invoke-sql -sql $tsql -connection $sqlConn -parameters @{discoveryID=$discoveryID}
    }
    end {
        $sqlConn.close()
        $sqlConn.dispose()
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
        $tsql = 'insert into DiscoveryQueue(DQ_ParentID,DQ_DCID,DQ_URL,DQ_URLType) values (@DQ_ParentID,@DQ_DCID,@DQ_URL,@DQ_URLType)'
    }
    process {
        $result = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran `
            -parameters @{DQ_ParentID=$parentURLID;DQ_DCID=$discoveryID;DQ_URL=$url;DQ_URLType=$urlType}
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
        $sqlConn.dispose()
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
        $tsql = 'insert into DiscoveryQueue(DQ_ParentID,DQ_DCID,DQ_URL,DQ_URLType,DQ_ListID) values (@DQ_ParentID,@DQ_DCID,@DQ_URL,@DQ_URLType,@DQ_ListID)'
    }
    process {
        $result = Invoke-Sql -sql $tsql -connection $sqlConn -transaction $sqlTran `
            -parameters @{DQ_ParentID=$parentURLID;DQ_DCID=$discoveryID;DQ_URL=$url;DQ_URLType=$urlType;DQ_ListID=$ListID}
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
        $sqlConn.dispose()
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
        $tsql = 'update DiscoveryQueue set DQ_Crawled = 1 where DQ_ID = @DQ_ID'
    }
    process {
        $result = invoke-sql -sql $tsql -connection $sqlConn -transaction $sqlTran -parameters @{DQ_ID=$URLID}
    }
    end {
        $sqlTran.Commit()
        $sqlConn.close()
        $sqlConn.dispose()
    }
}
    
function discover-SiteCollections {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID
    )

    $wa = get-siteDataWebApp -webAppURL $URL
    
    Save-discoveredXML -XML $wa -DQID $parentURLID

    foreach ($contentDB in $wa.VirtualServer.ContentDatabases.ContentDatabase) {
        $siteCollections = get-siteDataContentDB -contentDBID $contentDB.ID -webAppURL $URL
        foreach ($site in $siteCollections.ContentDatabase.Sites.Site) {
            push-discoveredURL -discoveryID $discoID -urlType 'SiteCollection' -parentURLID $parentURLID -url $site.URL
        }
    }
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

    $webs = $sc.Web.Webs.Web
    $lists = $sc.Web.Lists.List

    foreach ($web in $webs) {
        push-discoveredURL -url $web.URL -discoveryID $discoID -urlType 'Site' -parentURLID $parentURLID
    }

    foreach ($list in $lists) {
        push-discoveredList -url $URL -ListID $list.ID -discoveryID $discoID -urlType 'List' -parentURLID $parentURLID
    }
}

function discover-ListContents {
    [cmdletbinding()]
    param (
        $URL,
        $discoID,
        $parentURLID,
        $listID
    )

    $ld = get-siteDataList -URL $url -ListID $listID

    Save-discoveredXML -XML $ld -DQID $parentURLID
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
    $sqlConn.dispose()
}

Export-ModuleMember -Function start-webappDiscovery
