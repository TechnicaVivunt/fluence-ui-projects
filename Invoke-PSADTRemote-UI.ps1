<#
.SYNOPSIS
    PSADT Remote Deployment Tool with Fluent UI (Fluence)
    
.DESCRIPTION
    Deploy PSADT packages to remote computers with real-time monitoring.
    Uses Fluence.Wpf for modern Fluent UI styling matching other toolboxes.
#>

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -Path (Join-Path $scriptRoot "Fluence.Wpf.dll")

$app = [System.Windows.Application]::Current
if (-not $app) { $app = New-Object System.Windows.Application }

[Fluence.Wpf.ApplicationThemeManager]::Apply(
    [Fluence.Wpf.ApplicationTheme]::Auto,
    [Fluence.Wpf.BackdropType]::Mica,
    $true)

[Fluence.Wpf.ApplicationAccentColorManager]::ApplyCustomAccent(
    [System.Windows.Media.Color]::FromRgb(0x02, 0x3C, 0x74)
)

# ============================================================
# XAML UI
# ============================================================
$xaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="PSADT Remote Deployment"
    Width="700"
    Height="550"
    WindowStartupLocation="CenterScreen"
    SystemBackdropType="Mica"
    ExtendsContentIntoTitleBar="True"
    Background="Transparent"
    CornerStyle="Round"
    UseLayoutRounding="True">

    <ui:FluenceWindow.Resources>
        <SolidColorBrush x:Key="AccentFillColorDefaultBrush" Color="#023c74"/>
        <SolidColorBrush x:Key="AccentFillColorSecondaryBrush" Color="#0c274a"/>
        <SolidColorBrush x:Key="AccentFillColorTertiaryBrush" Color="#021f3d"/>
        <SolidColorBrush x:Key="AccentFillColorDisabledBrush" Color="#023c74"/>

        <Style x:Key="UnifiedButton"
               TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance" Value="Accent"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="10,4"/>
            <Setter Property="Height" Value="36"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
        </Style>

        <Style x:Key="SectionCard" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource LayerFillColorDefaultBrush}"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>
    </ui:FluenceWindow.Resources>

    <DockPanel>
        <!-- Bottom Navigation -->
        <StackPanel DockPanel.Dock="Bottom"
                    Orientation="Horizontal"
                    HorizontalAlignment="Center"
                    Margin="0,12,0,12">
            <ui:Button x:Name="BtnDeployment"
                       Style="{StaticResource UnifiedButton}"
                       Content="Deployment"
                       Margin="4,0"
                       Width="120"/>
            <ui:Button x:Name="BtnLogs"
                       Style="{StaticResource UnifiedButton}"
                       Content="Logs"
                       Margin="4,0"
                       Width="120"/>
            <ui:Button x:Name="BtnClose"
                       Style="{StaticResource UnifiedButton}"
                       Content="Close"
                       Margin="4,0"
                       Width="120"/>
        </StackPanel>

        <!-- MAIN CONTENT -->
        <StackPanel Margin="20,20,20,12"
                    DockPanel.Dock="Top">

            <!-- PAGE HEADER -->
            <StackPanel Margin="0,0,0,16">
                <TextBlock Text="PSADT Remote Deployment"
                           ui:TextBlockExtensions.Typography="TitleLarge"
                           FontSize="24"
                           FontWeight="Bold"
                           Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                <TextBlock x:Name="Subtitle"
                           Text="Ready"
                           FontSize="12"
                           Margin="0,4,0,0"
                           Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
            </StackPanel>

            <!-- DEPLOYMENT PANEL -->
            <Border Style="{StaticResource SectionCard}"
                    x:Name="DeploymentPanel">
                <StackPanel>
                    <TextBlock Text="Deployment"
                               FontSize="14"
                               FontWeight="SemiBold"
                               Margin="0,0,0,10"/>

                    <TextBlock Text="Computer:"
                               FontSize="11"
                               Margin="0,0,0,2"/>
                    <TextBox x:Name="ComputerInput"
                             Height="28"
                             Margin="0,0,0,8"/>

                    <TextBlock Text="Source Path:"
                               FontSize="11"
                               Margin="0,0,0,2"/>
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="70"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="SourcePathInput"
                                 Height="28"
                                 Grid.Column="0"
                                 Margin="0,0,6,0"/>
                        <ui:Button x:Name="BtnBrowse"
                                   Grid.Column="1"
                                   Content="Browse"
                                   Height="28"
                                   Style="{StaticResource UnifiedButton}"/>
                    </Grid>

                    <ui:Button x:Name="BtnDeploy"
                               Style="{StaticResource UnifiedButton}"
                               Content="Start Deployment"
                               Margin="0,0,0,6"/>
                    <ui:Button x:Name="BtnReRun"
                               Style="{StaticResource UnifiedButton}"
                               Content="Re-run Deployment"
                               Margin="0,0,0,6"
                               IsEnabled="False"/>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <ui:Button x:Name="BtnOpenFolder"
                                   Grid.Column="0"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Open Folder"
                                   IsEnabled="False"
                                   Margin="0,0,3,0"/>
                        <ui:Button x:Name="BtnDeleteFolder"
                                   Grid.Column="1"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Delete"
                                   IsEnabled="False"
                                   Margin="3,0,0,0"/>
                    </Grid>
                </StackPanel>
            </Border>

            <!-- OUTPUT PANEL -->
            <Border Style="{StaticResource SectionCard}"
                    x:Name="OutputPanel">
                <StackPanel>
                    <TextBlock Text="Status"
                               FontSize="14"
                               FontWeight="SemiBold"
                               Margin="0,0,0,8"/>

                    <TextBox x:Name="StatusText"
                             Height="24"
                             IsReadOnly="True"
                             BorderThickness="0"
                             Background="{DynamicResource LayerFillColorDefaultBrush}"
                             Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                             Margin="0,0,0,8"
                             Text="Ready"
                             FontSize="11"/>

                    <ProgressBar x:Name="ProgressBar"
                                 Height="3"
                                 Margin="0,0,0,8"/>

                    <TextBox x:Name="OutputBox"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"
                             BorderThickness="0"
                             Background="{DynamicResource LayerFillColorDefaultBrush}"
                             Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                             IsReadOnly="True"
                             TextWrapping="Wrap"
                             FontFamily="Consolas"
                             FontSize="9"
                             Height="120"
                             Padding="6"/>
                </StackPanel>
            </Border>

            <!-- LOGS PANEL -->
            <Border Style="{StaticResource SectionCard}"
                    x:Name="LogsPanel"
                    Visibility="Collapsed">
                <StackPanel>
                    <TextBlock Text="Deployment Logs"
                               FontSize="14"
                               FontWeight="SemiBold"
                               Margin="0,0,0,8"/>

                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <ui:Button x:Name="BtnRefreshLogs"
                                   Grid.Column="0"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Refresh"
                                   IsEnabled="False"
                                   Margin="0,0,3,0"/>
                        <ui:Button x:Name="BtnOpenLogFile"
                                   Grid.Column="1"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Open"
                                   IsEnabled="False"
                                   Margin="3,0,0,0"/>
                    </Grid>

                    <TextBox x:Name="LogViewer"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"
                             BorderThickness="0"
                             Background="{DynamicResource LayerFillColorDefaultBrush}"
                             Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                             IsReadOnly="True"
                             TextWrapping="Wrap"
                             FontFamily="Consolas"
                             FontSize="9"
                             Height="270"
                             Padding="6"/>
                </StackPanel>
            </Border>
        </StackPanel>
    </DockPanel>
