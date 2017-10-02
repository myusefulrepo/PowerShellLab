﻿#requires -version 5.0

#test if VM setup is complete

#The password will be passed by the control script WaitforVM.ps1
#You can manually set it while developing this Pester test
$LabData = Import-PowerShellDataFile -Path .\*.psd1
$Secure = ConvertTo-SecureString -String "$($labdata.allnodes.labpassword)" -AsPlainText -Force 
$Domain = "company"
$cred = New-Object PSCredential "$Domain\Administrator", $Secure
$wgcred = New-Object PSCredential  "administrator", $secure

Describe DOM1 {

    $dc = New-PSSession -VMName DOM1 -Credential $cred -ErrorAction SilentlyContinue
    #set error action preference to suppress all error messsages
    if ($dc) {
        Invoke-Command { $errorActionPreference = 'silentlyContinue'} -session $dc
    }

    It "[DOM1] Should belong to the COMPANY domain" {
        $test = Invoke-Command {Get-Ciminstance -ClassName win32_computersystem -property domain} -session $DC
        $test.domain | Should Be "company.pri"
    }

    #test for features
    $feat = Invoke-Command { Get-WindowsFeature | Where installed} -session $dc
    $needed = 'AD-Domain-Services', 'DNS', 'RSAT-AD-Tools',
    'RSAT-AD-PowerShell'
    foreach ($item in $needed) {
        It "[DOM1] Should have feature $item installed" {
            $feat.Name -contains $item | Should Be "True"
        }
    }

    It "[DOM1] Should have an IP address of 192.168.3.10" {
        $i = Invoke-command -ScriptBlock { Get-NetIPAddress -interfacealias 'Ethernet' -AddressFamily IPv4} -Session $dc
        $i.ipv4Address | should be '192.168.3.10'
    }

    It "[DOM1] Should have a domain name of $domain" {
        $r = Invoke-command { Get-ADDomain -ErrorAction SilentlyContinue } -session $dc
        $r.name | should Be $domain
    }

    $OUs = Invoke-command { Get-ADorganizationalUnit -filter * -ErrorAction SilentlyContinue} -session $dc
    $needed = 'IT', 'Dev', 'Marketing', 'Sales', 'Accounting', 'JEA_Operators', 'Servers'
    foreach ($item in $needed) {
        It "[DOM1] Should have organizational unit $item" {
            $OUs.name -contains $item | Should Be "True"
        }
    }
    $groups = Invoke-Command { Get-ADGroup -filter * -ErrorAction SilentlyContinue} -session $dc
    $target = "IT", "Sales", "Marketing", "Accounting", "JEA Operators"
    foreach ($item in $target) {

        It "[DOM1] Should have a group called $item" {
            $groups.Name -contains $item | Should Be "True"
        }

    }

    $users = Invoke-Command { Get-AdUser -filter * -ErrorAction SilentlyContinue} -session $dc
    It "[DOM1] Should have at least 15 user accounts" {
        $users.count | should BeGreaterThan 15
    }

    $admins = Invoke-Command {Get-ADGroupMember "Domain Admins"-ErrorAction SilentlyContinue} -session $dc
    It "[DOM1] ArtD is a member of Domain Admins" {
        $admins.name -contains 'artd'
    }

    It "[DOM1] AprilS is a member of Domain Admins" {
        $admins.name -contains 'aprils'
    }

    $computer = Invoke-Command { Get-ADComputer -filter * -ErrorAction SilentlyContinue} -session $dc
    It "[DOM1] Should have a computer account for WIN10" {
        $computer.name -contains "Win10" | Should Be "True"
    } 

    It "[DOM1] Should have a computer account for SRV1" {
        $computer.name -contains "SRV1" | Should Be "True"
    } 

    It "[DOM1] Should have a computer account for SRV2" {
        $computer.name -contains "SRV2" | Should Be "True"
    } 

    $rec = Invoke-command {Resolve-DNSName Srv3.company.pri} -session $DC
    It "[DOM1] Should have a DNS record for SRV3.COMPANY.PRI" {
        $rec.name | Should be 'srv3.company.pri'
        $rec.ipaddress | Should be '192.168.3.60'
    }
} #DOM1

