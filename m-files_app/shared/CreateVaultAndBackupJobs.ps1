<#
    .SYNOPSIS
	  Creates a new M-Files vault from the vault template
	  and adds scheduled backup jobs for the new vault.
    .EXAMPLE
	  ./CreateVaultAndBackupJobs.ps1
	  ./CreateVaultAndBackupJobs.ps1 -VaultName "Custom Vault Name" -VaultTemplate "Custom Vault Template.mfb"
#>
Param( $VaultName = "My Vault", $VaultTemplate = "My Vault.mfb" )

$ErrorActionPreference = "Stop"

#*=============================================================================
#* FUNCTIONS
#*=============================================================================

# Get job for restoring the vault from the vault backup file.
Function GetRestoreJob( [string]$vaultDataFolder, [string]$vaultGuid, [string]$vaultName, [string]$backupFile )
{
	# Define properties for the vault to be restored.
	$vaultProperties = New-Object MFilesAPI.VaultPropertiesClass
	$vaultProperties.DisplayName = $vaultName
	$vaultProperties.FileDataStorageType = [MFilesAPI.MFFileDataStorage]::MFFileDataStorageDisk
	$vaultProperties.MainDataFolder = $vaultDataFolder
	$vaultProperties.VaultGUID = $vaultGuid

	# Return  restore job object.
	$restoreJob = New-Object MFilesAPI.RestoreJobClass
	$restoreJob.BackupFileFull = $backupFile
	$restoreJob.OverwriteExistingFiles = $False
	$restoreJob.VaultProperties = $vaultProperties
	return $restoreJob
}



# Move Database to SQL
Function MoveToSql( [string]$server, [string]$name, [string]$username, [Security.SecureString]$password ) {

}

# Get one backup job for the vault.
Function GetBackupJob( [string]$backupFolder, [string]$vaultGuid, [string]$vaultName, [Int]$weekNumber, [Int]$dayNumber )
{
	# Get backup name and type.
	If( !$vaultGUID ) {
		$backupName = "Master ${weekNumber}_${dayNumber}"
	}
	ElseIf( $dayNumber -eq 0 ) {
		$backupType = [MFilesAPI.MFBackupType]::MFBackupTypeFull
		$backupName = "${vaultName} Full ${weekNumber}"
	}
	Else {
		$backupType = [MFilesAPI.MFBackupType]::MFBackupTypeDifferential
		$backupName = "${vaultName} Diff ${weekNumber}_${dayNumber}"
	}

	# Get week day when backup job is performed.
	$day = ( Get-Date ).AddDays( $dayNumber + 1 ).AddDays( ( $weekNumber - 1 ) * 7 )
	Switch( [int]( $day ).DayOfWeek ) {
		0 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDaySunday }
		1 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDayMonday }
		2 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDayTuesday }
		3 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDayWednesday }
		4 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDayThursday }
		5 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDayFriday }
		6 { $weekDay = [MFilesAPI.MFTriggerWeekDay]::MFTriggerWeekDaySaturday }
	}

	# Define when backup job is triggered.
	$weeklyTrigger = New-Object MFilesAPI.WeeklyTriggerClass
	$weeklyTrigger.DaysOfTheWeek = $weekDay
	$weeklyTrigger.WeeksInterval = 2
	
	# Define start time for the trigger.
	$trigger = New-Object MFilesAPI.ScheduledJobTriggerClass
	$trigger.BeginDay = $day.Day
	$trigger.BeginMonth = $day.Month
	$trigger.BeginYear = $day.Year
	$trigger.StartHour = 0
	$trigger.StartMinute = 0
	$trigger.Type.SetWeekly( $weeklyTrigger )

	# Define backup job properties.
	$backupJob = New-Object MFilesAPI.BackupJobClass
	$backupJob.Impersonation.ImpersonationType = [MFilesAPI.MFImpersonationType]::MFImpersonationTypeLocalSystem
	$backupJob.OverwriteExistingFiles = $True
	$backupJob.TargetFile = "${backupFolder}\${backupName}.mfb"
	
	# If vault GUID is given, we are setting up vault backup job.
	# Otherwise master database backup job is configured.
	if( $vaultGUID ) {
		$backupJob.BackupType = $backupType
		$backupJob.VaultGUID = $vaultGUID
	}

	# Return backup job.
	$job = New-Object MFilesAPI.ScheduledJobClass
	$job.SetBackupVaultJob( $backupJob )
	$job.Enabled = $True
	$job.JobName = $backupName
	$job.JobType = [MFilesAPI.MFScheduledJobType]::MFScheduledJobTypeBackup
	$job.Triggers.Add( -1, $trigger )
	return $job
}

#*=============================================================================
#* SCRIPT BODY
#*=============================================================================

# Get drive letters.
$dataDiskLabel = "Data"
try {
    $dataDisk = ( Get-Volume -FileSystemLabel $dataDiskLabel -ErrorAction "Stop" ).DriveLetter
} 
catch {
	Write-Host "Disk with label '$dataDiskLabel' doesn't exist."
    exit
}
$backupDiskLabel = "Backup"
try {
    $backupDisk = ( Get-Volume -FileSystemLabel $backupDiskLabel -ErrorAction "Stop" ).DriveLetter
} 
catch {
	Write-Host "Disk with label '$backupDiskLabel' doesn't exist."
    exit
}

# Create a random GUID for the new vault.
$guidForNewVault = [guid]::NewGuid().ToString( "B" )

# Get folders.
$vaultTemplateFolder = "${dataDisk}:\Vault Templates"
$vaultFolder = "${dataDisk}:\Vaults\${VaultName}-${guidForNewVault}"
$backupFolder = "${backupDisk}:\Backups\${VaultName}-${guidForNewVault}"

# Get path to vault template.
$vaultTemplatePath = "${vaultTemplateFolder}\${VaultTemplate}"

# Load the M-Files API.
[Reflection.Assembly]::LoadWithPartialName( "Interop.MFilesAPI" )

# Connect to the M-Files server with current Windows user (must be system administrator).
$mfserver = New-Object MFilesAPI.MFilesServerApplicationClass
$mfserver.ConnectAdministrative()

# Restore vault to the M-Files server.
$restoreJob = GetRestoreJob $vaultFolder $guidForNewVault $VaultName $vaultTemplatePath
$mfserver.VaultManagementOperations.RestoreVault( $restoreJob )
Write-Host "Vault restored."

# Create backups jobs for the vault.
for( $week = 1; $week -le 2; $week++ ) {
	for( $day = 0; $day -le 6; $day++ ) {
		$backupJob = GetBackupJob $backupFolder $guidForNewVault $VaultName $week $day
		$backupJobID = $mfserver.ScheduledJobManagementOperations.AddScheduledJob( $backupJob )
	}
}
Write-Host "Backup jobs created."

# Press any key to continue...
Write-Host
Write-Host "Press any key to continue ..."
$x = $host.UI.RawUI.ReadKey( "NoEcho,IncludeKeyDown" )