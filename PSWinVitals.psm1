Function Get-VitalStatistics {
    [CmdletBinding(DefaultParameterSetName='Statistics')]
    Param(
        [Parameter(ParameterSetName='All')]
        [Switch]$AllStatistics,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$ComponentStoreAnalysis,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$ComputerInfo,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$CrashDumps,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$DevicesWithBadStatus,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$EnvironmentVariables,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$InstalledFeatures,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$InstalledPrograms,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$VolumeSummary,

        [Parameter(ParameterSetName='Statistics')]
        [Switch]$WindowsUpdates
    )

    if ($PSCmdlet.ParameterSetName -eq 'All') {
        $ComponentStoreAnalysis = $true
        $ComputerInfo = $true
        $CrashDumps = $true
        $DevicesWithBadStatus = $true
        $EnvironmentVariables = $true
        $InstalledFeatures = $true
        $InstalledPrograms = $true
        $VolumeSummary = $true
        $WindowsUpdates = $true
    }

    if ($ComponentStoreAnalysis) {
        if (!(Test-IsAdministrator)) {
            throw 'You must have administrator privileges to analyse the component store.'
        }
    }

    $VitalStatistics = [PSCustomObject]@{
        ComponentStoreAnalysis = $null
        ComputerInfo = $null
        CrashDumps = $null
        DevicesWithBadStatus = $null
        EnvironmentVariables = $null
        InstalledFeatures = $null
        InstalledPrograms = $null
        VolumeSummary = $null
        WindowsUpdates = $null
    }

    if ($ComputerInfo) {
        Write-Verbose -Message 'Retrieving computer info ...'
        $VitalStatistics.ComputerInfo = Get-ComputerInfo
    }

    if ($DevicesWithBadStatus) {
        Write-Verbose -Message 'Retrieving problematic devices ...'
        $VitalStatistics.DevicesWithBadStatus = Get-PnpDevice | Where-Object { $_.Status -ne 'OK' }
    }

    if ($VolumeSummary) {
        Write-Verbose -Message 'Retrieving volume summary ...'
        $VitalStatistics.VolumeSummary = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }
    }
    
    if ($CrashDumps) {
        [PSCustomObject]$CrashDumps = [PSCustomObject]@{
            Kernel = $null
            Services = $null
        }

        Write-Verbose -Message 'Retrieving kernel crash dumps ...'
        $CrashDumps.Kernel = Get-KernelCrashDumps

        Write-Verbose -Message 'Retrieving service crash dumps ...'
        $CrashDumps.Services = Get-ServiceCrashDumps

        $VitalStatistics.CrashDumps = $CrashDumps
    }

    if ($ComponentStoreAnalysis) {
        $VitalStatistics.ComponentStoreAnalysis = Invoke-DISM -Operation AnalyzeComponentStore
    }
    
    if ($InstalledFeatures) {
        if (!(Get-Module -Name ServerManager -ListAvailable)) {
            Write-Warning -Message 'Unable to retrieve installed features as ServerManager module not found.'
        } else {
            Write-Verbose -Message 'Retrieving installed features ...'
            $VitalStatistics.InstalledFeatures = Get-WindowsFeature | Where-Object { $_.Installed }
        }
    }

    if ($InstalledPrograms) {
        Write-Verbose -Message 'Retrieving installed programs ...'
        $VitalStatistics.InstalledPrograms = Get-InstalledPrograms
    }

    if ($EnvironmentVariables) {
        [PSCustomObject]$EnvironmentVariables = [PSCustomObject]@{
            Machine = $null
            User = $null
        }

        Write-Verbose -Message 'Retrieving system environment variables ...'
        $EnvironmentVariables.Machine = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Machine)

        Write-Verbose -Message 'Retrieving user environment variables ...'
        $EnvironmentVariables.User = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::User)

        $VitalStatistics.EnvironmentVariables = $EnvironmentVariables
    }

    if ($WindowsUpdates) {
        if (!(Get-Module -Name PSWindowsUpdate -ListAvailable)) {
            Write-Warning -Message 'Unable to retrieve available updates as PSWindowsUpdate module not found.'
        } else {
            Write-Verbose -Message 'Retrieving available Windows updates ...'
            $VitalStatistics.WindowsUpdates = Get-WUList
        }
    }

    return $VitalStatistics
}

