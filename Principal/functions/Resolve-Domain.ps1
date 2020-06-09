function Resolve-Domain
{
<#
	.SYNOPSIS
		Resolves a domain based on its name.
	
	.DESCRIPTION
		Resolves a domain based on its name.
		Retrieves the information available from Get-ADDomain, but can tune just what it returns.
		Automatically caches results, in order to optimize performance.
	
		Use Clear-DomainCache to clear this cache.
	
	.PARAMETER Name
		Name of the domain to resolve.
		Defaults to the domain of the targeted server (Server parameter).
	
	.PARAMETER OutputType
		What piece of information to return.
		Defaults to the full ADObject of the domain.
	
	.PARAMETER Server
		The server / domain to work with.
	
	.PARAMETER Credential
		The credentials to use for this operation.
	
	.EXAMPLE
		PS C:\> Resolve-Domain
	
		Resolves the current domain.
	
	.EXAMPLE
		PS C:\> Resolve-Domain -Name fabrikam.org -Server dc01.fabrikam.org -Credential $cred
	
		Resolves the domain 'fabrikam.org' using the server 'dc01.fabrikam.org' and the specified credentials.
#>
	[CmdletBinding()]
	param (
		[string]
		$Name,
		
		[ValidateSet('ADObject', 'FQDN', 'Name', 'SID', 'DistinguishedName', 'NetBIOSName', 'DataSet')]
		[string]
		$OutputType = 'ADObject',
		
		[PSFComputer]
		$Server,
		
		[PSCredential]
		$Credential
	)
	
	begin
	{
		$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
		$creds = $PSBoundParameters | ConvertTo-PSFHashtable -Include Credential
		
		if (-not $Name)
		{
			try { $Name = (Get-Domain @parameters).DNSRoot }
			catch { $Name = $env:USERDNSDOMAIN }
		}
		
		#region Utility Functions
		function ConvertTo-Output
		{
			[CmdletBinding()]
			param (
				[string]
				$OutputType,
				
				[Parameter(ValueFromPipeline = $true)]
				$InputObject
			)
			
			process
			{
				foreach ($item in $InputObject)
				{
					switch ($OutputType)
					{
						'ADObject' { $item.ADObject }
						'FQDN' { $item.FQDN }
						'Name' { $item.Name }
						'SID' { $item.SID }
						'DistinguishedName' { $item.DistinguishedName }
						'NetBIOSName' { $item.NetBIOSName }
						'DataSet' { $item }
					}
				}
			}
		}
		#endregion Utility Functions
	}
	process
	{
		if ($Name -as [System.Security.Principal.SecurityIdentifier])
		{
			$Name = ([System.Security.Principal.SecurityIdentifier]$Name).AccountDomainSid.Value
			if ($script:domains.SID[$Name]) { return $script:domains.SID[$Name] | ConvertTo-Output -OutputType $OutputType }
		}
		if ($script:domains.FQDN[$Name]) { return $script:domains.FQDN[$Name] | ConvertTo-Output -OutputType $OutputType }
		if ($script:domains.Name[$Name]) { return $script:domains.Name[$Name] | ConvertTo-Output -OutputType $OutputType }
		if ($script:domains.NetBIOSName[$Name]) { return $script:domains.NetBIOSName[$Name] | ConvertTo-Output -OutputType $OutputType }
		
		try
		{
			$domainObject = Get-ADDomain @parameters -Identity $Name -ErrorAction Stop
			Register-Domain -Server $domainObject.DNSRoot @creds
		}
		catch
		{
			if (-not $domainObject)
			{
				try
				{
					$domainObject = Get-ADDomain -Identity $Name -ErrorAction Stop
					Register-Domain -Server $domainObject.DNSRoot
				}
				catch { $PSCmdlet.ThrowTerminatingError($_) }
			}
			if (-not $domainObject) { $PSCmdlet.ThrowTerminatingError($_) }
		}
		if (-not $domainObject) { return }
		
		$script:domains.FQDN[$domainObject.DNSRoot] | ConvertTo-Output -OutputType $OutputType
	}
}