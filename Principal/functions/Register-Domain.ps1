function Register-Domain
{
<#
	.SYNOPSIS
		Register an additional domain for principal resolution.
	
	.DESCRIPTION
		Register an additional domain for principal resolution.
		Domains are registered automatically as principal resolution occurs, but by pre-caching them, issues can be avoided.
	
		Specifically, resolving principals by UserPrincipalName can fail, if the UPN uses an additional UPN suffix, if the domains have not been pre-registered.
	
		Registering a domain will by default have all domains in that forest registered.
	
	.PARAMETER Server
		The server / domain to work with.
	
	.PARAMETER Credential
		The credentials to use for this operation.
	
	.PARAMETER NoRecurse
		Disables iterating over all domains in the forest when registering a domain.
	
	.EXAMPLE
		PS C:\> Register-Domain
	
		Registers (caches) the current domain - and all fellow domains in the current forest.
	
	.EXAMPLE
		PS C:\> Register-Domain -Server corp.contoso.com -Credential $cred -NoRecurse
	
		Registers (caches) the domain 'corp.contoso.com', using the specified credentials.
		Will not try to access the other domains in the forest.
#>
	[CmdletBinding()]
	param (
		[PSFComputer]
		$Server,
		
		[PSCredential]
		$Credential,
		
		[switch]
		$NoRecurse
	)
	
	begin
	{
		$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
	}
	process
	{
		try { $adDomain = Get-ADDomain @parameters -ErrorAction Stop }
		catch { Stop-PSFFunction -String 'Register-Domain.ADAccess.Failed' -StringValues $Server -EnableException $true -ErrorRecord $_ -Cmdlet $PSCmdlet }
		
		$forest = Get-ADForest @parameters
		
		$data = [pscustomobject]@{
			DistinguishedName = $adDomain.DistinguishedName
			Name			  = $adDomain.Name
			FQDN			  = $adDomain.DNSRoot
			SID			      = $adDomain.DomainSID
			NetBIOSName	      = $adDomain.NetBIOSName
			PDCEmulator	      = $adDomain.PDCEmulator
			UPNs              = @($adDomain.DNSRoot) + @($forest.UPNSuffixes)
			Credential	      = $Credential
			ADObject		  = $adDomain
		}
		$script:domains.SID["$($data.SID)"] = $data
		$script:domains.Name[$data.Name] = $data
		$script:domains.FQDN[$data.FQDN] = $data
		$script:domains.NetBIOSName[$data.NetBIOSName] = $data
		foreach ($upn in $data.UPNs)
		{
			if (-not $script:domains.UPN[$upn]) { $script:domains.UPN[$upn] = @() }
			if ($script:domains.UPN[$upn].FQDN -contains $data.FQDN) { continue }
			$script:domains.UPN[$upn] += $data
		}
		
		if ($NoRecurse) { return }
		
		$cred = $PSBoundParameters | ConvertTo-PSFHashtable -Include Credential
		
		foreach ($domain in $forest.Domains)
		{
			if ($domain -eq $adDomain.DNSRoot) { continue }
			
			try { $domainObject = Get-ADDomain -Server $domain @cred -ErrorAction Stop }
			catch { continue }
			
			$data = [pscustomobject]@{
				DistinguishedName = $domainObject.DistinguishedName
				Name			  = $domainObject.Name
				FQDN			  = $domainObject.DNSRoot
				SID			      = $domainObject.DomainSID
				NetBIOSName	      = $domainObject.NetBIOSName
				PDCEmulator	      = $domainObject.PDCEmulator
				Credential	      = $Credential
				ADobject		  = $domainObject
			}
			$script:domains.SID["$($data.SID)"] = $data
			$script:domains.Name[$data.Name] = $data
			$script:domains.FQDN[$data.FQDN] = $data
			$script:domains.NetBIOSName[$data.NetBIOSName] = $data
			foreach ($upn in $data.UPNs)
			{
				if (-not $script:domains.UPN[$upn]) { $script:domains.UPN[$upn] = @() }
				if ($script:domains.UPN[$upn].FQDN -contains $data.FQDN) { continue }
				$script:domains.UPN[$upn] += $data
			}
		}
	}
}