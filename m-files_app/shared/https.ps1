import-module webadministration
#Get-Module -ListAvailable

cd cert:
$cert = New-SelfSignedCertificate -DnsName  myweb -Friendlyname MyCert -CertStoreLocation Cert:\LocalMachine\My
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList Root, LocalMachine
$rootStore.Open("MaxAllowed")
$rootStore.Add($cert)
$rootStore.Close()

cd iis:
new-item -path IIS:\SslBindings\0.0.0.0!443 -value $cert
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
iisreset