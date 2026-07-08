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
    Width="800"
    Height="650"
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
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="8,3"/>
            <Setter Property="Height" Value="38"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
        </Style>

        <Style x:Key="SectionCard" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource LayerFillColorDefaultBrush}"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="0,0,0,16"/>
        </Style>
    </ui:FluenceWindow.Resources>

    <DockPanel>
        <!-- Bottom Navigation -->
        <StackPanel DockPanel.Dock="Bottom"
                    Orientation="Horizontal"
                    HorizontalAlignment="Center"
                    Margin="0,14,0,14"
                    Height="44">
            <ui:Button x:Name="BtnDeployment"
                       Style="{StaticResource UnifiedButton}"
                       Content="Deployment"
                       Margin="4,0"
                       Width="140"/>
            <ui:Button x:Name="BtnLogs"
                       Style="{StaticResource UnifiedButton}"
                       Content="Logs"
                       Margin="4,0"
                       Width="140"/>
            <ui:Button x:Name="BtnClose"
                       Style="{StaticResource UnifiedButton}"
                       Content="Close"
                       Margin="4,0"
                       Width="140"/>
        </StackPanel>

        <!-- MAIN CONTENT -->
        <ScrollViewer VerticalScrollBarVisibility="Auto" DockPanel.Dock="Top">
            <StackPanel Margin="28,24,28,16">

                <!-- PAGE HEADER -->
                <StackPanel Margin="0,0,0,20">
                    <TextBlock Text="PSADT Remote Deployment"
                               FontSize="28"
                               FontWeight="Bold"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                    <TextBlock x:Name="Subtitle"
                               Text="Ready"
                               FontSize="14"
                               Margin="0,8,0,0"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
                </StackPanel>

                <!-- DEPLOYMENT PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="DeploymentPanel">
                    <StackPanel>
                        <TextBlock Text="Deployment Configuration"
                                   FontSize="16"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,14"/>

                        <TextBlock Text="Computer:"
                                   FontSize="12"
                                   Margin="0,0,0,4"
                                   Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                        <TextBox x:Name="ComputerInput"
                                 Height="36"
                                 Margin="0,0,0,12"
                                 Padding="10,8"
                                 FontSize="12"/>

                        <TextBlock Text="Source Path:"
                                   FontSize="12"
                                   Margin="0,0,0,4"
                                   Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                        <TextBox x:Name="SourcePathInput"
                                 Height="36"
                                 Margin="0,0,0,14"
                                 Padding="10,8"
                                 FontSize="12"
                                 IsReadOnly="True"/>

                        <ui:Button x:Name="BtnDeploy"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Start Deployment"
                                   Margin="0,0,0,8"/>
                        <ui:Button x:Name="BtnReRun"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Re-run Deployment"
                                   Margin="0,0,0,10"
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
                                       Margin="0,0,4,0"/>
                            <ui:Button x:Name="BtnDeleteFolder"
                                       Grid.Column="1"
                                       Style="{StaticResource UnifiedButton}"
                                       Content="Delete"
                                       IsEnabled="False"
                                       Margin="4,0,0,0"/>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- OUTPUT PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="OutputPanel">
                    <StackPanel>
                        <TextBlock Text="Deployment Progress"
                                   FontSize="16"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,12"/>

                        <TextBlock x:Name="StatusText"
                                   Text="Ready"
                                   FontSize="12"
                                   Margin="0,0,0,8"
                                   Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>

                        <ProgressBar x:Name="ProgressBar"
                                     Height="6"
                                     Margin="0,0,0,12"
                                     Foreground="#023c74"/>

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
                                 Height="160"
                                 Padding="10"/>
                    </StackPanel>
                </Border>

                <!-- LOGS PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="LogsPanel"
                        Visibility="Collapsed">
                    <StackPanel>
                        <TextBlock Text="Deployment Logs"
                                   FontSize="16"
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
                                       Content="Refresh"
                                       IsEnabled="False"
                                       Margin="0,0,4,0"/>
                            <ui:Button x:Name="BtnOpenLogFile"
                                       Grid.Column="1"
                                       Style="{StaticResource UnifiedButton}"
                                       Content="Open"
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
                                 Height="300"
                                 Padding="10"/>
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
# Global State
# ============================================================
$script:LastDeployment = $null

# ============================================================
# Helper Functions
# ============================================================

