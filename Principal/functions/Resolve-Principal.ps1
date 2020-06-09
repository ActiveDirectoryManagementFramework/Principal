function Resolve-Principal
{
<#
	.SYNOPSIS
		Resolves the principals specified.
	
	.DESCRIPTION
		Resolves the principals specified.
	
		This command can accept a variety of inputs and resolve them into its identity.
		Using registered / cached domains, this resolution will try to automatically determine the correct domain to scan and resolve the identity.
		Then this information can be provided in multiple formats, as would be useful for the user.
	
	.PARAMETER Name
		The name to resolve.
		This can be any of the following formats:
		- SamAccountName (will resolve against targeted server/domain)
		- SID
		- UserPrincipalName (Domain may need to be pre-registered, when using a UPN-Suffix that is not equal to the domain's DNS name)
		- NT Account (May encounter issues if multiple domains share the same NetBIOS Name)
	
	.PARAMETER OutputType
		How the output should be formatted:
		ADObject:       Return the AD object of the principal
		NTAccount:      Return an NT Account object (e.g: 'contoso\max.mustermann')
		SID:            Return the SecurityIdentifier uniquele representing the identity. It is generally a good idea to use this, if you want to compare identities.
		DataSet:        Return the full dataset contained, including the user AD object and the domain information of the hosting domain.
		UPN:            Return the UserPrincipalName
		SamAccountName: Return the SAMAccountName
	
	.PARAMETER Server
		The server / domain to work with.
	
	.PARAMETER Credential
		The credentials to use for this operation.
	
	.EXAMPLE
		PS C:\> Resolve-Principal -Name 'mm'
	
		Resolves the user mm against the local domain.
	
	.EXAMPLE
		PS C:\> Resolve-Principal -Name 'contoso\maria'
	
		Resolves the user maria against the contoso domain.
	
	.EXAMPLE
		PS C:\> Resolve-Principal -Name 'murat@fabrikam.org'
	
		Resolves the user murat against all known domains that support the UPN suffix fabrikam.org.
		Only a domain with the DNS name of fabrikam.org will be detected if not pre-registered or previously already discovered.
	
	.EXAMPLE
		PS C:\> Resolve-Principal -Name 'S-1-5-21-584015949-955715703-1113067636-1105'
	
		Resolves the user with the RID 1105 against the domain with the domain sid 'S-1-5-21-584015949-955715703-1113067636'
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$Name,
		
		[ValidateSet('ADObject', 'NTAccount', 'SID', 'DataSet', 'UPN', 'SamAccountName')]
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
		
		$principalProperties = 'ObjectSID', 'SamAccountName', 'UserPrincipalName', 'Name', 'ObjectClass'
		
		#region Utility functions
		function Convert-ADPrincipal
		{
			[CmdletBinding()]
			param (
				$DomainInfo,
				
				[Parameter(ValueFromPipeline = $true)]
				$ADObject
			)
			
			process
			{
				foreach ($inputItem in $ADObject)
				{
					$data = [pscustomobject]@{
						SID = $inputItem.ObjectSID
						SamAccountName = $inputItem.SamAccountName
						UserPrincipalName = $inputItem.UserPrincipalName
						Name = $inputItem.Name
						ObjectClass = $inputItem.ObjectClass
						Domain = $DomainInfo
						ADObject = $inputItem
					}
					$script:principals.SID["$($inputItem.ObjectSID)"] = $data
					if ($inputItem.UserPrincipalName) { $script:principals.UserPrincipalName[$inputItem.UserPrincipalName] = $data }
					$script:principals.NTAccount[('{0}\{1}' -f $DomainInfo.NetBIOSName, $inputItem.SamAccountName)] = $data
					
					if (-not $script:principals.Domains[$DomainInfo.FQDN])
					{
						$script:principals.Domains[$DomainInfo.FQDN] = @{ }
					}
					$script:principals.Domains[$DomainInfo.FQDN][$data.SamAccountName] = $data
					
					$data
				}
			}
		}
		
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
						'NTAccount' { ('{0}\{1}' -f $item.Domain.NetBIOSName, $item.SamAccountName) -as [System.Security.Principal.NTAccount] }
						'SID' { $item.SID }
						'DataSet' { $item }
						'UPN' { $item.UserPrincipalName }
						'SamAccountName' { $item.SamAccountName }
					}
				}
			}
		}
		
		function Get-DomainInfo
		{
			[CmdletBinding()]
			param (
				[string]
				$Name,
				
				[Hashtable]
				$Parameters
			)
			
			$data = [pscustomobject]@{
				UserName = $Name
				Domain   = $Null
				Type	 = 'Default'
			}
			
			#region Name notation Cases - resolve domain name and username
			try { $domainName = (Get-Domain @Parameters).DNSRoot }
			catch { $domainName = $env:USERDNSDOMAIN }
			if ($Name -like '*@*')
			{
				$data.UserName = @($Name -split '@')[0]
				$data.Type = 'UPN'
				$domainName = @($Name -split '@')[-1]
			}
			elseif ($Name -like '*\*')
			{
				$data.UserName = @($Name -split '\\')[-1]
				$domainName = @($Name -split '\\')[0]
			}
			elseif ($Name -as [System.Security.Principal.SecurityIdentifier])
			{
				$data.UserName = $Name
				$domainName = $Name
			}
			#endregion Name notation Cases - resolve domain name and username
			
			if ($data.Type -eq 'UPN' -and $script:domains.UPN[$domainName])
			{
				$data.Domain = $script:domains.UPN[$domainName]
				return $data
			}
			
			try { $domainObject = Resolve-Domain -Name $domainName -OutputType DataSet @Parameters }
			catch { }
			if ($domainObject)
			{
				$data.Domain = $domainObject
				return $data
			}
			
			# Didn't find anything and not a UPN? Return nothing
			if ($Name -notlike '*@*') { return }
			
			# UPN Suffix Resolution
			$domains = $script:domains.UPN[$domainName]
			
			if (-not $domains) { return }
			
			$data.Domain = $domains
			$data
		}
		
		function Get-ADObject2
		{
			[CmdletBinding()]
			param (
				$DomainInfoObject,
				
				[string]
				$LdapFilter,
				
				[string[]]
				$Properties,
				
				[System.Collections.Hashtable]
				$Parameters
			)
			
			Write-PSFMessage -Level Debug -String 'Resolve-Principal.Resolving.Query' -StringValues $LdapFilter -FunctionName 'Resolve-Principal'
			$adObject = $null
			
			foreach ($domainInfo in $DomainInfoObject)
			{
				$paramClone = $Parameters.Clone()
				$paramClone += @{
					LDAPFilter = $LdapFilter
					ErrorAction = 'Stop'
					Properties = $Properties
				}
				$paramClone.Server = $domainInfo.FQDN
				
				try { $adObject = Get-ADObject @paramClone }
				catch
				{
					$paramClone.Remove('Credential')
					if ($domainInfo.Credential) { $paramClone.Credential = $domainInfo.Credential }
					
					try { $adObject = Get-ADObject @paramClone }
					catch { Write-PSFMessage -Level Warning -String 'Resolve-Principal.AccessError' -StringValues $domainInfo.FQDN -ErrorRecord $_ -FunctionName 'Resolve-Principal' }
				}
				
				if ($adObject) { return $adObject }
			}
		}
		#endregion Utility functions
	}
	process
	{
		if ($script:principals.SID[$Name]) { return $script:principals.SID[$Name] | ConvertTo-Output -OutputType $OutputType }
		if ($script:principals.UserPrincipalName[$Name]) { return $script:principals.UserPrincipalName[$Name] | ConvertTo-Output -OutputType $OutputType }
		if ($script:principals.NTAccount[$Name]) { return $script:principals.NTAccount[$Name] | ConvertTo-Output -OutputType $OutputType }
		
		if ($OutputType -eq 'SID' -and $Name -as [System.Security.Principal.SecurityIdentifier])
		{
			return $Name -as [System.Security.Principal.SecurityIdentifier]
		}
		
		$domainInfo = Get-DomainInfo -Name $Name -Parameters $parameters
		if (-not $domainInfo)
		{
			Write-PSFMessage -Level Warning -String 'Resolve-Principal.Resolve.Domain.Error' -StringValues $Name
			Write-Error "Unable to resolve domain for $Name"
			return
		}
		
		switch ($domainInfo.Type)
		{
			'UPN'
			{
				$adObject = $null
				$adObject = Get-ADObject2 -DomainInfoObject $domainInfo.Domain -LdapFilter "(userPrincipalName=$Name)" -Properties $principalProperties -Parameters $parameters
				
				if (-not $adObject)
				{
					Write-PSFMessage -Level Warning -String 'Resolve-Principal.Resolve.Principal.Error' -StringValues $Name
					Write-Error "Unable to resolve principal $Name"
					return
				}
				$adObject | Convert-ADPrincipal -DomainInfo $domainInfo | ConvertTo-Output -OutputType $OutputType
			}
			#region Default Workflow
			default
			{
				if ($script:principals.Domains[$domainInfo.Domain.FQDN].SamAccountName.$($domainInfo.UserName))
				{
					return $script:principals.Domains[$domainInfo.Domain.FQDN].SamAccountName.$($domainInfo.UserName) | ConvertTo-Output -OutputType $OutputType
				}
				
				$adObject = $null
				$adObject = Get-ADObject2 -DomainInfoObject $domainInfo.Domain -LdapFilter "(samAccountName=$($domainInfo.UserName))" -Properties $principalProperties -Parameters $parameters
				
				if (-not $adObject)
				{
					Write-PSFMessage -Level Warning -String 'Resolve-Principal.Resolve.Principal.Error' -StringValues $Name
					Write-Error "Unable to resolve principal $Name"
					return
				}
				$adObject | Convert-ADPrincipal -DomainInfo $domainInfo.Domain | ConvertTo-Output -OutputType $OutputType
			}
			#endregion Default Workflow
		}
	}
}
