# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	
	'Register-Domain.ADAccess.Failed'		    = 'Failed to connect to {0}' # $Server
	'Resolve-Principal.AccessError'			    = 'Failed to access domain {0}' # $domainInfo.FQDN
	'Resolve-Principal.Resolve.Domain.Error'    = 'Unable to resolve domain of user {0}' # $Name
	'Resolve-Principal.Resolve.Principal.Error' = 'Unable to resolve user {0}' # $Name
	'Resolve-Principal.Resolving.Query'		    = 'Resolving principal based on {0}' # $LdapFilter
}