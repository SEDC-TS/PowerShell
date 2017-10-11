<#
.CREATED BY:
    Reginald D. Johnson, Jimmy Dutka
.CREATED ON:
    11\14\2014
.Synopsis
   automate cleaning up C and D drive with low disk space
.DESCRIPTION
   Cleans up the C and D drives temp files and other misc. unneeded files
.EXAMPLE
   .\CleanLogsPlus.ps1
#>
function global:Write-Verbose
   (
    [string]$Message
   )
   # check $VerbosePreference variable
   { if ( $VerbosePreference -ne 'SilentlyContinue' )
       { Write-Host " $Message" -ForegroundColor 'Yellow' } }
            Write-Verbose
            $DaysToDelete = 7
            $LogDate = Get-Date -format "MM-d-yy-HH"
            $objShell = New-Object -ComObject Shell.Application
            $objFolder = $objShell.Namespace(0xA)

            Start-Transcript -Path C:\Windows\Temp\$LogDate.log
            # Cleans all code off of the screen.
            Clear-Host
$Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
          @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
          @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
          @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
          @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
             Format-Table -AutoSize | Out-String

# Stop the windows update service
Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue

# Delete Windows memory dump
Remove-Item "C:\Windows\MEMORY.DMP" -force -Verbose -ErrorAction SilentlyContinue

# Delete the contents of windows software distribution
Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
Remove-Item -force -Verbose -recurse -ErrorAction SilentlyContinue

# Delete the contents of Windows Error Reporting/ReportQueue, which contains application error/crash dumps
Get-ChildItem "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
Remove-Item -force -Verbose -recurse -ErrorAction SilentlyContinue

# Delete the contents of the Windows\Temp folder
Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
Remove-Item -force -Verbose -recurse -ErrorAction SilentlyContinue

# Delete the IIS HTTP error logs
Get-ChildItem "C:\Windows\System32\LogFiles\HTTPERR\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -Verbose -recurse -ErrorAction SilentlyContinue

# Delete the IIS SMTP error logs
Get-ChildItem "C:\Windows\System32\LogFiles\SMTPSVC1\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -Verbose -recurse -ErrorAction SilentlyContinue

# Delete files in user's Temp folder
Get-ChildItem "C:\users\$env:USERNAME\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -Verbose -recurse -ErrorAction SilentlyContinue

# Delete files in user's Temporary Internet Files.
Get-ChildItem "C:\users\$env:USERNAME\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -recurse -ErrorAction SilentlyContinue

# Delete IIS logs
Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -le $(Get-Date).AddDays(-60)) } |
Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue

# Delete IIS logs
Get-ChildItem "D:\inetpub\logs\LogFiles\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -recurse -ErrorAction SilentlyContinue

# Delete SEDC OSCP logs
Get-ChildItem "D:\inetpub\wwwroot\oscp\Portals\_default\Logs\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -recurse -ErrorAction SilentlyContinue

# Delete SEDC ClientManagement Log Files
Get-ChildItem "C:\Program Files (x86)\SEDC\ClientManagement\Logs\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -recurse -ErrorAction SilentlyContinue

# Delete SEDC Service Log Files
Get-ChildItem "D:\SEDC\Services\Logs\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
Remove-Item -force -recurse -ErrorAction SilentlyContinue

#Run DISM
$dismopts = @("/online", "/Cleanup-Image", "/SPSuperseded")
Invoke-Expression -Command "Dism.exe $dismopts"

# Delete the contents of the recycling Bin
$objFolder.items() | ForEach-Object { Remove-Item $_.path -ErrorAction SilentlyContinue -Force -Verbose -Recurse }

# Start the Windows Update Service
Get-Service -Name wuauserv | Start-Service -Verbose

# Get some partition and system info so we can see if virtual diskspace can be added
#####
Function Get-DriveLetter($PartPath) {
    $LogicalDisks = Get-WMIObject Win32_LogicalDiskToPartition | Where-Object {$_.Antecedent -eq $PartPath}
    $LogicalDrive = Get-WMIObject Win32_LogicalDisk | Where-Object {$_.__PATH -eq $LogicalDisks.Dependent}
    $LogicalDrive.DeviceID
}
Function Get-PartitionAlignment {
    Get-WMIObject Win32_DiskPartition | Sort-Object DiskIndex, Index | Select-Object -Property `
    @{Expression = {$_.DiskIndex};Label="Disk"},`
    @{Expression = {$_.Index};Label="Partition"},`
    @{Expression = {Get-DriveLetter($_.__PATH)};Label="Drive"},`
    @{Expression = {"{0:N3}" -f ($_.Size/1Gb)};Label="Size_GB"}
}
# Hash table to set the alignment of the properties in the format-table
$OutputTable = `
@{Expression = {$_.Disk};Label="Disk"},`
@{Expression = {$_.Partition};Label="Partition"},`
@{Expression = {$_.Drive};Label="Drive"},`
@{Expression = {"{0:N3}" -f ($_.Size_GB)};Label="Size_GB";align="right"}
$PartitionAlignment = Get-PartitionAlignment
$PartitionAlignment | Format-Table $OutputTable -AutoSize

# Get some system info, to see if we're virtual or not
$SystemType = Get-WmiObject Win32_ComputerSystem | Select-Object Manufacturer, Model | Format-Table -AutoSize | Out-String
Write-Host $SystemType -ForegroundColor 'DarkGreen'

#####

$After =  Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
        @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
        @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
        @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
        @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
            Format-Table -AutoSize | Out-String

# Sends some before and after info for ticketing purposes
Hostname ; Get-Date | Select-Object DateTime
Write-Host "Before: $Before"
Write-Host "After: $After"

# Completed Successfully!
Stop-Transcript