function Add-OutputLine {
    param([string]$Message)
    if ($OutputBox.Text.Length -gt 50000) { 
        $OutputBox.Text = $OutputBox.Text.Substring([Math]::Max(0, $OutputBox.Text.Length - 30000))
    }
    $OutputBox.Text += "$Message`n"
    $OutputBox.ScrollToEnd()
    $window.Dispatcher.Invoke([System.Action]{}, "Render")
}

function Set-Status {
    param([string]$Message)
    $StatusText.Text = $Message
}

function Set-Progress {
    param([int]$Value)
    $ProgressBar.Value = [Math]::Min($Value, 100)
    $window.Dispatcher.Invoke([System.Action]{}, "Render")
}

# ============================================================
# Main Deployment Function
# ============================================================

function Invoke-PSADTDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$SourceDeploymentPath,

        [int]$QuietSeconds = 5
    )

    $DeploymentName = Split-Path $SourceDeploymentPath -Leaf
    $RemoteDeployPath = "C:\PSADT\$DeploymentName"
    $RemoteUNC = "\\$ComputerName\C$\PSADT\$DeploymentName"
    $RemoteExe = Join-Path $RemoteUNC "Invoke-AppDeployToolkit.exe"
    $RemoteLogDir = "\\$ComputerName\C$\Windows\Logs\Software"

    Add-OutputLine "============================================================"
    Add-OutputLine " PSADT Remote Deployment"
    Add-OutputLine "============================================================"
    Add-OutputLine "Computer   : $ComputerName"
    Add-OutputLine "Deployment : $DeploymentName"
    Add-OutputLine "Source     : $SourceDeploymentPath"
    Add-OutputLine "Destination: $RemoteDeployPath"
    Add-OutputLine "============================================================"

    try {

        Set-Status "Creating remote directory..."
        Add-OutputLine "[*] Creating remote directory..."

        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
        } -ArgumentList $RemoteDeployPath

        Add-OutputLine "[OK] Directory ready"

        Set-Status "Copying files..."
        Add-OutputLine "[*] Copying deployment files..."
        Set-Progress 0

        $files = Get-ChildItem -Path $SourceDeploymentPath -Recurse -File
        $totalBytes = ($files | Measure-Object Length -Sum).Sum
        $copiedBytes = 0
        $fileCount = 0
        $totalFiles = $files.Count

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
                [math]::Round(($copiedBytes / $totalBytes) * 100, 0)
            } else { 0 }

            Set-Progress $percent
            Set-Status "Copying ($fileCount/$totalFiles files) - $percent%"
        }

        Add-OutputLine "[OK] Copy complete ($fileCount files)"
        Set-Progress 25

        Set-Status "Validating toolkit..."
        Add-OutputLine "[*] Validating toolkit..."

        if (-not (Test-Path $RemoteExe)) {
            throw "Invoke-AppDeployToolkit.exe not found at $RemoteExe"
        }

        Add-OutputLine "[OK] Toolkit found"
        Set-Progress 50

        Set-Status "Starting deployment session..."
        Add-OutputLine "[*] Starting remote session..."

        $session = New-PSSession -ComputerName $ComputerName

        try {
            $job = Invoke-Command -Session $session -AsJob -ScriptBlock {
                param($Path)
                $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
                Start-Process -FilePath $exe -ArgumentList '-DeploymentType Install -DeployMode Silent' -Wait
            } -ArgumentList $RemoteDeployPath

            Add-OutputLine "[OK] Deployment started"

            Set-Status "Waiting for log file..."
            Add-OutputLine "[*] Waiting for log file..."

            $initialLogs = Get-ChildItem $RemoteLogDir -Filter "*.log" -ErrorAction SilentlyContinue
            $initialNames = $initialLogs.Name
            $logFile = $null
            $waitCount = 0

            while (-not $logFile -and $waitCount -lt 120) {
                Start-Sleep 1
                $waitCount++
                $current = Get-ChildItem $RemoteLogDir -Filter "*.log" -ErrorAction SilentlyContinue
                $new = $current | Where-Object { $_.Name -notin $initialNames } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($new) { $logFile = $new.FullName }
            }

            if (-not $logFile) {
                Add-OutputLine "[WARN] Log file not found"
            } else {
                Add-OutputLine "[OK] Log: $logFile"
                Set-Progress 65

                Set-Status "Monitoring deployment..."
                Add-OutputLine "[*] Monitoring deployment..."
                
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

            Add-OutputLine "[*] Waiting for process completion..."
            Set-Progress 85
            $result = Receive-Job $job -Wait -AutoRemoveJob

        }
        finally {
            if ($session) {
                Remove-PSSession $session -ErrorAction SilentlyContinue
            }
        }

        Set-Progress 100
        Set-Status "Deployment complete"
        Add-OutputLine ""
        Add-OutputLine "============================================================"
        Add-OutputLine " Deployment Complete"
        Add-OutputLine "============================================================"
        Add-OutputLine "Computer   : $ComputerName"
        Add-OutputLine "Deployment : $DeploymentName"
        Add-OutputLine "Path       : $RemoteDeployPath"
        Add-OutputLine "Log        : $logFile"
        Add-OutputLine "============================================================"

        return @{
            ComputerName = $ComputerName
            Deployment = $DeploymentName
            LogFile = $logFile
            Path = $RemoteDeployPath
        }
    }
    catch {
        Add-OutputLine ""
        Add-OutputLine "[ERROR] $($_.Exception.Message)"
        Set-Status "Deployment failed"
        Set-Progress 0
        throw
    }
}