Function Invoke-VitalChecks {
    [CmdletBinding(DefaultParameterSetName='Checks')]
    Param(
        [Parameter(ParameterSetName='All')]
        [Switch]$AllChecks,

        [Parameter(ParameterSetName='Checks')]
        [Switch]$FileSystemScans,

        [Parameter(ParameterSetName='Checks')]
        [Switch]$SystemFileChecker,

        [Parameter(ParameterSetName='Checks')]
        [Switch]$ComponentStoreScan,

        [Parameter(ParameterSetName='Checks')]
        [Switch]$WindowsUpdates,

        [Switch]$VerifyOnly
    )

    if ($PSCmdlet.ParameterSetName -eq 'All') {
        $ComponentStoreScan = $true
        $FileSystemScans = $true
        $SystemFileChecker = $true
        $WindowsUpdates = $true
    }

    if (!(Test-IsAdministrator)) {
        throw 'The checks this function performs require administrator privileges.'
    }

    $VitalChecks = [PSCustomObject]@{
        ComponentStoreScan = $null
        FileSystemScans = $null
        SystemFileChecker = $null
        WindowsUpdates = $null
    }

    if ($FileSystemScans) {
        if ($VerifyOnly) {
            $VitalChecks.FileSystemScans = Invoke-CHKDSK -VerifyOnly
        } else {
            $VitalChecks.FileSystemScans = Invoke-CHKDSK
        }
    }
    
    if ($SystemFileChecker) {
        if ($VerifyOnly) {
            $VitalChecks.SystemFileChecker = Invoke-SFC -VerifyOnly
        } else {
            $VitalChecks.SystemFileChecker = Invoke-SFC
        }
    }

    if ($ComponentStoreScan) {
        if ($VerifyOnly) {
            $VitalChecks.ComponentStoreScan = Invoke-DISM -Operation ScanHealth
        } else {
            $VitalChecks.ComponentStoreScan = Invoke-DISM -Operation RestoreHealth
        }
    }

    if ($WindowsUpdates) {
        if ($VerifyOnly) {
            $VitalChecks.WindowsUpdates = Get-WUInstall -AcceptAll -ListOnly
        } else {
            $VitalChecks.WindowsUpdates = Get-WUInstall -AcceptAll -IgnoreReboot
        }
    }

    return $VitalChecks
}

Function Invoke-VitalUpdates {
    [CmdletBinding(DefaultParameterSetName='Updates')]
    Param(
        [Parameter(ParameterSetName='All')]
        [Switch]$AllUpdates,

        [Parameter(ParameterSetName='Updates')]
        [Switch]$ComponentStoreCleanup,

        [Parameter(ParameterSetName='Updates')]
        [Switch]$PowerShellHelp,

        [Parameter(ParameterSetName='Updates')]
        [Switch]$SysinternalsSuite
    )

    if ($PSCmdlet.ParameterSetName -eq 'All') {
        $ComponentStoreCleanup = $true
        $PowerShellHelp = $true
        $SysinternalsSuite = $true
    }

    if (!(Test-IsAdministrator)) {
        throw 'The updates this function performs require administrator privileges.'
    }

    $VitalUpdates = [PSCustomObject]@{
        ComponentStoreCleanup = $null
        PowerShellHelp = $null
        SysinternalsSuite = $null
    }

    if ($PowerShellHelp) {
        Write-Verbose -Message 'PowerShell: Updating help ...'
        Update-Help -Force
        $VitalUpdates.PowerShellHelp = $true
    }

    if ($SysinternalsSuite) {
        $VitalUpdates.SysinternalsSuite = Update-Sysinternals
    }

    if ($ComponentStoreCleanup) {
        $VitalUpdates.ComponentStoreCleanup = Invoke-DISM -Operation StartComponentCleanup
    }

    return $VitalUpdates
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $NativeRegPath = '\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $Wow6432RegPath = '\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $InstalledPrograms = @(
        # Native applications installed system wide
        if (Test-Path -Path "HKLM:$NativeRegPath") { Get-ChildItem -Path "HKLM:$NativeRegPath" }
        # Native applications installed under the current user
        if (Test-Path -Path "HKCU:$NativeRegPath") { Get-ChildItem -Path "HKCU:$NativeRegPath" }
        # 32-bit applications installed system wide on 64-bit Windows
        if (Test-Path -Path "HKLM:$Wow6432RegPath") { Get-ChildItem -Path "HKLM:$Wow6432RegPath" }
        # 32-bit applications installed under the current user on 64-bit Windows
        if (Test-Path -Path "HKCU:$Wow6432RegPath") { Get-ChildItem -Path "HKCU:$Wow6432RegPath" }
    ) | # Get the properties of each uninstall key
    ForEach-Object { Get-ItemProperty -Path $_.PSPath } |
    # Filter out all the uninteresting entries
    Where-Object { $_.DisplayName -and
        !$_.SystemComponent -and
        !$_.ReleaseType -and
        !$_.ParentKeyName -and
    ($_.UninstallString -or $_.NoRemove) }

    return $InstalledPrograms
}

