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
# Configuration
# ============================================================
$script:Config = @{
    ComputerName           = ""
    SourceDeploymentPath   = ""
    RemoteDeployPath       = ""
    RemoteUNC              = ""
    RemoteExe              = ""
    RemoteLogDir           = ""
    DeploymentName         = ""
    CurrentLogFile         = ""
    DeploymentInProgress   = $false
    QuietSeconds           = 5
}

# ============================================================
# XAML UI
# ============================================================
$xaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="PSADT Remote Deployment"
    Width="900"
    Height="800"
    WindowStartupLocation="CenterScreen"
    SystemBackdropType="Mica"
    ExtendsContentIntoTitleBar="True"
    Background="Transparent"
    CornerStyle="Round"
    UseLayoutRounding="True">

    <!-- GLOBAL RESOURCES -->
    <ui:FluenceWindow.Resources>

        <!-- Accent colors -->
        <SolidColorBrush x:Key="AccentFillColorDefaultBrush" Color="#023c74"/>
        <SolidColorBrush x:Key="AccentFillColorSecondaryBrush" Color="#0c274a"/>
        <SolidColorBrush x:Key="AccentFillColorTertiaryBrush" Color="#021f3d"/>
        <SolidColorBrush x:Key="AccentFillColorDisabledBrush" Color="#023c74"/>

        <!-- Unified button style -->
        <Style x:Key="UnifiedButton"
               TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance" Value="Accent"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Height" Value="40"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
        </Style>

        <!-- Section card style -->
        <Style x:Key="SectionCard" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource LayerFillColorDefaultBrush}"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="0,0,0,16"/>
        </Style>

    </ui:FluenceWindow.Resources>


    <!-- PAGE LAYOUT -->
    <DockPanel>

        <!-- Bottom Navigation -->
        <StackPanel DockPanel.Dock="Bottom"
                    Orientation="Horizontal"
                    HorizontalAlignment="Center"
                    Margin="0,20,0,20">

            <ui:Button x:Name="BtnDeployment"
                       Style="{StaticResource UnifiedButton}"
                       Content="Deployment"
                       Margin="6,0"
                       Width="140"/>

            <ui:Button x:Name="BtnLogs"
                       Style="{StaticResource UnifiedButton}"
                       Content="Logs"
                       Margin="6,0"
                       Width="140"/>

            <ui:Button x:Name="BtnClose"
                       Style="{StaticResource UnifiedButton}"
                       Content="Close"
                       Margin="6,0"
                       Width="140"/>
        </StackPanel>


        <!-- MAIN CONTENT AREA -->
        <ScrollViewer VerticalScrollBarVisibility="Auto"
                      DockPanel.Dock="Top">

            <StackPanel Margin="32,32,32,24"
                        Width="800"
                        HorizontalAlignment="Center">

                <!-- PAGE HEADER -->
                <StackPanel Margin="0,0,0,28">
                    <TextBlock Text="PSADT Remote Deployment"
                               ui:TextBlockExtensions.Typography="TitleLarge"
                               FontSize="30"
                               FontWeight="Bold"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>

                    <TextBlock x:Name="Subtitle"
                               Text="Ready to deploy"
                               ui:TextBlockExtensions.Typography="Subtitle"
                               FontSize="14"
                               Margin="0,8,0,0"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
                </StackPanel>


                <!-- DEPLOYMENT PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="DeploymentPanel">

                    <StackPanel>

                        <TextBlock Text="Deployment Configuration"
                                   ui:TextBlockExtensions.Typography="Subtitle"
                                   FontSize="18"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,16"/>

                        <!-- Computer Name -->
                        <TextBlock Text="Computer Name:"
                                   ui:TextBlockExtensions.Typography="Body"
                                   Margin="0,0,0,6"/>
                        <TextBox x:Name="ComputerInput"
                                 Height="32"
                                 Margin="0,0,0,12"/>

                        <!-- Source Path -->
                        <TextBlock Text="Source Deployment Path:"
                                   ui:TextBlockExtensions.Typography="Body"
                                   Margin="0,0,0,6"/>
                        <Grid Margin="0,0,0,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="100"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="SourcePathInput"
                                     Height="32"
                                     Grid.Column="0"
                                     Margin="0,0,8,0"/>
                            <ui:Button x:Name="BtnBrowse"
                                       Grid.Column="1"
                                       Content="Browse..."
                                       Height="32"
                                       Style="{StaticResource UnifiedButton}"/>
                        </Grid>

                        <!-- Quiet Timeout -->
                        <TextBlock Text="Quiet Timeout (seconds):"
                                   ui:TextBlockExtensions.Typography="Body"
                                   Margin="0,0,0,6"/>
                        <Slider x:Name="QuietSecondsSlider"
                                Minimum="1"
                                Maximum="120"
                                Value="5"
                                IsSnapToTickEnabled="True"
                                TickPlacement="BottomRight"
                                Margin="0,0,0,20"/>

                        <!-- Action Buttons -->
                        <ui:Button x:Name="BtnDeploy"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="▶ Start Deployment"
                                   Margin="0,0,0,8"/>

                        <ui:Button x:Name="BtnReRun"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="🔄 Re-run Deployment"
                                   Margin="0,0,0,8"
                                   IsEnabled="False"/>

                        <Grid Margin="0,0,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <ui:Button x:Name="BtnOpenFolder"
                                       Grid.Column="0"
                                       Style="{StaticResource UnifiedButton}"
                                       Content="📁 Open Folder"
                                       IsEnabled="False"
                                       Margin="0,0,4,0"/>
                            <ui:Button x:Name="BtnDeleteFolder"
                                       Grid.Column="1"
                                       Style="{StaticResource UnifiedButton}"
                                       Content="🗑 Delete Folder"
                                       IsEnabled="False"
                                       Margin="4,0,0,0"/>
                        </Grid>

                    </StackPanel>

                </Border>


                <!-- OUTPUT PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="OutputPanel">

                    <StackPanel>

                        <TextBlock Text="Deployment Status"
                                   ui:TextBlockExtensions.Typography="Subtitle"
                                   FontSize="18"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,12"/>

                        <TextBlock Text="Status:"
                                   ui:TextBlockExtensions.Typography="Body"
                                   Margin="0,0,0,4"/>
                        <TextBox x:Name="StatusText"
                                 Height="28"
                                 IsReadOnly="True"
                                 BorderThickness="0"
                                 Background="{DynamicResource LayerFillColorDefaultBrush}"
                                 Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                                 Margin="0,0,0,12"
                                 Text="Ready"/>

                        <ProgressBar x:Name="ProgressBar"
                                     Height="4"
                                     Margin="0,0,0,8"/>

                        <TextBlock Text="Console Output:"
                                   ui:TextBlockExtensions.Typography="Body"
                                   Margin="0,0,0,4"/>
                        <TextBox x:Name="OutputBox"
                                 AcceptsReturn="True"
                                 VerticalScrollBarVisibility="Auto"
                                 BorderThickness="0"
                                 Background="{DynamicResource LayerFillColorDefaultBrush}"
                                 Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 FontFamily="Consolas"
                                 FontSize="11"
                                 Height="180"
                                 Padding="8"/>

                    </StackPanel>

                </Border>


                <!-- LOGS PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="LogsPanel"
                        Visibility="Collapsed">

                    <StackPanel>

                        <TextBlock Text="Deployment Logs"
                                   ui:TextBlockExtensions.Typography="Subtitle"
                                   FontSize="18"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,12"/>

                        <Grid Margin="0,0,0,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <ui:Button x:Name="BtnRefreshLogs"
                                       Grid.Column="0"
                                       Style="{StaticResource UnifiedButton}"
                                       Content="🔄 Refresh Logs"
                                       IsEnabled="False"
                                       Margin="0,0,4,0"/>
                            <ui:Button x:Name="BtnOpenLogFile"
                                       Grid.Column="1"
                                       Style="{StaticResource UnifiedButton}"
                                       Content="📂 Open in Explorer"
                                       IsEnabled="False"
                                       Margin="4,0,0,0"/>
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
                                 FontSize="11"
                                 Height="380"
                                 Padding="8"/>

                    </StackPanel>

                </Border>

            </StackPanel>

        </ScrollViewer>

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
$QuietSecondsSlider = $window.FindName("QuietSecondsSlider")
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
    $Subtitle.Text = "Deployment Configuration"
})

