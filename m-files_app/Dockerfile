# Using the official Windows Server Core with IIS as the base image.
FROM microsoft/windowsservercore
SHELL ["powershell", "-command"]

ENV MFILES_INSTALLER_URL: 'http://cdn.m-files.com/public/M-Files_11.3/M-Files_x64_eng_11_3_4330_254.msi' \
      MFILES_INSTALLER_SHA256: '1AB361E47EBACE119701DAD5EA79378C0C7DDD1FAA94A83AEA9DC2093C596DE3' \
      MFILES_VERSION: '11.3.4330.254' \
      MFILES_DNS: 'm-files.test.org' \
      MF_MSI_PATH: 'c:\mf_dl.msi'


# Disable M-Files Automatic Update Client. Otherwise, the installation will fail.
RUN New-Item -Path HKLM:\SOFTWARE\Motive; \
New-Item -Path HKLM:\SOFTWARE\Motive\M-Files; \
New-ItemProperty -Path HKLM:\SOFTWARE\Motive\M-Files -Name StartMFAUClient -Value 0 -PropertyType DWORD

# Install M-Files Server.
# Download the installer, test the SHA to verify, install and delete installer.
RUN Invoke-WebRequest -OutFile $env:MF_MSI_PATH -Uri $env:MFILES_INSTALLER_URL; \
    if ((Get-FileHash $env:MF_MSI_PATH -Algorithm sha256).Hash -ne $env:MFILES_INSTALLER_SHA256) {exit 1}; \
    Start-Process 'msiexec.exe' -ArgumentList '/package', $env:MF_MSI_PATH, '/quiet', 'ADDLOCAL=Server,Support' -Wait -NoNewWindow; \
    Remove-Item $env:MF_MSI_PATH    

# Execute the commands to install IIS Features required by M-Files Web Access. 
# Component list cross referenced from here: 
# http://geekswithblogs.net/Wchrabaszcz/archive/2013/09/04/how-to-install-windows-server-features-using-powershell--server.aspx
RUN Install-WindowsFeature -name Web-Server -IncludeManagementTools; \
    Install-WindowsFeature -Name Web-Net-Ext45 -IncludeAllSubFeature; \
    Install-WindowsFeature -Name Web-Common-Http -IncludeAllSubFeature; \
    Install-WindowsFeature -Name Web-Asp-Net45 -IncludeAllSubFeature; \
    Install-WindowsFeature -Name Web-Dyn-Compression -IncludeAllSubFeature; \
    Install-WindowsFeature -Name Web-Windows-Auth -IncludeAllSubFeature; \
    Install-WindowsFeature -Name Web-Metabase -IncludeAllSubFeature

# Add resource files to be used from local ./shared folder.
ADD ./shared /setup/

#Create a new sa-login to use for logging in outside of the container.
RUN c:\setup\LoginAndWebAccessSetup.exe "mfsa" "foo123"

# Create a self-signed cert and attach it to Default Web Site HTTPS binging
RUN . c:\\setup\https.ps1

#Open browser access from outside to the M-Files Web website.
 
# Dot-source a helper script to enable RPC over HTTPS and run it.
RUN . c:\\setup\\RpcOverHttpsSetup_Docker.ps1 ; \
Set-RpcOverHttps -mfilesDns $env:MFILES_DNS -mfilesVersion $env:MFILES_VERSION

# Add a healthcheck to check if the default web site is up.
HEALTHCHECK CMD powershell -command \  
    try { \
     $response = iwr http://localhost; \
     if ($response.StatusCode -eq 200) { return 0} \
     else {return 1}; \
    } catch { return 1 }