</ui:FluenceWindow>

"@

[xml]$xmlMain = $xaml
$window = [System.Windows.Markup.XamlReader]::Parse($xaml)

# ============================================================
# Bind Controls
# ============================================================
$BtnDeployment = $window.FindName("BtnDeployment")
$BtnLogs = $window.FindName("BtnLogs")
$BtnClose = $window.FindName("BtnClose")
$Subtitle = $window.FindName("Subtitle")

$DeploymentPanel = $window.FindName("DeploymentPanel")
$LogsPanel = $window.FindName("LogsPanel")

$ComputerInput = $window.FindName("ComputerInput")
$SourcePathInput = $window.FindName("SourcePathInput")
$BtnBrowse = $window.FindName("BtnBrowse")
$BtnDeploy = $window.FindName("BtnDeploy")
$BtnReRun = $window.FindName("BtnReRun")
$BtnOpenFolder = $window.FindName("BtnOpenFolder")
$BtnDeleteFolder = $window.FindName("BtnDeleteFolder")

$StatusText = $window.FindName("StatusText")
$ProgressBar = $window.FindName("ProgressBar")
$OutputBox = $window.FindName("OutputBox")

$BtnRefreshLogs = $window.FindName("BtnRefreshLogs")
$BtnOpenLogFile = $window.FindName("BtnOpenLogFile")
$LogViewer = $window.FindName("LogViewer")

# ============================================================
# Panel Switching
# ============================================================
$BtnDeployment.Add_Click({
    $DeploymentPanel.Visibility = "Visible"
    $LogsPanel.Visibility = "Collapsed"
    $Subtitle.Text = "Deployment"
})

$BtnLogs.Add_Click({
    $DeploymentPanel.Visibility = "Collapsed"
    $LogsPanel.Visibility = "Visible"
    $Subtitle.Text = "Logs"
})

$BtnClose.Add_Click({ $window.Close() })

# ============================================================
# Helper Functions
# ============================================================

