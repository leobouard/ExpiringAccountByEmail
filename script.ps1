param(
    [array]$ExpiresInDays = (30,15,7),
    [Parameter(Mandatory=$true)][ValidateSet('Self','Manager')][array]$Recipients,
    [array]$TestRecipient = ('email@domain.co'),
    [string]$SearchBase = (Get-ADDomain).DistinguishedName
)

$properties = 'AccountExpirationDate','Manager','EmailAddress'
$users = Get-ADUser -Filter {Enabled -eq $true} -Properties $properties -SearchBase $searchBase |
    Where-Object {$_.AccountExpirationDate} | Sort-Object -Property Accountexpirationdate

$users | ForEach-Object {
    $value = [int](New-TimeSpan -End $_.AccountExpirationDate).TotalDays
    $_ | Add-Member -MemberType NoteProperty -Name 'ExpiresIn' -Value $value -Force
}

$users | Where-Object {$_.ExpiresIn -in $ExpiresInDays} | ForEach-Object {

    $body = Get-Content -Path $PSScriptRoot\body.html -Encoding UTF8
    $body = $ExecutionContext.InvokeCommand.ExpandString($body)

    $splat = @{
        Body       = $body
        BodyAsHtml = $true
        Encoding   = 'UTF8'
        From       = 'noreply@domain.com'
        SmtpServer = 'smtp.domain.com'
        Subject    = "[IT] $($_.Name)'s account expires in $($_.ExpiresIn) day(s)"
    }

    $To = [System.Collections.Generic.List[string]]@()
    if ($Recipients -contains 'Manager' -and $_.Manager) { $To.Add((Get-ADUser $_.Manager -Properties EmailAddress).EmailAddress) }
    if ($Recipients -contains 'Self' -and $_.EmailAddress) { $To.Add($_.EmailAddress) }
    if ($TestRecipient) { $To = $TestRecipient }
    $splat.Add('To',$To)

    Send-MailMessage @splat
}