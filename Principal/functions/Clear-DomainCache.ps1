function Clear-DomainCache
{
<#
	.SYNOPSIS
		Clears the domain data cache, resetting this module's domain memory.
	
	.DESCRIPTION
		Clears the domain data cache, resetting this module's domain memory.
	
	.EXAMPLE
		PS C:\> Clear-DomainCache
	
		Clears the domain data cache, resetting this module's domain memory.
#>
	[CmdletBinding()]
	param (
		
	)
	
	process
	{
		$script:domains = @{
			SID = @{ }
			Name = @{ }
			FQDN = @{ }
			NetBIOSName = @{ }
			UPN = @{ }
		}
		$script:domain_cache = @{
			
		}
	}
}
