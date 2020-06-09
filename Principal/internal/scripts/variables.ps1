<#
SID: <data>
Name: <data>
FQDN: <data>
NetBIOSName: <data>
UPN: @(<data>,<data>,...)

<data>:
- DistinguishedName
- Name
- FQDN
- SID
- NetBIOSName
- PDCEmulator
- Credential
- UPNs
- ADObject
#>
$script:domains = @{
	SID = @{ }
	Name = @{ }
	FQDN = @{ }
	NetBIOSName = @{ }
	UPN = @{ }
}


<#
@domain:
- SamAccountName: <data>

SID: <data>
UserPrincipalName: <data>
NTAccount: <data>
Domains: @domain

<data>:
- SID
- SamAccountName
- UserPrincipalName
- Name
- ObjectClass
- Domain
- ADObject
#>
$script:principals = @{
	SID = @{ }
	UserPrincipalName = @{ }
	NTAccount = @{ }
	Domains = @{ }
}


<#
Plain domain cache for asking for a specific domain object.
Caches based on Server parameter.
#>
$script:domain_cache = @{
	
}