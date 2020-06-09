function Clear-PrincipalCache
{
<#
	.SYNOPSIS
		Clears the principal cache.
	
	.DESCRIPTION
		Clears the principal cache.
		This cache is used to optimize Resolve-Principal calls.
	
		Clearing it may become necessary when:
		- Encountering memory issues (when resolving tens of thousands of principals)
		- switching between multiple forests with the same domain names & Principal names (e.g.: from DEV to QA)
	
	.EXAMPLE
		PS C:\> Clear-PrincipalCache
	
		Clears the principal cache.
#>
	[CmdletBinding()]
	Param (
	
	)
	
	process
	{
		$script:principals = @{
			SID = @{ }
			UserPrincipalName = @{ }
		}
	}
}
