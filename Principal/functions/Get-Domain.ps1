function Get-Domain
{
	<#
	.SYNOPSIS
		Returns the direct domain object accessible via the server/credential parameter connection.
	
	.DESCRIPTION
		Returns the direct domain object accessible via the server/credential parameter connection.
		Caches data for subsequent calls.
	
	.PARAMETER Server
		The server / domain to work with.
	
	.PARAMETER Credential
		The credentials to use for this operation.
	
	.EXAMPLE
		PS C:\> Get-Domain @parameters

		Returns the domain associated with the specified connection information
	#>
	[CmdletBinding()]
	Param (
		[PSFComputer]
		$Server = '<Default>',
		
		[PSCredential]
		$Credential
	)
	
	process
	{
		if ($script:domain_cache["$Server"])
		{
			return $script:domain_cache["$Server"]
		}
		
		$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
		try { $adObject = Get-ADDomain @parameters -ErrorAction Stop }
		catch { throw }
		$script:domain_cache["$Server"] = $adObject
		$adObject
	}
}