$BtnLogs.Add_Click({
    $DeploymentPanel.Visibility = "Collapsed"
    $LogsPanel.Visibility = "Visible"
    $Subtitle.Text = "Deployment Logs"
})

$BtnClose.Add_Click({ $window.Close() })

# ============================================================
# Helper Functions
# ============================================================

function Update-OutputConsole {
    param([string]$Message)
    
    if ($OutputBox.Text.Length -gt 50000) {
        $OutputBox.Text = ""
    }
    
    $OutputBox.Text += "$Message`n"
    $OutputBox.ScrollToEnd()
}

function Update-Status {
    param([string]$Message)
    
    $StatusText.Text = $Message
    $Subtitle.Text = $Message
}

function Update-Progress {
    param([int]$Value)
    
    $ProgressBar.Value = [Math]::Min($Value, 100)
}

function Validate-Inputs {
    if ([string]::IsNullOrWhiteSpace($ComputerInput.Text)) {
        [System.Windows.MessageBox]::Show("Please enter a computer name", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return $false
    }
    
    if ([string]::IsNullOrWhiteSpace($SourcePathInput.Text)) {
        [System.Windows.MessageBox]::Show("Please select a source deployment path", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return $false
    }
    
    if (-not (Test-Path $SourcePathInput.Text)) {
        [System.Windows.MessageBox]::Show("Source path does not exist", "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return $false
    }
    
    return $true
}

function Update-DeploymentConfig {
    $script:Config.ComputerName = $ComputerInput.Text
    $script:Config.SourceDeploymentPath = $SourcePathInput.Text
    $script:Config.DeploymentName = Split-Path $SourcePathInput.Text -Leaf
    $script:Config.RemoteDeployPath = "C:\PSADT\$($script:Config.DeploymentName)"
    $script:Config.RemoteUNC = "\\$($script:Config.ComputerName)\C$\PSADT\$($script:Config.DeploymentName)"
    $script:Config.RemoteExe = Join-Path $script:Config.RemoteUNC "Invoke-AppDeployToolkit.exe"
    $script:Config.RemoteLogDir = "\\$($script:Config.ComputerName)\C$\Windows\Logs\Software"
    $script:Config.QuietSeconds = [int]$QuietSecondsSlider.Value
}

function Test-RemoteConnection {
    Update-Status "Testing connection..."
    Update-OutputConsole "[*] Testing connection to $($ComputerInput.Text)..."
    
    try {
        $null = Test-Connection -ComputerName $ComputerInput.Text -Count 1 -ErrorAction Stop
        Update-OutputConsole "[✓] Connection successful!"
        return $true
    }
    catch {
        Update-OutputConsole "[✗] Connection failed: $($_.Exception.Message)"
        Update-Status "Connection failed"
        return $false
    }
}

function Copy-DeploymentFiles {
    Update-Status "Copying files..."
    Update-OutputConsole "[*] Copying deployment files..."
    
    try {
        # Create remote directory
        Invoke-Command -ComputerName $script:Config.ComputerName -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
        } -ArgumentList $script:Config.RemoteDeployPath
        
        $files = Get-ChildItem -Path $script:Config.SourceDeploymentPath -Recurse -File
        $totalBytes = ($files | Measure-Object Length -Sum).Sum
        $copiedBytes = 0
        $fileCount = 0
        
        foreach ($file in $files) {
            $relative = $file.FullName.Substring(
                $script:Config.SourceDeploymentPath.TrimEnd('\').Length
            ).TrimStart('\')
            
            $dest = Join-Path $script:Config.RemoteUNC $relative
            $destFolder = Split-Path $dest -Parent
            
            if (-not (Test-Path $destFolder)) {
                New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $dest -Force
            $copiedBytes += $file.Length
            $fileCount++
            
            $percent = if ($totalBytes -gt 0) {
                [math]::Round(($copiedBytes / $totalBytes) * 100, 2)
            }
            else {
                0
            }
            
            Update-Progress $percent
            Update-OutputConsole "  ✓ $relative"
        }
        
        Update-OutputConsole "[✓] File copy complete ($fileCount files, $([math]::Round($copiedBytes / 1MB, 2))MB)"
        Update-Progress 25
        return $true
    }
    catch {
        Update-OutputConsole "[✗] Copy failed: $($_.Exception.Message)"
        Update-Status "Copy failed"
        return $false
    }
}

function Test-RemoteToolkit {
    Update-Status "Validating toolkit..."
    Update-OutputConsole "[*] Checking for Invoke-AppDeployToolkit.exe..."
    
    if (-not (Test-Path $script:Config.RemoteExe)) {
        Update-OutputConsole "[✗] Invoke-AppDeployToolkit.exe not found"
        Update-Status "Toolkit validation failed"
        return $false
    }
    
    Update-OutputConsole "[✓] Toolkit found!"
    Update-Progress 50
    return $true
}

function Start-RemoteDeployment {
    Update-Status "Deploying..."
    Update-OutputConsole "[*] Launching deployment on $($script:Config.ComputerName)..."
    Update-Progress 50
    
    try {
        $session = New-PSSession -ComputerName $script:Config.ComputerName -ErrorAction Stop
        
        try {
            $job = Invoke-Command -Session $session -AsJob -ScriptBlock {
                param($Path)
                
                $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
                Start-Process -FilePath $exe `
                    -ArgumentList '-DeploymentType Install -DeployMode Silent' `
                    -Wait
                    
            } -ArgumentList $script:Config.RemoteDeployPath
            
            Update-OutputConsole "[✓] Deployment job started (Job: $($job.Id))"
            
            # Wait for log file
            Update-Status "Waiting for logs..."
            Update-OutputConsole "[*] Waiting for deployment log..."
            
            $initialLogs = Get-ChildItem $script:Config.RemoteLogDir -Filter "*.log" -ErrorAction SilentlyContinue
            $initialNames = $initialLogs.Name
            
            $logFile = $null
            $waitCount = 0
            
            while (-not $logFile -and $waitCount -lt 60) {
                Start-Sleep 1
                $waitCount++
                
                $current = Get-ChildItem $script:Config.RemoteLogDir -Filter "*.log" -ErrorAction SilentlyContinue
                
                $new = $current |
                    Where-Object { $_.Name -notin $initialNames } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
                
                if ($new) {
                    $logFile = $new.FullName
                }
            }
            
            if (-not $logFile) {
                Update-OutputConsole "[⚠] Log file not found within timeout"
                $script:Config.CurrentLogFile = ""
            }
            else {
                $script:Config.CurrentLogFile = $logFile
                Update-OutputConsole "[✓] Log file found: $logFile"
                Update-Progress 75
                
                # Tail log until quiet
                $lastSize = 0
                $quietCounter = 0
                
                Update-Status "Deployment in progress..."
                
                while ($quietCounter -lt $script:Config.QuietSeconds) {
                    if (Test-Path $logFile) {
                        $size = (Get-Item $logFile).Length
                        
                        if ($size -ne $lastSize) {
                            $content = Get-Content $logFile -Tail 5 | Out-String
                            Update-OutputConsole $content
                            $lastSize = $size
                            $quietCounter = 0
                        }
                        else {
                            $quietCounter++
                        }
                    }
                    
                    Start-Sleep 1
                }
            }
            
            Update-OutputConsole "[*] Waiting for job completion..."
            $result = Receive-Job $job -Wait -AutoRemoveJob
            
            Update-Progress 100
            Update-Status "Deployment complete!"
            Update-OutputConsole "[✓] Deployment finished successfully!"
            
            $BtnReRun.IsEnabled = $true
            $BtnOpenFolder.IsEnabled = $true
            $BtnDeleteFolder.IsEnabled = $true
            $BtnRefreshLogs.IsEnabled = $true
            $BtnOpenLogFile.IsEnabled = $true
            
            return $true
        }
        finally {
            if ($session) {
                Remove-PSSession $session
            }
        }
    }
    catch {
        Update-OutputConsole "[✗] Deployment failed: $($_.Exception.Message)"
        Update-Status "Deployment failed"
        Update-Progress 0
        return $false
    }
}

function Invoke-ReRunDeployment {
    Update-Status "Re-running..."
    Update-OutputConsole "[*] Re-running deployment..."
    
    try {
        Invoke-Command -ComputerName $script:Config.ComputerName -ScriptBlock {
            param($Path)
            
            $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
            Start-Process -FilePath $exe `
                -ArgumentList '-DeploymentType Install -DeployMode Silent' `
                -Wait
                
        } -ArgumentList $script:Config.RemoteDeployPath
        
        Update-OutputConsole "[✓] Re-run deployment completed!"
        Update-Status "Re-run completed"
    }
    catch {
        Update-OutputConsole "[✗] Re-run failed: $($_.Exception.Message)"
        Update-Status "Re-run failed"
    }
}

function Invoke-DeleteRemoteFolder {
    $result = [System.Windows.MessageBox]::Show(
        "Delete deployment folder on $($script:Config.ComputerName)?",
        "Confirm Delete",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Invoke-Command -ComputerName $script:Config.ComputerName -ScriptBlock {
                param($Path)
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            } -ArgumentList $script:Config.RemoteDeployPath
            
            Update-OutputConsole "[✓] Deployment folder removed"
            Update-Status "Folder deleted"
        }
        catch {
            Update-OutputConsole "[✗] Delete failed: $($_.Exception.Message)"
            Update-Status "Delete failed"
        }
    }
}

function Refresh-LogContent {
    if ([string]::IsNullOrWhiteSpace($script:Config.CurrentLogFile)) {
        [System.Windows.MessageBox]::Show("No log file available", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    
    try {
        $content = Get-Content $script:Config.CurrentLogFile -ErrorAction SilentlyContinue | Out-String
        $LogViewer.Text = $content
        $LogViewer.ScrollToEnd()
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not read log file: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

function Open-LogFile {
    if ([string]::IsNullOrWhiteSpace($script:Config.CurrentLogFile)) {
        [System.Windows.MessageBox]::Show("No log file available", "Info", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    
    try {
        $logPath = Split-Path $script:Config.CurrentLogFile -Parent
        explorer.exe $logPath
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open folder: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# ============================================================
# Event Handlers
# ============================================================

$BtnBrowse.Add_Click({
    $FolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderDialog.Description = "Select PSADT deployment folder"
    $FolderDialog.ShowNewFolderButton = $false
    
    Add-Type -AssemblyName System.Windows.Forms
    if ($FolderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourcePathInput.Text = $FolderDialog.SelectedPath
    }
})

$BtnDeploy.Add_Click({
    if (-not (Validate-Inputs)) { return }
    
    $BtnDeploy.IsEnabled = $false
    $ComputerInput.IsReadOnly = $true
    $SourcePathInput.IsReadOnly = $true
    $BtnBrowse.IsEnabled = $false
    $OutputBox.Clear()
    
    $deployThread = [System.Threading.Thread]::new({
        try {
            Update-DeploymentConfig
            Update-Progress 0
            Update-OutputConsole "=========================================="
            Update-OutputConsole "PSADT Remote Deployment Starting"
            Update-OutputConsole "=========================================="
            
            if (-not (Test-RemoteConnection)) { return }
            if (-not (Copy-DeploymentFiles)) { return }
            if (-not (Test-RemoteToolkit)) { return }
            
            Start-RemoteDeployment
        }
        catch {
            Update-OutputConsole "[✗] Error: $($_.Exception.Message)"
            Update-Status "Error occurred"
        }
        finally {
            $BtnDeploy.IsEnabled = $true
            $ComputerInput.IsReadOnly = $false
            $SourcePathInput.IsReadOnly = $false
            $BtnBrowse.IsEnabled = $true
        }
    })
    $deployThread.Start()
})

$BtnReRun.Add_Click({
    $rerunThread = [System.Threading.Thread]::new({
        Invoke-ReRunDeployment
    })
    $rerunThread.Start()
})

$BtnOpenFolder.Add_Click({
    try {
        Invoke-Item "\\$($script:Config.ComputerName)\C$\PSADT\$($script:Config.DeploymentName)"
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open folder: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$BtnDeleteFolder.Add_Click({
    Invoke-DeleteRemoteFolder
})

$BtnRefreshLogs.Add_Click({
    Refresh-LogContent
})

$BtnOpenLogFile.Add_Click({
    Open-LogFile
})

$window.Add_Closed({
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()
    [System.Environment]::Exit(0)
})

# ============================================================
# Show Form
# ============================================================
Update-OutputConsole "==========================================`nPSADT Remote Deployment Tool Ready`n=========================================="
$app.Run($window)
