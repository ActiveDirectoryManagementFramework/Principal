# Principal

## Description

The principal module is designed to help with identity resolution, both in single-domain and multi-forest scenarios. It can return the resolved identity in a variety of formats.

## Examples

> UserPrincipalName to ADObject

```powershell
Resolve-Principal -Name tom@contoso.com -OutputType ADObject
```

> NT Account to SID

```powershell
Resolve-Principal -Name fabrikam\max -OutputType SID
```

> SID To User Principal Name

```powershell
Resolve-Principal -Name S-1-5-21-584015949-955715703-1113067636-1105 -OutputType UPN
```