function Add-OutputLine {
    param([string]$Message)
    if ($OutputBox.Text.Length -gt 30000) { $OutputBox.Text = "" }
    $OutputBox.Text += "$Message`n"
    $OutputBox.ScrollToEnd()
}

function Set-Status {
    param([string]$Message)
    $StatusText.Text = $Message
    $Subtitle.Text = $Message
}

function Set-Progress {
    param([int]$Value)
    $ProgressBar.Value = [Math]::Min($Value, 100)
}

# ============================================================
# Deployment Logic
# ============================================================

function Invoke-PSADTDeployment {
    param(
        [string]$ComputerName,
        [string]$SourceDeploymentPath,
        [int]$QuietSeconds = 5
    )

    $DeploymentName = Split-Path $SourceDeploymentPath -Leaf
    $RemoteDeployPath = "C:\PSADT\$DeploymentName"
    $RemoteUNC = "\\$ComputerName\C$\PSADT\$DeploymentName"
    $RemoteExe = Join-Path $RemoteUNC "Invoke-AppDeployToolkit.exe"
    $RemoteLogDir = "\\$ComputerName\C$\Windows\Logs\Software"

    try {
        # Test connection
        Set-Status "Testing connection..."
        Add-OutputLine "[*] Testing connection..."
        $null = Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Stop
        Add-OutputLine "[OK] Connected"

        # Create remote directory
        Set-Status "Copying files..."
        Add-OutputLine "[*] Copying deployment..."
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
        } -ArgumentList $RemoteDeployPath

        # Copy files
        $files = Get-ChildItem -Path $SourceDeploymentPath -Recurse -File
        $totalBytes = ($files | Measure-Object Length -Sum).Sum
        $copiedBytes = 0
        $fileCount = 0

        foreach ($file in $files) {
            $relative = $file.FullName.Substring(
                $SourceDeploymentPath.TrimEnd('\').Length
            ).TrimStart('\')
            
            $dest = Join-Path $RemoteUNC $relative
            $destFolder = Split-Path $dest -Parent
            
            if (-not (Test-Path $destFolder)) {
                New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $dest -Force
            $copiedBytes += $file.Length
            $fileCount++
            
            $percent = if ($totalBytes -gt 0) {
                [math]::Round(($copiedBytes / $totalBytes) * 100, 2)
            } else { 0 }
            
            Set-Progress $percent
        }

        Add-OutputLine "[OK] Copy complete ($fileCount files)"
        Set-Progress 25

        # Validate toolkit
        Set-Status "Validating toolkit..."
        Add-OutputLine "[*] Checking toolkit..."
        if (-not (Test-Path $RemoteExe)) {
            Add-OutputLine "[ERROR] Toolkit not found"
            Set-Status "Toolkit validation failed"
            return $false
        }
        Add-OutputLine "[OK] Toolkit found"
        Set-Progress 50

        # Start deployment
        Set-Status "Deploying..."
        Add-OutputLine "[*] Launching deployment..."
        $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
        
        try {
            $job = Invoke-Command -Session $session -AsJob -ScriptBlock {
                param($Path)
                $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
                Start-Process -FilePath $exe -ArgumentList '-DeploymentType Install -DeployMode Silent' -Wait
            } -ArgumentList $RemoteDeployPath

            Add-OutputLine "[OK] Job started"

            # Wait for log file
            Set-Status "Waiting for logs..."
            Add-OutputLine "[*] Waiting for log..."
            
            $initialLogs = Get-ChildItem $RemoteLogDir -Filter "*.log" -ErrorAction SilentlyContinue
            $initialNames = $initialLogs.Name
            $logFile = $null
            $waitCount = 0

            while (-not $logFile -and $waitCount -lt 60) {
                Start-Sleep 1
                $waitCount++
                $current = Get-ChildItem $RemoteLogDir -Filter "*.log" -ErrorAction SilentlyContinue
                $new = $current | Where-Object { $_.Name -notin $initialNames } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($new) { $logFile = $new.FullName }
            }

            if (-not $logFile) {
                Add-OutputLine "[WARN] Log not found"
            } else {
                Add-OutputLine "[OK] Log found: $logFile"
                Set-Progress 75

                # Tail log until quiet
                Set-Status "Monitoring..."
                $lastSize = 0
                $quietCounter = 0

                while ($quietCounter -lt $QuietSeconds) {
                    if (Test-Path $logFile) {
                        $size = (Get-Item $logFile).Length
                        if ($size -ne $lastSize) {
                            $lastSize = $size
                            $quietCounter = 0
                        } else {
                            $quietCounter++
                        }
                    }
                    Start-Sleep 1
                }
            }

            Add-OutputLine "[*] Waiting for job..."
            $result = Receive-Job $job -Wait -AutoRemoveJob

            Set-Progress 100
            Set-Status "Deployment complete"
            Add-OutputLine "[OK] Deployment finished"

            $BtnReRun.IsEnabled = $true
            $BtnOpenFolder.IsEnabled = $true
            $BtnDeleteFolder.IsEnabled = $true
            $BtnRefreshLogs.IsEnabled = $true
            $BtnOpenLogFile.IsEnabled = $true

            return @{ LogFile = $logFile; ComputerName = $ComputerName; DeploymentName = $DeploymentName }
        }
        finally {
            if ($session) { Remove-PSSession $session }
        }
    }
    catch {
        Add-OutputLine "[ERROR] $($_.Exception.Message)"
        Set-Status "Deployment failed"
        Set-Progress 0
        return $false
    }
}

# ============================================================
# Event Handlers
# ============================================================

$script:LastDeployment = $null

$BtnBrowse.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $FolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderDialog.Description = "Select PSADT deployment folder"
    $FolderDialog.ShowNewFolderButton = $false
    
    if ($FolderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourcePathInput.Text = $FolderDialog.SelectedPath
    }
})