Describe SRV1 {
    $SRV1 = New-PSSession -VMName SRV1 -Credential $cred -ErrorAction SilentlyContinue
    It "[SRV1] Should belong to the COMPANY domain" {
        $test = Invoke-Command {Get-Ciminstance -ClassName win32_computersystem -property domain} -session $SRV1
        $test.domain | Should Be "company.pri"
    }

    It "[SRV1] Should have an IP address of 192.168.3.50" {
        $i = Invoke-command -ScriptBlock { Get-NetIPAddress -interfacealias 'Ethernet' -AddressFamily IPv4} -Session $SRV1
        $i.ipv4Address | should be '192.168.3.50'
    }
    $dns = Invoke-Command {Get-DnsClientServerAddress -InterfaceAlias ethernet -AddressFamily IPv4} -session $SRV1
    It "[SRV1] Should have a DNS server configuration of 192.168.3.10" {                        
        $dns.ServerAddresses -contains '192.168.3.10' | Should Be "True"           
    }
} #SRV1

Describe SRV2 {
    $SRV2 = New-PSSession -VMName SRV2 -Credential $cred -ErrorAction SilentlyContinue
    It "[SRV2] Should belong to the COMPANY domain" {
        $test = Invoke-Command {Get-Ciminstance -ClassName win32_computersystem -property domain} -session $SRV2
        $test.domain | Should Be "company.pri"
    }
    
    It "[SRV2] Should have an IP address of 192.168.3.51" {
        $i = Invoke-command -ScriptBlock { Get-NetIPAddress -interfacealias 'Ethernet' -AddressFamily IPv4} -Session $SRV2
        $i.ipv4Address | should be '192.168.3.51'
    }
    $dns = Invoke-Command {Get-DnsClientServerAddress -InterfaceAlias ethernet -AddressFamily IPv4} -session $SRV2
    It "[SRV2] Should have a DNS server configuration of 192.168.3.10" {                        
        $dns.ServerAddresses -contains '192.168.3.10' | Should Be "True"           
    }

    It "[SRV2] Should have the Web-Server feature installed" {
        $feature = Invoke-command { Get-WindowsFeature -Name web-server} -session $SRV2
        $feature.Installed | Should be $True
    }

    It "[SRV2] Should have a sample web service file" {
        $file = Invoke-Command { Get-item C:\MyWebServices\firstservice.asmx} -session $SRV2
        $file.name | should be 'firstservice.asmx'
    }
    It "[SRV2] Should have a WebApplication called MyWebServices" {
        $app = Invoke-command {Get-WebApplication -Name MyWebServices} -session $SRV2
        $app.path | Should be "/MyWebServices"
        $app.physicalpath | should be "c:\MyWebServices"
    }
} #SRV2


Describe SRV3 {

    It "[SRV3] Should respond to WSMan requests" { 
        $script:sess = New-PSSession -VMName SRV3 -Credential $wgCred -ErrorAction Stop
        $script:sess.Computername | Should Be 'SRV3'
    }

    It "[SRV3] Should have an IP address of 192.168.3.60" {
        $r = Invoke-Command { Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4} -session $script:sess
        $r.IPv4Address | Should Be '192.168.3.60'
    }

    It "[SRV3] Should belong to the Workgroup domain" {
        $sys = Invoke-Command { Get-CimInstance Win32_computersystem} -session $script:sess
        $sys.Domain | Should Be "Workgroup"
    }

}
#>

Describe Win10 {

    $cl = New-PSSession -VMName Win10 -Credential $cred -ErrorAction SilentlyContinue
    It "[WIN10] Should belong to the COMPANY domain" {
        $test = Invoke-Command {Get-Ciminstance -ClassName win32_computersystem -property domain} -session $cl
        $test.domain | Should Be "company.pri"
    }

    It "[Win10] Should have an IP address of 192.168.3.100" {
        $i = Invoke-command -ScriptBlock { Get-NetIPAddress -interfacealias 'Ethernet' -AddressFamily IPv4} -session $cl
        $i.ipv4Address | should be '192.168.3.100'
    }

    $dns = Invoke-Command {Get-DnsClientServerAddress -InterfaceAlias ethernet -AddressFamily IPv4} -session $cl
    It "[Win10] Should have a DNS server configuration of 192.168.3.10" {                        
        $dns.ServerAddresses -contains '192.168.3.10' | Should Be "True"           
    }

} #client

Get-PSSession | Remove-PSSession
