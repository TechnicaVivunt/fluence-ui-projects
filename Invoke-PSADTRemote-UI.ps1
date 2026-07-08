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

function Update-OutputConsole {
    param([string]$Message)
    
    if ($OutputBox.Text.Length -gt 30000) {
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
}

function Test-RemoteConnection {
    Update-Status "Testing connection..."
    Update-OutputConsole "[*] Testing connection..."
    
    try {
        $null = Test-Connection -ComputerName $ComputerInput.Text -Count 1 -ErrorAction Stop
        Update-OutputConsole "[OK] Connected"
        return $true
    }
    catch {
        Update-OutputConsole "[ERROR] Connection failed"
        Update-Status "Connection failed"
        return $false
    }
}

function Copy-DeploymentFiles {
    Update-Status "Copying files..."
    Update-OutputConsole "[*] Copying deployment..."
    
    try {
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
        }
        
        $sizeMB = [math]::Round($copiedBytes / 1MB, 2)
        Update-OutputConsole "[OK] Copy complete ($fileCount files)"
        Update-Progress 25
        return $true
    }
    catch {
        Update-OutputConsole "[ERROR] Copy failed"
        Update-Status "Copy failed"
        return $false
    }
}

function Test-RemoteToolkit {
    Update-Status "Validating toolkit..."
    Update-OutputConsole "[*] Checking toolkit..."
    
    if (-not (Test-Path $script:Config.RemoteExe)) {
        Update-OutputConsole "[ERROR] Toolkit not found"
        Update-Status "Toolkit validation failed"
        return $false
    }
    
    Update-OutputConsole "[OK] Toolkit found"
    Update-Progress 50
    return $true
}

function Start-RemoteDeployment {
    Update-Status "Deploying..."
    Update-OutputConsole "[*] Launching deployment..."
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
            
            Update-OutputConsole "[OK] Job started"
            
            # Wait for log file
            Update-Status "Waiting for logs..."
            Update-OutputConsole "[*] Waiting for log..."
            
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
                Update-OutputConsole "[WARN] Log not found"
                $script:Config.CurrentLogFile = ""
            }
            else {
                $script:Config.CurrentLogFile = $logFile
                Update-OutputConsole "[OK] Log found"
                Update-Progress 75
                
                # Tail log until quiet
                $lastSize = 0
                $quietCounter = 0
                
                Update-Status "Monitoring..."
                
                while ($quietCounter -lt $script:Config.QuietSeconds) {
                    if (Test-Path $logFile) {
                        $size = (Get-Item $logFile).Length
                        
                        if ($size -ne $lastSize) {
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
            
            Update-OutputConsole "[*] Waiting for job..."
            $result = Receive-Job $job -Wait -AutoRemoveJob
            
            Update-Progress 100
            Update-Status "Deployment complete"
            Update-OutputConsole "[OK] Deployment finished"
            
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
        Update-OutputConsole "[ERROR] Deployment failed"
        Update-Status "Deployment failed"
        Update-Progress 0
        return $false
    }
}

function Invoke-ReRunDeployment {
    Update-Status "Re-running..."
    Update-OutputConsole "[*] Re-running..."
    
    try {
        Invoke-Command -ComputerName $script:Config.ComputerName -ScriptBlock {
            param($Path)
            
            $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
            Start-Process -FilePath $exe `
                -ArgumentList '-DeploymentType Install -DeployMode Silent' `
                -Wait
                
        } -ArgumentList $script:Config.RemoteDeployPath
        
        Update-OutputConsole "[OK] Re-run complete"
        Update-Status "Re-run complete"
    }
    catch {
        Update-OutputConsole "[ERROR] Re-run failed"
        Update-Status "Re-run failed"
    }
}

function Invoke-DeleteRemoteFolder {
    $result = [System.Windows.MessageBox]::Show(
        "Delete deployment folder?",
        "Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Invoke-Command -ComputerName $script:Config.ComputerName -ScriptBlock {
                param($Path)
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            } -ArgumentList $script:Config.RemoteDeployPath
            
            Update-OutputConsole "[OK] Folder deleted"
            Update-Status "Deleted"
        }
        catch {
            Update-OutputConsole "[ERROR] Delete failed"
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
        [System.Windows.MessageBox]::Show("Could not read log file", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
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
        [System.Windows.MessageBox]::Show("Could not open folder", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

# ============================================================
# Event Handlers
# ============================================================

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
    if (-not (Validate-Inputs)) { return }
    
    $BtnDeploy.IsEnabled = $false
    $ComputerInput.IsReadOnly = $true
    $SourcePathInput.IsReadOnly = $true
    $BtnBrowse.IsEnabled = $false
    $OutputBox.Clear()
    
    $deployScript = {
        try {
            Update-DeploymentConfig
            Update-Progress 0
            Update-OutputConsole "=== PSADT Deployment ==="
            
            if (-not (Test-RemoteConnection)) { return }
            if (-not (Copy-DeploymentFiles)) { return }
            if (-not (Test-RemoteToolkit)) { return }
            
            Start-RemoteDeployment
        }
        catch {
            Update-OutputConsole "[ERROR] Deployment error"
            Update-Status "Error"
        }
        finally {
            $BtnDeploy.IsEnabled = $true
            $ComputerInput.IsReadOnly = $false
            $SourcePathInput.IsReadOnly = $false
            $BtnBrowse.IsEnabled = $true
        }
    }
    
    $runspace = [System.Management.Automation.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('Config', $script:Config)
    $runspace.SessionStateProxy.SetVariable('Update-OutputConsole', (Get-Item Function:\Update-OutputConsole))
    $runspace.SessionStateProxy.SetVariable('Update-Status', (Get-Item Function:\Update-Status))
    $runspace.SessionStateProxy.SetVariable('Update-Progress', (Get-Item Function:\Update-Progress))
    $runspace.SessionStateProxy.SetVariable('Test-RemoteConnection', (Get-Item Function:\Test-RemoteConnection))
    $runspace.SessionStateProxy.SetVariable('Copy-DeploymentFiles', (Get-Item Function:\Copy-DeploymentFiles))
    $runspace.SessionStateProxy.SetVariable('Test-RemoteToolkit', (Get-Item Function:\Test-RemoteToolkit))
    $runspace.SessionStateProxy.SetVariable('Start-RemoteDeployment', (Get-Item Function:\Start-RemoteDeployment))
    $runspace.SessionStateProxy.SetVariable('Update-DeploymentConfig', (Get-Item Function:\Update-DeploymentConfig))
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript($deployScript)
    [void]$ps.BeginInvoke()
})

$BtnReRun.Add_Click({
    $rerunScript = {
        Invoke-ReRunDeployment
    }
    
    $runspace = [System.Management.Automation.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('Config', $script:Config)
    $runspace.SessionStateProxy.SetVariable('Update-OutputConsole', (Get-Item Function:\Update-OutputConsole))
    $runspace.SessionStateProxy.SetVariable('Update-Status', (Get-Item Function:\Update-Status))
    $runspace.SessionStateProxy.SetVariable('Invoke-ReRunDeployment', (Get-Item Function:\Invoke-ReRunDeployment))
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript($rerunScript)
    [void]$ps.BeginInvoke()
})

$BtnOpenFolder.Add_Click({
    try {
        Invoke-Item "\\$($script:Config.ComputerName)\C$\PSADT\$($script:Config.DeploymentName)"
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open folder", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
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
Update-OutputConsole "=== Ready ==="
$app.Run($window)