Function Get-KernelCrashDumps {
    [CmdletBinding()]
    Param()

    $KernelCrashDumps = [PSCustomObject]@{
        MemoryDump = $null
        Minidumps = $null
    }

    $CrashControlRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'

    if (!(Test-Path -Path $CrashControlRegPath -PathType Container)) {
        Write-Warning -Message "The CrashControl key doesn't exist in the Registry so we're guessing dump locations."
    } else {
        $CrashControl = Get-ItemProperty -Path $CrashControlRegPath

        if ($CrashControl.DumpFile) {
            $DumpFile = $CrashControl.DumpFile
        } else {
            $DumpFile = "$env:windir\MEMORY.DMP"
            Write-Warning -Message "The DumpFile value doesn't exist in CrashControl so we're guessing the location."
        }

        if ($CrashControl.MinidumpDir) {
            $MinidumpDir = $CrashControl.MinidumpDir
        } else {
            $MinidumpDir = "$env:windir\Minidump"
            Write-Warning -Message "The MinidumpDir value doesn't exist in CrashControl so we're guessing the location."
        }
    }

    if (Test-Path -Path $DumpFile -PathType Leaf) {
        $KernelCrashDumps.MemoryDump = Get-Item -Path $DumpFile
    }

    if (Test-Path -Path $MinidumpDir -PathType Container) {
        $KernelCrashDumps.Minidumps = Get-Item -Path "$MinidumpDir\*"
    }

    return $KernelCrashDumps
}

Function Get-ServiceCrashDumps {
    [CmdletBinding()]
    Param()

    $ServiceCrashDumps = [PSCustomObject]@{
        LocalSystem = $null
        LocalService = $null
        NetworkService = $null
    }

    $LocalSystemCrashDumpsPath = "$env:windir\System32\Config\SystemProfile\AppData\Local\CrashDumps"
    $LocalServiceCrashDumpsPath = "$env:windir\ServiceProfiles\LocalService\AppData\Local\CrashDumps"
    $NetworkServiceCrashDumpsPath = "$env:windir\ServiceProfiles\NetworkService\AppData\Local\CrashDumps"

    if (Test-Path -Path $LocalSystemCrashDumpsPath -PathType Container) {
        $ServiceCrashDumps.LocalSystem = Get-Item -Path "$LocalSystemCrashDumpsPath\*"
    } else {
        Write-Verbose -Message "The crash dumps path doesn't exist for the LocalSystem account."
    }

    if (Test-Path -Path $LocalServiceCrashDumpsPath -PathType Container) {
        $ServiceCrashDumps.LocalService = Get-Item -Path "$LocalServiceCrashDumpsPath\*"
    } else {
        Write-Verbose -Message "The crash dumps path doesn't exist for the LocalService account."
    }

    if (Test-Path -Path $NetworkServiceCrashDumpsPath -PathType Container) {
        $ServiceCrashDumps.NetworkService = Get-Item -Path "$NetworkServiceCrashDumpsPath\*"
    } else {
        Write-Verbose -Message "The crash dumps path doesn't exist for the NetworkService account."
    }

    return $ServiceCrashDumps
}

