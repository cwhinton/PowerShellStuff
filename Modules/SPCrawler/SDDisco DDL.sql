drop table DiscoveryQueue
drop table DiscoveryCrawls
go

create table DiscoveryCrawls(
	DC_ID int IDENTITY(1,1) NOT NULL primary key,
	DC_StartDT datetime NOT NULL,
	DC_EndDT datetime NULL,
	DC_URL	varchar(500) not null
)

create table DiscoveryQueue(
	DQ_ID bigint IDENTITY(1,1) NOT NULL primary key,
	DQ_ParentID bigint NULL references DiscoveryQueue(DQ_ID),
	DQ_DCID int NOT NULL references DiscoveryCrawls(dc_id),
	DQ_URL varchar(500) NOT NULL,
	DQ_URLType varchar(25) NOT NULL,
	DQ_ListID varchar(38) null,
	DQ_Crawled bit not null default(0),
)

GO

drop table SPWebAppPolicy
drop table SPWebApp
go
create table SPWebApp (
	SPWA_ID	int identity not null primary key,
	SPWA_DQID bigint not null references DiscoveryQueue(DQ_ID),
	SPWA_SPID char(38) not null,
	SPWA_Version char(14) not null,
	SPWA_URL	varchar(150) not null,
	SPWA_URLZone	varchar(25),
	SPWA_URLIsHostHeader bit
)

create table SPPolicy (
	SPP_ID int not null identity primary key,
	SPP_LoginName varchar(100) not null,
	SPP_BinaryIdentifier varchar(200) not null,
	SPP_BinaryIdentifierType varchar(50) not null,
	SPP_GrantMask numeric(25,0) not null,
	SPP_DenyMask numeric(25,0) not null
)

create table SPWebAppPolicy (
	SPWAP_ID integer not null identity primary key,
	SPWAP_SPWAID int not null references SPWebApp(SPWA_ID),
	SPWAP_SPPID int not null references SPPolicy(SPP_ID)
)

create table SPSiteCollection(
	SPSC_ID	int identity not null primary key,
	SPSC_DQID bigint not null references DiscoveryQueue(DQ_ID),
	SPSC_SiteSubscriptionID varchar(36) not null,
	SPSC_URL varchar(250) not null,
	SPSC_SPID	varchar(38) not null,
	SPSC_LastModified datetime,
	SPSC_ContentDatabaseID varchar(38) not null,
	SPSC_WebApplicationID varchar(38) not null,
	SPSC_ChangeID	varchar(200),
	SPSC_SiteTemplate varchar(10),
	SPSC_SiteTemplateID	varchar(5)
)

create table SharePointGroups (
	SPG_ID	bigint identity not null primary key,
	SPG_SPSCID int not null references SPSiteCollection(SPSC_ID),
	SPG_DQID	bigint not null references DiscoveryQueue(DQ_ID),
	SPG_GroupID int not null,
	SPG_Name	varchar(100) not null,
	SPG_Description varchar(500),
	SPG_OwnerID	int not null,
	SPG_OwnerIsUser bit not null
)

create table SharePointUsers (
	SPU_ID	bigint identity not null primary key,
	SPU_SPSCID int not null references SPSiteCollection(SPSC_ID),
	SPU_DQID	bigint not null references DiscoveryQueue(DQ_ID),
	SPU_UserID	int not null,
	SPU_SID		varchar(50),
	SPU_Name	varchar(50),
	SPU_LoginName	varchar(50),
	SPU_Email	varchar(250),
	SPU_Notes	varchar(500),
	SPU_isSiteAdmin	bit,
	SPU_isDomainGroup bit,
	SPU_IsShareByEmailGuestUser bit,
	SPU_IsShareByLinkGuestUser bit
)

create Table SharePointGroupUsers (
	SPGU_ID	bigint not null identity primary key,
	SPGU_SPSCID int not null references SPSiteCollection(SPSC_ID),
	SPGU_SPGID	bigint not null references SharePointGroups(SPG_ID),
	SPGU_SPUID	bigint not null references SharePointUsers(SPU_ID)
)