$BtnDeploy.Add_Click({
    if ([string]::IsNullOrWhiteSpace($ComputerInput.Text)) {
        [System.Windows.MessageBox]::Show("Please enter a computer name", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($SourcePathInput.Text)) {
        [System.Windows.MessageBox]::Show("Please select a source deployment path", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    if (-not (Test-Path $SourcePathInput.Text)) {
        [System.Windows.MessageBox]::Show("Source path does not exist", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $BtnDeploy.IsEnabled = $false
    $ComputerInput.IsReadOnly = $true
    $SourcePathInput.IsReadOnly = $true
    $BtnBrowse.IsEnabled = $false
    $OutputBox.Clear()

    Add-OutputLine "=== PSADT Deployment ==="
    $script:LastDeployment = Invoke-PSADTDeployment -ComputerName $ComputerInput.Text -SourceDeploymentPath $SourcePathInput.Text

    $BtnDeploy.IsEnabled = $true
    $ComputerInput.IsReadOnly = $false
    $SourcePathInput.IsReadOnly = $false
    $BtnBrowse.IsEnabled = $true
})

$BtnReRun.Add_Click({
    if (-not $script:LastDeployment) { return }
    
    Set-Status "Re-running..."
    Add-OutputLine "[*] Re-running..."
    
    try {
        Invoke-Command -ComputerName $script:LastDeployment.ComputerName -ScriptBlock {
            param($Path)
            $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
            Start-Process -FilePath $exe -ArgumentList '-DeploymentType Install -DeployMode Silent' -Wait
        } -ArgumentList "C:\PSADT\$($script:LastDeployment.DeploymentName)"
        
        Add-OutputLine "[OK] Re-run complete"
        Set-Status "Re-run complete"
    }
    catch {
        Add-OutputLine "[ERROR] Re-run failed"
        Set-Status "Re-run failed"
    }
})

$BtnOpenFolder.Add_Click({
    if (-not $script:LastDeployment) { return }
    try {
        Invoke-Item "\\$($script:LastDeployment.ComputerName)\C$\PSADT\$($script:LastDeployment.DeploymentName)"
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open folder", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$BtnDeleteFolder.Add_Click({
    if (-not $script:LastDeployment) { return }
    
    $result = [System.Windows.MessageBox]::Show("Delete deployment folder?", "Confirm", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Invoke-Command -ComputerName $script:LastDeployment.ComputerName -ScriptBlock {
                param($Path)
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            } -ArgumentList "C:\PSADT\$($script:LastDeployment.DeploymentName)"
            
            Add-OutputLine "[OK] Folder deleted"
            Set-Status "Deleted"
        }
        catch {
            Add-OutputLine "[ERROR] Delete failed"
            Set-Status "Delete failed"
        }
    }
})

$BtnRefreshLogs.Add_Click({
    if (-not $script:LastDeployment -or -not $script:LastDeployment.LogFile) {
        [System.Windows.MessageBox]::Show("No log file available", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    
    try {
        $content = Get-Content $script:LastDeployment.LogFile -ErrorAction SilentlyContinue | Out-String
        $LogViewer.Text = $content
        $LogViewer.ScrollToEnd()
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not read log file", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$BtnOpenLogFile.Add_Click({
    if (-not $script:LastDeployment -or -not $script:LastDeployment.LogFile) {
        [System.Windows.MessageBox]::Show("No log file available", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    
    try {
        $logPath = Split-Path $script:LastDeployment.LogFile -Parent
        explorer.exe $logPath
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open folder", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.Add_Closed({
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()
    [System.Environment]::Exit(0)
})

# ============================================================
# Show Form
# ============================================================
Add-OutputLine "=== Ready ==="
$app.Run($window)