Function Invoke-CHKDSK {
    [CmdletBinding()]
    Param(
        [Switch]$VerifyOnly
    )

    # We could use the Repair-Volume cmdlet instead, but it's just a very thin wrapper around CHKDSK anyway...
    $SupportedFileSystems = @('FAT', 'FAT16', 'FAT32', 'NTFS', 'NTFS4', 'NTFS5')
    $Volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.FileSystem -in $SupportedFileSystems }

    [PSCustomObject[]]$ChkDskResults = $null
    foreach ($Volume in $Volumes) {
        $ChkDskResult = [PSCustomObject]@{
            Output = $null
            ExitCode = $null
        }

        $VolumePath = $Volume.Path.TrimEnd('\')
        if ($VerifyOnly) {
            Write-Verbose -Message "[CHKDSK] Running verify-only scan on $VolumePath ..."
            $ChkDskResult.Output += & "$env:windir\System32\chkdsk.exe" "$VolumePath"
        } else {
            Write-Verbose -Message "[CHKDSK] Running scan on $VolumePath ..."
            $ChkDskResult.Output += & "$env:windir\System32\chkdsk.exe" "$VolumePath" /scan
        }
        $ChkDskResult.ExitCode = $LASTEXITCODE

        switch ($LASTEXITCODE) {
            0       { continue }
            2       { Write-Warning -Message "[CHKDSK]: Volume requires cleanup: $VolumePath" }
            3       { Write-Warning -Message "[CHKDSK] Volume contains errors: $VolumePath" }
            default { Write-Error -Message "[CHKDSK] Unexpected exit code '$LASTEXITCODE' while scanning volume: $VolumePath" }
        }

        $ChkDskResults += $ChkDskResult
    }

    return $ChkDskResults
}

Function Invoke-DISM {
    [CmdletBinding()]
    Param(
        [ValidateSet('AnalyzeComponentStore', 'RestoreHealth', 'ScanHealth', 'StartComponentCleanup')]
        [String]$Operation
    )

    $DismResults = [PSCustomObject]@{
        Output = $null
        ExitCode = $null
    }

    Write-Verbose -Message "[DISM] Running $Operation operation ..."
    $DismResults.Output = & "$env:windir\System32\dism.exe" /Online /Cleanup-Image /$Operation
    $DismResults.ExitCode = $LASTEXITCODE

    switch ($LASTEXITCODE) {
        0       { continue }
        default { Write-Error -Message "[DISM] Returned non-zero exit code performing $Operation operation: $LASTEXITCODE" }
    }

    return $DismResults
}

Function Invoke-SFC {
    [CmdletBinding()]
    Param(
        [Switch]$VerifyOnly
    )

    $SfcResults = [PSCustomObject]@{
        Output = $null
        ExitCode = $null
    }

    if ($VerifyOnly) {
        Write-Verbose -Message '[SFC] Running verify-only scan ...'
        $SfcResults.Output = & "$env:windir\System32\sfc.exe" /VERIFYONLY
    } else {
        Write-Verbose -Message '[SFC] Running scan ...'
        $SfcResults.Output = & "$env:windir\System32\sfc.exe" /SCANNOW
    }
    $SfcResults.ExitCode = $LASTEXITCODE

    switch ($LASTEXITCODE) {
        0       { continue }
        default { Write-Error -Message "[SFC] Returned non-zero exit code: $LASTEXITCODE" }
    }

    return $SfcResults
}

Function Test-IsAdministrator {
    [CmdletBinding()]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        return $true
    }
    return $false
}

Function Update-Sysinternals {
    [CmdletBinding()]
    Param()

    $SuiteUrl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
    $ZipPath  = "$env:TEMP\SysinternalsSuite.zip"
    $DestPath = "${env:ProgramFiles(x86)}\Sysinternals"

    Write-Verbose -Message '[Sysinternals] Retrieving latest version ...'
    Invoke-WebRequest -Uri $SuiteUrl -OutFile $ZipPath

    Write-Verbose -Message '[Sysinternals] Decompressing archive ...'
    Remove-Item -Path "$DestPath\*" -Recurse
    Expand-Archive -Path $ZipPath -DestinationPath $DestPath
    Remove-Item -Path $ZipPath

    $Version = (Get-ChildItem -Path $DestPath | Sort-Object -Property LastWriteTime | Select-Object -Last 1).LastWriteTime.ToString('yyyyMMdd')
    Write-Verbose -Message "[Sysinternals] Installed version $Version."

    return $Version
}