# ============================================================
# Event Handlers
# ============================================================

$BtnDeploy.Add_Click({
    if ([string]::IsNullOrWhiteSpace($ComputerInput.Text)) {
        [System.Windows.MessageBox]::Show("Please enter a computer name", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($SourcePathInput.Text)) {
        [System.Windows.MessageBox]::Show("Please enter a source deployment path", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    if (-not (Test-Path $SourcePathInput.Text)) {
        [System.Windows.MessageBox]::Show("Source path does not exist", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $BtnDeploy.IsEnabled = $false
    $ComputerInput.IsReadOnly = $true
    $SourcePathInput.IsReadOnly = $true
    $OutputBox.Clear()
    $ProgressBar.Value = 0
    $Subtitle.Text = "Deploying..."

    try {
        $script:LastDeployment = Invoke-PSADTDeployment -ComputerName $ComputerInput.Text -SourceDeploymentPath $SourcePathInput.Text

        $BtnReRun.IsEnabled = $true
        $BtnOpenFolder.IsEnabled = $true
        $BtnDeleteFolder.IsEnabled = $true
        $BtnRefreshLogs.IsEnabled = $true
        $BtnOpenLogFile.IsEnabled = $true

    }
    catch {
        Set-Status "Deployment failed"
    }
    finally {
        $BtnDeploy.IsEnabled = $true
        $ComputerInput.IsReadOnly = $false
        $SourcePathInput.IsReadOnly = $false
    }
})

$BtnReRun.Add_Click({
    if (-not $script:LastDeployment) { return }
    
    $OutputBox.AppendText("`n[*] Re-running deployment...`n")
    $OutputBox.ScrollToEnd()
    Set-Status "Re-running..."
    Set-Progress 0

    try {
        Invoke-Command -ComputerName $script:LastDeployment.ComputerName -ScriptBlock {
            param($Path)
            $exe = Join-Path $Path "Invoke-AppDeployToolkit.exe"
            Start-Process -FilePath $exe -ArgumentList '-DeploymentType Install -DeployMode Silent' -Wait
        } -ArgumentList $script:LastDeployment.Path
        
        Add-OutputLine "[OK] Re-run deployment completed"
        Set-Status "Re-run complete"
        Set-Progress 100
    }
    catch {
        Add-OutputLine "[ERROR] Re-run failed: $($_.Exception.Message)"
        Set-Status "Re-run failed"
    }
})

$BtnOpenFolder.Add_Click({
    if (-not $script:LastDeployment) { return }
    try {
        Invoke-Item "\\$($script:LastDeployment.ComputerName)\C$\PSADT\$($script:LastDeployment.Deployment)"
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open folder: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
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
            } -ArgumentList $script:LastDeployment.Path
            
            Add-OutputLine "[OK] Folder deleted"
            Set-Status "Deleted"
        }
        catch {
            Add-OutputLine "[ERROR] Delete failed: $($_.Exception.Message)"
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
        [System.Windows.MessageBox]::Show("Could not read log file: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
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
        [System.Windows.MessageBox]::Show("Could not open folder: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$window.Add_Closed({
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()
    [System.Environment]::Exit(0)
})

# ============================================================
# Show Form
# ============================================================
$OutputBox.Text = "Ready"
$app.Run($window)
