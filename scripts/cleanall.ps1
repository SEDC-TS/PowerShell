<#
.CREATED BY:
    Reginald D. Johnson
.CREATED ON:
    11\14\2014
.Synopsis
   automate cleaning up a C: drive with low disk space
.DESCRIPTION
   Cleans up the C: drives temp files and other misc. unneeded files.
.EXAMPLE
   .\cleanup_log.ps1
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
            $LogDate = get-date -format "MM-d-yy-HH"
            $objShell = New-Object -ComObject Shell.Application 
            $objFolder = $objShell.Namespace(0xA) 
                    
            Start-Transcript -Path C:\Windows\Temp\$LogDate.log
            ## Cleans all code off of the screen.
            Clear-Host
$Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
          @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
          @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
          @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
          @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
             Format-Table -AutoSize | Out-String                      
                    
## Stops the windows update service. 
Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue

## Windows Update Service has been stopped successfully!

## Deletes the contents of windows software distribution.
Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue
## The Contents of Windows SoftwareDistribution have been removed successfully!

## Deletes the contents of the Windows Temp folder.
Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } |
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue
## The Contents of Windows Temp have been removed successfully!
             

## Delets all files and folders in user's Temp folder. 
Get-ChildItem "C:\users\$env:USERNAME\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete))} |
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue
## The contents of C:\users\$env:USERNAME\AppData\Local\Temp\ have been removed successfully!
                    
## Remove all files and folders in user's Temporary Internet Files. 
Get-ChildItem "C:\users\$env:USERNAME\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"-Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
remove-item -force -recurse -ErrorAction SilentlyContinue
## All Temporary Internet Files have been removed successfully!

## Cleans IIS Logs if applicable. 
Get-ChildItem "D:\inetpub\logs\LogFiles\*"-Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
remove-item -force -recurse -ErrorAction SilentlyContinue
## All Temporary Internet Files have been removed successfully!

## Remove SEDC Service Log Files. 
Get-ChildItem "D:\SEDC\Services\Logs\*"-Recurse -Force -Verbose -ErrorAction SilentlyContinue |
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} |
remove-item -force -recurse -ErrorAction SilentlyContinue
## All SEDC service Logs have been removed successfully!
                    
## Cleans IIS Logs if applicable.
Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object { ($_.CreationTime -le $(Get-Date).AddDays(-60)) } |
Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue
## All IIS Logfiles over x days old have been removed Successfully!
                  
##Run DISM 
$dismopts = @("/online", "/Cleanup-Image", "/SPSuperseded")
Invoke-Expression -Command "Dism.exe $dismopts"

## deletes the contents of the recycling Bin.

## The Recycling Bin is now being emptied!
$objFolder.items() | ForEach-Object { Remove-Item $_.path -ErrorAction SilentlyContinue -Force -Verbose -Recurse }

## The Recycling Bin has been emptied!
    ## Starts the Windows Update Service
    Get-Service -Name wuauserv | Start-Service -Verbose
$After =  Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
        @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
        @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
        @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } },
        @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } |
            Format-Table -AutoSize | Out-String
     ## Sends some before and after info for ticketing purposes
     Hostname ; Get-Date | Select-Object DateTime
     Write-Host "Before: $Before"
     Write-Host "After: $After"
  
  
  ## Completed Successfully!
  Stop-Transcript 