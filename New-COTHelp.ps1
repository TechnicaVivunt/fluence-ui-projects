<#
.SYNOPSIS
    COT Help Utility Script

.DESCRIPTION
    Provides a modern WPF-based GUI for displaying PC information and support tools.
    Uses Fluence.Wpf for Fluent UI rendering (Mica, themed controls, accent color).
    Presents a main window with system details (computer name, user, model, IP address,
    disk space, OS version, last reboot, VPN status). Includes extended reporting for
    mapped drives, printers, monitor serials, and GlobalProtect version, plus an admin
    toolbox for SCCM client actions, logs, and reports.

.AUTHOR
    Brandon Crabtree (used existing logic from past versions from John Hong and Doug Ruehrwein)

.NOTES
    Script Name : COTHelp.ps1
    Requires    : PowerShell 5+, Windows Presentation Framework, Fluence.Wpf.dll
    Purpose     : Assist end users and service desk staff with quick access to system info
                  and troubleshooting tools in a unified GUI.
#>

# ---------------------------------------------------------------------------
# Splash screen — runs in its own runspace so the main thread can gather data.
# Plain WPF Window (no Fluence dep needed here).
# ---------------------------------------------------------------------------
$splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Loading..."
        Width="300" Height="110"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        ResizeMode="NoResize"
        Background="#023c74"
        Topmost="True">
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Margin="20">
        <TextBlock Text="Gathering PC Information..."
                   Foreground="White" FontSize="15"
                   HorizontalAlignment="Center" Margin="0,0,0,14"/>
        <ProgressBar IsIndeterminate="True" Height="6" Width="240"
                     Background="Transparent" Foreground="White"/>
    </StackPanel>
</Window>
"@

Add-Type -AssemblyName PresentationCore, PresentationFramework

$sync = [hashtable]::Synchronized(@{})
$SplashRunspace = [runspacefactory]::CreateRunspace()
$SplashRunspace.ApartmentState = "STA"
$SplashRunspace.Open()

$ps = [powershell]::Create().AddScript({
    param($xaml, $sync)
    $Splash = [Windows.Markup.XamlReader]::Parse($xaml)
    $sync.Splash = $Splash
    $Splash.ShowDialog() | Out-Null
}).AddArgument($splashXaml).AddArgument($sync)

$ps.Runspace = $SplashRunspace
$ps.BeginInvoke() | Out-Null

# ---------------------------------------------------------------------------
# Load Fluence.Wpf
# ---------------------------------------------------------------------------
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -Path (Join-Path $scriptRoot "Fluence.Wpf.dll")

$app = [System.Windows.Application]::Current
if (-not $app) { $app = New-Object System.Windows.Application }

[Fluence.Wpf.ApplicationThemeManager]::Apply(
    [Fluence.Wpf.ApplicationTheme]::Auto,
    [Fluence.Wpf.BackdropType]::Mica,
    $true)

# COT brand blue as the accent
[Fluence.Wpf.ApplicationAccentColorManager]::ApplyCustomAccent(
    [System.Windows.Media.Color]::FromRgb(0x02, 0x3C, 0x74)
)

# ---------------------------------------------------------------------------
# XAML  Main Window
# ---------------------------------------------------------------------------
$xaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="COT Help"
    Padding="1"
    SizeToContent="WidthAndHeight"
    MinWidth="400"
    MinHeight="375"
    WindowStartupLocation="CenterScreen"
    Topmost="True"
    SystemBackdropType="Mica"
    ExtendsContentIntoTitleBar="True"
    Background="{DynamicResource LayerFillColorDefaultBrush}"
    CornerStyle="Round">

    <ui:FluenceWindow.Resources>
        <SolidColorBrush x:Key="AccentFillColorDefaultBrush"    Color="#023c74"/>
        <SolidColorBrush x:Key="AccentFillColorSecondaryBrush"  Color="#0c274a"/>
        <SolidColorBrush x:Key="AccentFillColorTertiaryBrush"   Color="#011f3c"/>
        <SolidColorBrush x:Key="AccentFillColorDisabledBrush"   Color="#023c74"/>

        <Style x:Key="ActionButton" TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance"          Value="Accent"/>
            <Setter Property="FontSize"            Value="13"/>
            <Setter Property="Padding"             Value="12,6"/>
            <Setter Property="Height"              Value="40"/>
            <Setter Property="MinWidth"            Value="190"/>
            <Setter Property="Margin"              Value="0,0,8,8"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
        </Style>

        <Style x:Key="UnifiedButton" TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance"          Value="Accent"/>
            <Setter Property="FontSize"            Value="14"/>
            <Setter Property="Padding"             Value="12,6"/>
            <Setter Property="Height"              Value="44"/>
            <Setter Property="MinWidth"            Value="200"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
        </Style>
    </ui:FluenceWindow.Resources>

    <ScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="24,20,24,24">

            <!-- Header -->
            <TextBlock Text="COT Help"
                       FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                       Margin="0,0,0,18"/>

            <!-- PC Info card -->
            <ui:Card Padding="16" Margin="0,0,0,14" Variant="Default">
                <StackPanel>
                    <TextBlock x:Name="ComputerName" FontSize="14"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="UserName"     FontSize="14"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,0,0,3"/>
                    <TextBlock x:Name="Model"        FontSize="14"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,0,0,3"/>

                    <Grid Margin="0,3,0,3">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="IPAddress"  Grid.Column="0" FontSize="14"
                                   Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                        <TextBlock x:Name="VPNStatus"  Grid.Column="1" FontSize="14"
                                   Foreground="{DynamicResource TextFillColorSecondaryBrush}"
                                   HorizontalAlignment="Right"/>
                    </Grid>

                    <TextBlock x:Name="DiskFreeSpace" FontSize="14"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,3,0,0"/>
                </StackPanel>
            </ui:Card>

            <!-- Action buttons -->
            <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,4">
                <ui:Button x:Name="CopyBtn"
                           Style="{StaticResource ActionButton}"
                           Content="Copy PC Information"/>
                <ui:Button x:Name="EmailBtn"
                           Style="{StaticResource ActionButton}"
                           Content="E-Mail Service Desk"/>
                <ui:Button x:Name="ExtendedReportBtn"
                           Style="{StaticResource ActionButton}"
                           Content="Extended System Report"/>
                <ui:Button x:Name="TicketBtn"
                           Style="{StaticResource ActionButton}"
                           Content="File Service Desk Ticket"/>
                <ui:Button x:Name="ChfsBtn"
                           Style="{StaticResource ActionButton}"
                           Content="CHFS Service Request"
                           Visibility="Collapsed"/>
                <ui:Button x:Name="AdminBtn"
                           Style="{StaticResource ActionButton}"
                           Content="Admin Tools"
                           Visibility="Collapsed"/>
            </WrapPanel>

            <!-- Close -->
            <ui:Button x:Name="CloseBtn"
                       Style="{StaticResource UnifiedButton}"
                       Content="Close"
                       Margin="0,10,0,0"/>

            <!-- Footer -->
            <Grid Margin="0,16,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="LastReboot"      Grid.Column="0" FontSize="12"
                           Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
                <TextBlock x:Name="FooterOSVersion" Grid.Column="1" FontSize="12"
                           Foreground="{DynamicResource TextFillColorSecondaryBrush}"
                           HorizontalAlignment="Right"/>
            </Grid>

        </StackPanel>
    </ScrollViewer>

</ui:FluenceWindow>
"@

# ---------------------------------------------------------------------------
# XAML  Extended Report Window
# ---------------------------------------------------------------------------
$extendedXaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="Extended Report"
    Width="560"
    SizeToContent="WidthAndHeight"
    MinWidth="480"
    MinHeight="400"
    WindowStartupLocation="CenterOwner"
    Topmost="True"
    ShowInTaskbar="False"
    SystemBackdropType="Mica"
    ExtendsContentIntoTitleBar="True"
    Background="Transparent"
    CornerStyle="Round"
    UseLayoutRounding="True">

    <ui:FluenceWindow.Resources>
        <SolidColorBrush x:Key="AccentFillColorDefaultBrush"   Color="#023c74"/>
        <SolidColorBrush x:Key="AccentFillColorSecondaryBrush" Color="#0c274a"/>
        <SolidColorBrush x:Key="AccentFillColorTertiaryBrush"  Color="#011f3c"/>
        <SolidColorBrush x:Key="AccentFillColorDisabledBrush"  Color="#023c74"/>

        <Style x:Key="UnifiedButton" TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance"          Value="Accent"/>
            <Setter Property="FontSize"            Value="14"/>
            <Setter Property="Padding"             Value="12,6"/>
            <Setter Property="Height"              Value="44"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
        </Style>
    </ui:FluenceWindow.Resources>

    <ui:SmoothScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="24,20,24,24">

            <TextBlock Text="Extended Report"
                       FontSize="22" FontWeight="Bold"
                       Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                       Margin="0,0,0,16"/>

            <ui:Card Padding="16" Margin="0,0,0,14" Variant="Default">
                <StackPanel>
                    <TextBlock Text="Mapped Drives" FontSize="13" FontWeight="SemiBold"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}" Margin="0,0,0,4"/>
                    <TextBlock x:Name="MappedDrivesText" FontSize="14" TextWrapping="Wrap"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,0,0,12"/>

                    <TextBlock Text="Printers" FontSize="13" FontWeight="SemiBold"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}" Margin="0,0,0,4"/>
                    <TextBlock x:Name="PrintersText" FontSize="14" TextWrapping="Wrap"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,0,0,12"/>

                    <TextBlock Text="Monitor Serial Numbers" FontSize="13" FontWeight="SemiBold"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}" Margin="0,0,0,4"/>
                    <TextBlock x:Name="MonitorSerialsText" FontSize="14" TextWrapping="Wrap"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}" Margin="0,0,0,12"/>

                    <TextBlock Text="GlobalProtect Version" FontSize="13" FontWeight="SemiBold"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}" Margin="0,0,0,4"/>
                    <TextBlock x:Name="GlobalProtectText" FontSize="14" TextWrapping="Wrap"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                </StackPanel>
            </ui:Card>

            <!-- Buttons -->
            <Grid Margin="0,4,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="8"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <ui:Button x:Name="CopyExtendedBtn" Grid.Column="0"
                           Style="{StaticResource UnifiedButton}"
                           Content="Copy Extended Report"/>
                <ui:Button x:Name="CloseExtendedBtn" Grid.Column="2"
                           Style="{StaticResource UnifiedButton}"
                           Content="Close"/>
            </Grid>

            <TextBlock Text="Extended details gathered live from this device."
                       FontSize="12" Margin="0,14,0,0"
                       Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
        </StackPanel>
    </ui:SmoothScrollViewer>
</ui:FluenceWindow>
"@

# ---------------------------------------------------------------------------
# XAML  Admin Toolbox Window
# ---------------------------------------------------------------------------
$adminXaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="Admin Toolbox"
    Width="500"
    SizeToContent="WidthAndHeight"
    MinWidth="420"
    MinHeight="340"
    WindowStartupLocation="CenterScreen"
    Topmost="True"
    SystemBackdropType="Mica"
    ExtendsContentIntoTitleBar="True"
    Background="Transparent"
    CornerStyle="Round"
    UseLayoutRounding="True">

    <ui:FluenceWindow.Resources>
        <SolidColorBrush x:Key="AccentFillColorDefaultBrush"   Color="#023c74"/>
        <SolidColorBrush x:Key="AccentFillColorSecondaryBrush" Color="#0c274a"/>
        <SolidColorBrush x:Key="AccentFillColorTertiaryBrush"  Color="#011f3c"/>
        <SolidColorBrush x:Key="AccentFillColorDisabledBrush"  Color="#023c74"/>

        <Style x:Key="UnifiedButton" TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance"          Value="Accent"/>
            <Setter Property="FontSize"            Value="14"/>
            <Setter Property="Padding"             Value="12,6"/>
            <Setter Property="Height"              Value="44"/>
            <Setter Property="MinWidth"            Value="190"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
            <Setter Property="Margin"              Value="0,0,8,8"/>
        </Style>

        <Style x:Key="WarnButton" TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance"          Value="Accent"/>
            <Setter Property="FontSize"            Value="14"/>
            <Setter Property="Padding"             Value="12,6"/>
            <Setter Property="Height"              Value="44"/>
            <Setter Property="MinWidth"            Value="190"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
            <Setter Property="Margin"              Value="0,0,8,8"/>
            <Setter Property="Background"          Value="#FFA000"/>
        </Style>

        <Style x:Key="DangerButton" TargetType="ui:Button"
               BasedOn="{StaticResource {x:Type ui:Button}}">
            <Setter Property="Appearance"          Value="Accent"/>
            <Setter Property="FontSize"            Value="14"/>
            <Setter Property="Padding"             Value="12,6"/>
            <Setter Property="Height"              Value="44"/>
            <Setter Property="MinWidth"            Value="190"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
            <Setter Property="Margin"              Value="0,0,8,8"/>
            <Setter Property="Background"          Value="#D32F2F"/>
        </Style>
    </ui:FluenceWindow.Resources>

    <ui:SmoothScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="24,20,24,24">

            <!-- Header with progress indicator -->
            <Grid Margin="0,0,0,18">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0"
                           Text="Admin Toolbox"
                           FontSize="26" FontWeight="Bold"
                           Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock x:Name="WorkText"
                               Text="Working..."
                               Visibility="Collapsed"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}"
                               VerticalAlignment="Center" Margin="0,0,8,0" FontSize="13"/>
                    <ui:ProgressRing x:Name="WorkRing"
                                     Width="20" Height="20"
                                     IsIndeterminate="True"
                                     Visibility="Collapsed"/>
                </StackPanel>
            </Grid>

            <!-- SCCM Client -->
            <TextBlock Text="SCCM Client"
                       FontSize="14" FontWeight="SemiBold"
                       Foreground="{DynamicResource TextFillColorSecondaryBrush}"
                       Margin="0,0,0,8"/>
            <ui:Card Padding="14" Margin="0,0,0,14" Variant="Default">
                <WrapPanel HorizontalAlignment="Center">
                    <ui:Button x:Name="BtnMachinePolicy"     Style="{StaticResource UnifiedButton}" Content="Trigger Machine Cycles"/>
                    <ui:Button x:Name="BtnAppDeploymentEval" Style="{StaticResource UnifiedButton}" Content="Trigger Application Cycles"/>
                    <ui:Button x:Name="BtnClientRepair"      Style="{StaticResource WarnButton}"    Content="Repair SCCM Client"/>
                    <ui:Button x:Name="BtnClientReinstall"   Style="{StaticResource DangerButton}"  Content="Reinstall SCCM Client"/>
                </WrapPanel>
            </ui:Card>

            <!-- Logs -->
            <TextBlock Text="Logs"
                       FontSize="14" FontWeight="SemiBold"
                       Foreground="{DynamicResource TextFillColorSecondaryBrush}"
                       Margin="0,0,0,8"/>
            <ui:Card Padding="14" Margin="0,0,0,14" Variant="Default">
                <WrapPanel HorizontalAlignment="Center">
                    <ui:Button x:Name="BtnSCCMLogs"  Style="{StaticResource UnifiedButton}" Content="Open CCM Logs"/>
                    <ui:Button x:Name="BtnPSADTLogs" Style="{StaticResource UnifiedButton}" Content="Open PSADT Logs"/>
                </WrapPanel>
            </ui:Card>

            <!-- Reports -->
            <TextBlock Text="Reports"
                       FontSize="14" FontWeight="SemiBold"
                       Foreground="{DynamicResource TextFillColorSecondaryBrush}"
                       Margin="0,0,0,8"/>
            <ui:Card Padding="14" Margin="0,0,0,14" Variant="Default">
                <WrapPanel HorizontalAlignment="Center">
                    <ui:Button x:Name="BtnReportSoftware"  Style="{StaticResource UnifiedButton}" Content="Save Software Report"/>
                    <ui:Button x:Name="BtnReportMappings"  Style="{StaticResource UnifiedButton}" Content="Save Mappings Report"/>
                    <ui:Button x:Name="BtnMigrationReport" Style="{StaticResource UnifiedButton}" Content="Save Migration Report"/>
                    <ui:Button x:Name="BtnReportBattery"   Style="{StaticResource UnifiedButton}" Content="Save Battery Report"/>
                </WrapPanel>
            </ui:Card>

            <!-- Close -->
            <ui:Button x:Name="CloseAdminBtn"
                       Appearance="Accent"
                       Content="Close"
                       FontSize="14" Height="44"
                       HorizontalAlignment="Stretch"
                       Margin="0,4,0,0"/>

            <TextBlock Text="EAS Admin Utilities  use carefully."
                       FontSize="12" Margin="0,14,0,0"
                       Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
        </StackPanel>
    </ui:SmoothScrollViewer>
</ui:FluenceWindow>
"@

# ---------------------------------------------------------------------------
# Parse windows
# ---------------------------------------------------------------------------
$window      = [System.Windows.Markup.XamlReader]::Parse($xaml)
$extWindow   = [System.Windows.Markup.XamlReader]::Parse($extendedXaml)
$adminWindow = [System.Windows.Markup.XamlReader]::Parse($adminXaml)

# ---------------------------------------------------------------------------
# Fix Fluence border misalignment for ALL windows
# ---------------------------------------------------------------------------
$window.add_ContentRendered({
    $window.InvalidateMeasure()
    $window.InvalidateVisual()
    $window.UpdateLayout()
})

$extWindow.add_ContentRendered({
    $extWindow.InvalidateMeasure()
    $extWindow.InvalidateVisual()
    $extWindow.UpdateLayout()
})

$adminWindow.add_ContentRendered({
    $adminWindow.InvalidateMeasure()
    $adminWindow.InvalidateVisual()
    $adminWindow.UpdateLayout()
})

# ---------------------------------------------------------------------------
# Theme watcher (unchanged)
# ---------------------------------------------------------------------------
[Fluence.Wpf.SystemThemeWatcher]::Watch($window)
$window.add_Closed({ [Fluence.Wpf.SystemThemeWatcher]::UnWatch($window) })


# ---------------------------------------------------------------------------
# Domain / admin detection
# ---------------------------------------------------------------------------
try { $domain = (Get-CimInstance Win32_ComputerSystem).Domain } catch { $domain = $null }

$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$IsAdmin   = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
$whoami    = (whoami)
$IsEASUser = $whoami.ToLower().StartsWith("eas\")

# ---------------------------------------------------------------------------
# Get PC Info
# ---------------------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem

function Get-PCInfo {
    $reg       = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $osVersion = "$($os.Caption) $($reg.DisplayVersion)"
    $system    = Get-CimInstance Win32_ComputerSystem
    $makeModel = "$($system.Manufacturer) $($system.Model)"

    $drive     = Get-Volume -DriveLetter C
    $freeGB    = [string][Math]::Round($drive.SizeRemaining / 1GB, 2) + "GB"

    $ipaddress = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "169.*" -and
            $_.IPAddress -ne "127.0.0.1" -and
            $_.InterfaceDescription -notmatch "Hyper-V" -and
            $_.InterfaceAlias -notlike "vEthernet*"
        } |
        Select-Object -ExpandProperty IPAddress

    $lastBoot  = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $lastReboot = (New-TimeSpan -Start $lastBoot -End (Get-Date)).Days.ToString() + " days ago"

    $gpAdapter  = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -like "*PANGP*" }
    $vpnStatus  = if ($gpAdapter) {
                      if ($gpAdapter.Status -eq "Up") { "GlobalProtect Connected" } else { "Disconnected" }
                  } else { "Uninstalled" }

    return @{
        ComputerName  = [System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).HostName
        Model         = $makeModel
        IPAddress     = $ipaddress
        DiskFreeSpace = $freeGB
        OSVersion     = $osVersion
        UserName      = whoami
        LastReboot    = $lastReboot
        VPNStatus     = $vpnStatus
    }
}

function Compose-ReportText {
    @"
ComputerName: $($ComputerInfo.ComputerName)
User: $($ComputerInfo.UserName)
Model: $($ComputerInfo.Model)
IP Address: $($ComputerInfo.IPAddress)
Free Disk Space: $($ComputerInfo.DiskFreeSpace)
OS Version: $($ComputerInfo.OSVersion)
VPN Status: $($ComputerInfo.VPNStatus)
Last Reboot: $($ComputerInfo.LastReboot)
"@
}

function Compose-CSDEmail {
    $subject = "Incident Request"
    $body    = "Pre-populated information:`r`n`r`nComputerName: $($ComputerInfo.ComputerName)`r`nModel: $($ComputerInfo.Model)`r`nIP Address: $($ComputerInfo.IPAddress)`r`nOS Version: $($ComputerInfo.OSVersion)`r`nFree Disk Space: $($ComputerInfo.DiskFreeSpace)`r`nUser: $($ComputerInfo.UserName)`r`nVPN Status: $($ComputerInfo.VPNStatus)"
    $mailto  = "mailto:commonwealthservicedesk@ky.gov?subject=$([uri]::EscapeDataString($subject))&body=$([uri]::EscapeDataString($body))"
    Start-Process $mailto
}

# ---------------------------------------------------------------------------
# Update main window UI
# ---------------------------------------------------------------------------
function Update-UI {
    param($info)
    $window.FindName("ComputerName").Text    = "Computer Name: $($info.ComputerName)"
    $window.FindName("UserName").Text        = "User: $($info.UserName)"
    $window.FindName("Model").Text           = "Model: $($info.Model)"
    $window.FindName("IPAddress").Text       = "IP Address: $($info.IPAddress)"
    $window.FindName("DiskFreeSpace").Text   = "Free Disk Space: $($info.DiskFreeSpace)"
    $window.FindName("FooterOSVersion").Text = "Windows Version: $($info.OSVersion)"
    $window.FindName("LastReboot").Text      = "Last Reboot: $($info.LastReboot)"
    $window.FindName("VPNStatus").Text       = "VPN Status: $($info.VPNStatus)"
}

function Build-UrlWithDescription {
    param([string]$BaseUrl, $info)
    $description     = "Username: $($ComputerInfo.UserName)`nComputerName: $($ComputerInfo.ComputerName)`nIP: $($ComputerInfo.IPAddress)`nModel: $($ComputerInfo.Model)`nFree Disk Space: $($ComputerInfo.DiskFreeSpace)`nWindows Version: $($ComputerInfo.OSVersion)`nLast Reboot: $($ComputerInfo.LastReboot)`nVPN Status: $($ComputerInfo.VPNStatus)"
    $encodedDesc     = [Uri]::EscapeDataString($description)
    if ($BaseUrl -match "\?") { return "$BaseUrl&sysparm_description=$encodedDesc" }
    else                      { return "$BaseUrl?sysparm_description=$encodedDesc" }
}

# ---------------------------------------------------------------------------
# Copy popup (plain WPF  no Fluence dep needed)
# ---------------------------------------------------------------------------
function Show-CopyPopup {
    param([string]$Message = "Copied to clipboard!")
    $popup = New-Object System.Windows.Window
    $popup.WindowStyle         = 'None'
    $popup.AllowsTransparency  = $true
    $popup.Background          = 'Transparent'
    $popup.SizeToContent       = 'WidthAndHeight'
    $popup.Topmost             = $true
    $popup.ShowInTaskbar       = $false
    $popup.Owner               = $window
    $popup.WindowStartupLocation = 'CenterOwner'

    $border            = New-Object System.Windows.Controls.Border
    $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#023c74')
    $border.CornerRadius = 8
    $border.Padding    = '20'
    $border.Margin     = '10'

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = 'Vertical'
    $stack.HorizontalAlignment = 'Center'

    $text              = New-Object System.Windows.Controls.TextBlock
    $text.Text         = $Message
    $text.Foreground   = [System.Windows.Media.Brushes]::White
    $text.FontSize     = 15
    $text.Margin       = '0,0,0,14'
    $text.HorizontalAlignment = 'Center'

    $okBtn             = New-Object System.Windows.Controls.Button
    $okBtn.Content     = "OK"
    $okBtn.Width       = 80
    $okBtn.Height      = 32
    $okBtn.Background  = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#0c274a')
    $okBtn.Foreground  = [System.Windows.Media.Brushes]::White
    $okBtn.FontSize    = 13
    $okBtn.HorizontalAlignment = 'Center'
    $okBtn.Add_Click({ $popup.Close() })

    $stack.Children.Add($text)
    $stack.Children.Add($okBtn)
    $border.Child  = $stack
    $popup.Content = $border
    $popup.ShowDialog() | Out-Null
}

# ---------------------------------------------------------------------------
# Extended report logic
# ---------------------------------------------------------------------------
function Get-ExtendedPCInfo {
    function Decode-MonitorBytes {
        param([object]$Bytes)
        if ($Bytes -is [System.Array] -and $Bytes.Length -gt 0) {
            $clean = $Bytes | Where-Object { $_ -ne 0 }
            [System.Text.Encoding]::ASCII.GetString($clean).Trim()
        } else { $null }
    }

    $monitors = @()
    try {
        $rawMonitors = Get-CimInstance -Namespace "root\WMI" -ClassName "WMIMonitorID" -ErrorAction Stop
        foreach ($m in $rawMonitors) {
            $name   = Decode-MonitorBytes $m.UserFriendlyName
            $serial = Decode-MonitorBytes $m.SerialNumberID
            if ($serial -or $name) { $monitors += "$name : $serial" }
        }
    } catch { $monitors = @("Monitor info not available") }

    $gpVersion = "Not Installed"
    try {
        $apps = foreach ($path in @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*GlobalProtect*" }
        }
        if ($apps) { $gpVersion = ($apps | Select-Object -ExpandProperty DisplayVersion -First 1) }
    } catch { $gpVersion = "Unavailable" }

    $mappedDrives = @()
    try {
        if (Test-Path "HKCU:\Network") {
            foreach ($drive in Get-ChildItem "HKCU:\Network") {
                $remote = Get-ItemPropertyValue -Path $drive.PSPath -Name RemotePath -ErrorAction SilentlyContinue
                if ($remote) { $mappedDrives += "$($drive.PSChildName) -> $remote" }
            }
        }
    } catch {}
    if (-not $mappedDrives -or $mappedDrives.Count -eq 0) { $mappedDrives = @("No mapped drives found") }

    $printers = @()
    try {
        foreach ($p in Get-Printer) {
            if ($p.Name -notmatch 'PDF|Microsoft|Fax|OneNote') {
                $printers += "$($p.Name) (Port: $($p.PortName))"
            }
        }
    } catch {}
    try {
        if (Test-Path "HKCU:\Printers\Connections") {
            $mapped = Get-ChildItem "HKCU:\Printers\Connections" | ForEach-Object {
                "\\$($_.PSChildName -replace ',', '\')"
            }
            if ($mapped) { $printers += $mapped }
        }
    } catch {}
    if (-not $printers -or $printers.Count -eq 0) { $printers = @("No printers found") }

    return @{
        MappedDrives   = $mappedDrives
        Printers       = $printers
        MonitorSerials = $monitors
        GlobalProtect  = $gpVersion
    }
}

function Update-ExtendedUI {
    param($extWindow, $info)
    $extWindow.FindName("GlobalProtectText").Text = if ($info.GlobalProtect) { $info.GlobalProtect } else { "(none)" }
    $extWindow.FindName("MappedDrivesText").Text  = if ($info.MappedDrives -and $info.MappedDrives.Count) {
        ($info.MappedDrives | ForEach-Object { "  $_" }) -join "`r`n"
    } else { "  (none)" }
    $extWindow.FindName("PrintersText").Text = if ($info.Printers -and $info.Printers.Count) {
        ($info.Printers | ForEach-Object { "  $_" }) -join "`r`n"
    } else { "  (none)" }
    $extWindow.FindName("MonitorSerialsText").Text = if ($info.MonitorSerials -and $info.MonitorSerials.Count) {
        ($info.MonitorSerials | ForEach-Object { "  $_" }) -join "`r`n"
    } else { "  (none)" }
}

function Compose-MainPcInfoText {
    param($ComputerInfo)
    @"
Computer Name: $($ComputerInfo.ComputerName)
User: $($ComputerInfo.UserName)
Model: $($ComputerInfo.Model)
IP Address: $($ComputerInfo.IPAddress)
Free Disk Space: $($ComputerInfo.DiskFreeSpace)
OS Version: $($ComputerInfo.OSVersion)
VPN Status: $($ComputerInfo.VPNStatus)
Last Reboot: $($ComputerInfo.LastReboot)
"@
}

function Compose-ExtendedReportText {
    param($ExtendedInfo)
    function Join-Lines([string[]]$items) {
        if (-not $items -or $items.Count -eq 0) { return "  (none)" }
        return ($items | ForEach-Object { "  $_" }) -join "`r`n"
    }
    @"
Mapped Drives:
$(Join-Lines $ExtendedInfo.MappedDrives)

Printers:
$(Join-Lines $ExtendedInfo.Printers)

Monitor Serial Numbers:
$(Join-Lines $ExtendedInfo.MonitorSerials)
GlobalProtect Version: $(if ($ExtendedInfo.GlobalProtect) { "  $($ExtendedInfo.GlobalProtect)" } else { "  (none)" })
"@
}

function Compose-FullExtendedReportText {
    param($ComputerInfo, $ExtendedInfo)
    $header = Compose-MainPcInfoText -ComputerInfo $ComputerInfo
    $ext    = Compose-ExtendedReportText -ExtendedInfo $ExtendedInfo
    return "$header`r`n$ext"
}

# ---------------------------------------------------------------------------
# Admin report helpers (unchanged logic, same as original)
# ---------------------------------------------------------------------------
function Get-MappingsAllUsers {
    $results = @()
    function Get-UsernameFromSID {
        param([string]$SID)
        try {
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
            return $objSID.Translate([System.Security.Principal.NTAccount]).Value
        } catch { return "Unknown" }
    }
    $userSIDs = Get-ChildItem Registry::HKEY_USERS | Where-Object {
        ($_ -notmatch '_Classes$') -and ($_ -notmatch '^S-1-5-18$') -and
        ($_ -notmatch '^S-1-5-19$') -and ($_ -notmatch '^S-1-5-20$')
    }
    foreach ($sid in $userSIDs) {
        $sidStr   = $sid.PSChildName
        $username = Get-UsernameFromSID $sidStr
        $networkKeyPath = "Registry::HKEY_USERS\$sidStr\Network"
        if (Test-Path $networkKeyPath) {
            $results += [PSCustomObject]@{ Section="Mapped Drives"; Username=""; Type=""; Identifier=""; Target=""; Error="" }
            foreach ($drive in Get-ChildItem $networkKeyPath) {
                $remote = Get-ItemPropertyValue -Path $drive.PSPath -Name RemotePath -ErrorAction SilentlyContinue
                $results += [PSCustomObject]@{ Section=""; Username=$username; Type="MappedDrive"; Identifier=$drive.PSChildName; Target=$remote; Error="" }
            }
            $results += [PSCustomObject]@{ Section=""; Username=""; Type=""; Identifier=""; Target=""; Error="" }
        }
        $printerKeyPath = "Registry::HKEY_USERS\$sidStr\Printers\Connections"
        if (Test-Path $printerKeyPath) {
            $results += [PSCustomObject]@{ Section="Printers (Registry)"; Username=""; Type=""; Identifier=""; Target=""; Error="" }
            foreach ($printer in Get-ChildItem $printerKeyPath) {
                $results += [PSCustomObject]@{ Section=""; Username=$username; Type="Printer"; Identifier=($printer.PSChildName -replace ",","\"); Target=""; Error="" }
            }
            $results += [PSCustomObject]@{ Section=""; Username=""; Type=""; Identifier=""; Target=""; Error="" }
        }
    }
    try {
        $localPrinters = Get-Printer | Select-Object Name, PortName
        if ($localPrinters) {
            $results += [PSCustomObject]@{ Section="Local Printers (IP Mapped)"; Username=""; Type=""; Identifier=""; Target=""; Error="" }
            foreach ($p in $localPrinters) {
                if ($p.Name -notmatch 'PDF|Microsoft|Fax|OneNote') {
                    $results += [PSCustomObject]@{ Section=""; Username=$env:USERNAME; Type="LocalPrinter"; Identifier=$p.Name; Target=$p.PortName; Error="" }
                }
            }
            $results += [PSCustomObject]@{ Section=""; Username=""; Type=""; Identifier=""; Target=""; Error="" }
        }
    } catch {}
    return $results
}

function Get-Software {
    $results = @()
    foreach ($path in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                         "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
        $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.DisplayVersion }
        foreach ($app in $apps) {
            $results += [PSCustomObject]@{ Product=$app.DisplayName; Version=$app.DisplayVersion }
        }
    }
    return $results
}

function Write-ReportText {
    [CmdletBinding()]
    param([string]$Path, [string]$SectionName, [object[]]$Results, [switch]$Append)
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine("=== $SectionName ===")
    $null = $sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $null = $sb.AppendLine()
    foreach ($item in $Results) {
        if     ($item.Type -eq "MappedDrive")   { $null = $sb.AppendLine("User: $($item.Username)  Type: $($item.Type)  Drive: $($item.Identifier)  Target: $($item.Target)") }
        elseif ($item.Type -eq "Printer")       { $null = $sb.AppendLine("User: $($item.Username)  Type: $($item.Type)  Printer: $($item.Identifier)") }
        elseif ($item.Type -eq "LocalPrinter")  { $null = $sb.AppendLine("User: $($item.Username)  Type: $($item.Type)  Printer: $($item.Identifier)  Port: $($item.Target)") }
        elseif ($item.PSObject.Properties.Name -contains "Product") { $null = $sb.AppendLine("Product: $($item.Product)  Version: $($item.Version)") }
    }
    $null = $sb.AppendLine()
    if ($Append) { $sb.ToString() | Out-File -FilePath $Path -Append -Encoding UTF8 }
    else         { $sb.ToString() | Out-File -FilePath $Path -Encoding UTF8 }
}

function Write-MigrationReportText {
    param([string]$Path)
    Write-ReportText -Path $Path -SectionName "Mapped Drives and Printers" -Results (Get-MappingsAllUsers)
    Write-ReportText -Path $Path -SectionName "Software Inventory"         -Results (Get-Software) -Append
}

function Get-DesktopPath { [Environment]::GetFolderPath('Desktop') }

function Show-SaveDialog {
    param([string]$Title, [string]$DefaultFileName, [string]$Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*")
    Add-Type -AssemblyName PresentationFramework
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Title            = $Title
    $dlg.InitialDirectory = Get-DesktopPath
    $dlg.FileName         = $DefaultFileName
    $dlg.Filter           = $Filter
    if ($dlg.ShowDialog()) { return $dlg.FileName } else { return $null }
}

function Show-Working {
    if ($workText) { $workText.Text = "Working..."; $workText.Visibility = "Visible" }
    if ($ring)     { $ring.IsActive = $true;        $ring.Visibility     = "Visible" }
    foreach ($b in @($btnLogs,$btnPsadt,$btnMachine,$btnAppEval,$btnRepair,$btnReinstall,
                      $btnReportSoftware,$btnReportMappings,$btnMigrationReport,$btnReportBattery,$btnClose)) {
        if ($b) { $b.IsEnabled = $false }
    }
}
function Hide-Working {
    if ($ring)     { $ring.IsActive = $false; $ring.Visibility    = "Collapsed" }
    if ($workText) { $workText.Visibility = "Collapsed" }
    foreach ($b in @($btnLogs,$btnPsadt,$btnMachine,$btnAppEval,$btnRepair,$btnReinstall,
                      $btnReportSoftware,$btnReportMappings,$btnMigrationReport,$btnReportBattery,$btnClose)) {
        if ($b) { $b.IsEnabled = $true }
    }
}

# ---------------------------------------------------------------------------
# SCCM functions
# ---------------------------------------------------------------------------
function Invoke-MachinePolicy {
    try {
        Invoke-CimMethod -Namespace root\ccm -ClassName SMS_Client -MethodName TriggerSchedule -Arguments @{sScheduleID="{00000000-0000-0000-0000-000000000021}"}
        Invoke-CimMethod -Namespace root\ccm -ClassName SMS_Client -MethodName TriggerSchedule -Arguments @{sScheduleID="{00000000-0000-0000-0000-000000000022}"}
        [System.Windows.MessageBox]::Show("Machine Policy Retrieval & Evaluation triggered.", "SCCM")
    } catch {
        [System.Windows.MessageBox]::Show("Failed to trigger machine policy.`n$($_.Exception.Message)", "SCCM Error")
    }
}

function Invoke-AppPolicy {
    try {
        Invoke-CimMethod -Namespace root\ccm -ClassName SMS_Client -MethodName TriggerSchedule -Arguments @{sScheduleID="{00000000-0000-0000-0000-000000000121}"}
        [System.Windows.MessageBox]::Show("Software Update Scan triggered.", "SCCM")
    } catch {
        [System.Windows.MessageBox]::Show("Failed to trigger Software Update Scan.`n$($_.Exception.Message)", "SCCM Error")
    }
}

function Invoke-SCCMRepair {
    param([System.Windows.Controls.TextBlock]$WorkText)
    $choice = [System.Windows.MessageBox]::Show("Run ccmrepair.exe to repair the SCCM client?", "Repair SCCM Client",
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($choice -ne [System.Windows.MessageBoxResult]::Yes) { return }
    if ($WorkText) { $WorkText.Text = "Repairing SCCM client..." }
    Show-Working
    $job = Start-Job -ScriptBlock {
        try {
            $repairExe = "$env:WINDIR\CCM\ccmrepair.exe"
            if (-not (Test-Path $repairExe)) { throw "ccmrepair.exe not found at $repairExe." }
            & $repairExe | Out-Null; "OK"
        } catch { $_.Exception.Message }
    }
    Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
        if ($Event.SourceEventArgs.JobStateInfo.State -eq 'Completed') {
            $result = Receive-Job $Event.Sender; Remove-Job $Event.Sender; Hide-Working
            if ($result -eq "OK") { [System.Windows.MessageBox]::Show($adminWindow, "Repair initiated. Verify in ccmsetup.log.", "SCCM Client Repair") }
            else                  { [System.Windows.MessageBox]::Show($adminWindow, "Repair failed.`n$result", "SCCM Client Repair Error") }
        }
    } | Out-Null
}

function Invoke-SCCMReinstall {
    param([System.Windows.Controls.TextBlock]$WorkText,
          [string]$SiteCode = "COK",
          [string]$MpFqdn   = "ent1vp-apsc005.eas.ds.ky.gov",
          [string]$Source   = "\\ent1vp-apsc005.eas.ds.ky.gov\Client")
    $choice = [System.Windows.MessageBox]::Show("This will uninstall, then reinstall the SCCM client. Continue?", "Reinstall SCCM Client",
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($choice -ne [System.Windows.MessageBoxResult]::Yes) { return }
    if ($WorkText) { $WorkText.Text = "Reinstalling SCCM client..." }
    Show-Working
    $job = Start-Job -ScriptBlock {
        try {
            $ccmsetupPath = "$env:WINDIR\ccmsetup\ccmsetup.exe"
            if (Test-Path $ccmsetupPath) { & $ccmsetupPath /uninstall | Out-Null }
            Start-Sleep -Seconds 5
            Get-Service -Name CcmExec -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
            foreach ($p in @("$env:WINDIR\CCM","$env:WINDIR\CCMSetup","$env:WINDIR\CCMCache")) {
                if (Test-Path $p) { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $installExe = "$env:WINDIR\ccmsetup\ccmsetup.exe"
            if (-not (Test-Path $installExe) -and (Test-Path (Join-Path $using:Source "ccmsetup.exe"))) {
                $installExe = (Join-Path $using:Source "ccmsetup.exe")
            }
            if (-not (Test-Path $installExe)) { throw "Unable to locate CCMSetup.exe. Verify source path: $using:Source" }
            $installArgs = @()
            if ($using:MpFqdn)  { $installArgs += "/mp:$using:MpFqdn" }
            $installArgs += "/logon"
            if (Test-Path $using:Source) { $installArgs += "/source:$using:Source" }
            if ($using:SiteCode) { $installArgs += "SMSSITECODE=$using:SiteCode" }
            if ($using:MpFqdn)   { $installArgs += "SMSMP=$using:MpFqdn" }
            & $installExe $installArgs | Out-Null; "OK"
        } catch { $_.Exception.Message }
    }
    Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
        if ($Event.SourceEventArgs.JobStateInfo.State -eq 'Completed') {
            $result = Receive-Job $Event.Sender; Remove-Job $Event.Sender; Hide-Working
            if ($result -eq "OK") { [System.Windows.MessageBox]::Show($adminWindow, "Reinstall initiated. Verify in ccmsetup.log.", "SCCM Client Reinstall") }
            else                  { [System.Windows.MessageBox]::Show($adminWindow, "Reinstall failed.`n$result", "SCCM Client Reinstall Error") }
        }
    } | Out-Null
}

function Invoke-SoftwareReport {
    try {
        $out = Show-SaveDialog -Title "Save Software Report" -DefaultFileName "SoftwareReport_$env:COMPUTERNAME.txt" -Filter "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        if (-not $out) { return }
        Write-ReportText -Path $out -SectionName "Software Inventory" -Results (Get-Software)
        Show-CopyPopup -Message "Software report saved:`n$out"
    } catch { [System.Windows.MessageBox]::Show("Software report failed.`n$($_.Exception.Message)", "Reports Error") }
}

function Invoke-MappedDrivePrinterAllUsersReport {
    try {
        $out = Show-SaveDialog -Title "Save Mappings Report" -DefaultFileName "MappingsReport_$env:COMPUTERNAME.txt" -Filter "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        if (-not $out) { return }
        Write-ReportText -Path $out -SectionName "Mapped Drives and Printers" -Results (Get-MappingsAllUsers)
        Show-CopyPopup -Message "Mappings report saved:`n$out"
    } catch { [System.Windows.MessageBox]::Show("Mappings report failed.`n$($_.Exception.Message)", "Reports Error") }
}

function Invoke-MigrationReport {
    try {
        $out = Show-SaveDialog -Title "Migration Report" -DefaultFileName "MigrationReport_$env:COMPUTERNAME.txt" -Filter "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        if (-not $out) { return }
        Write-MigrationReportText -Path $out
        Show-CopyPopup -Message "Migration report saved:`n$out"
    } catch { [System.Windows.MessageBox]::Show("Migration report failed.`n$($_.Exception.Message)", "Reports Error") }
}

# ---------------------------------------------------------------------------
# Populate main window and wire buttons
# ---------------------------------------------------------------------------
$ComputerInfo = Get-PCInfo
Update-UI $ComputerInfo

$window.FindName("CloseBtn").Add_Click({
    if ($extWindow -and $extWindow.IsVisible) { $extWindow.Close() }
    $window.Close()
    exit
})

$window.FindName("CopyBtn").Add_Click({
    Set-Clipboard -Value (Compose-ReportText)
    Show-CopyPopup -Message "PC info copied to clipboard."
})

$window.FindName("EmailBtn").Add_Click({ Compose-CSDEmail })

$window.FindName("ExtendedReportBtn").Add_Click({
    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait

    try {
        Show-ExtendedReport
    }
    finally {
        [System.Windows.Input.Mouse]::OverrideCursor = $null
    }
})


$window.FindName("TicketBtn").Add_Click({
    $url = Build-UrlWithDescription -BaseUrl "https://cotportal.service-now.com/sp?id=sc_cat_item&sys_id=ca63b7e81b79b700c88b7661cd4bcbfe" -info $ComputerInfo
    Start-Process $url
})

$ChfsBtn = $window.FindName("ChfsBtn")
if ($domain -like "chfs.ds.ky.gov") { $ChfsBtn.Visibility = "Visible" }
$ChfsBtn.Add_Click({ Start-Process "https://cotportal.service-now.com/chfs?id=chfs_sc_cat_item&sys_id=a7ae63fedb8595945ab1c59b13961991" })

$AdminBtn = $window.FindName("AdminBtn")
if ($IsAdmin) { $AdminBtn.Visibility = "Visible" } else { $AdminBtn.Visibility = "Collapsed" }

# ---------------------------------------------------------------------------
# Extended window
# ---------------------------------------------------------------------------
function Show-ExtendedReport {
    $extWindow = [Windows.Markup.XamlReader]::Parse($extendedXaml)
    $extWindow.Add_ContentRendered({
    $extWindow.UpdateLayout()
    $extWindow.Width  = $extWindow.ActualWidth
    $extWindow.Height = $extWindow.ActualHeight
    $extWindow.UpdateLayout()
    })

    $ExtendedInfo = Get-ExtendedPCInfo
    Update-ExtendedUI $extWindow $ExtendedInfo

    $extWindow.FindName("CloseExtendedBtn").Add_Click({
        param($sender, $args)
        $win = [System.Windows.Window]::GetWindow($sender)
        if ($win) { $win.Close() }
    })

    $extWindow.FindName("CopyExtendedBtn").Add_Click({
        [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
        $fresh = Get-ExtendedPCInfo
        [System.Windows.Clipboard]::SetText((Compose-FullExtendedReportText -ComputerInfo $script:ComputerInfo -ExtendedInfo $fresh))
        [System.Windows.Input.Mouse]::OverrideCursor = $null
        Show-CopyPopup -Message "Extended PC info copied to clipboard."
    })
    $extWindow.Add_ContentRendered({
    [System.Windows.Input.Mouse]::OverrideCursor = $null
    })
    $extWindow.ShowDialog()
}

# ---------------------------------------------------------------------------
# Admin toolbox window
# ---------------------------------------------------------------------------
$window.FindName("AdminBtn").Add_Click({
    try {
        $btnClose           = $adminWindow.FindName("CloseAdminBtn")
        $btnLogs            = $adminWindow.FindName("BtnSCCMLogs")
        $btnPsadt           = $adminWindow.FindName("BtnPSADTLogs")
        $btnMachine         = $adminWindow.FindName("BtnMachinePolicy")
        $btnAppEval         = $adminWindow.FindName("BtnAppDeploymentEval")
        $btnRepair          = $adminWindow.FindName("BtnClientRepair")
        $btnReinstall       = $adminWindow.FindName("BtnClientReinstall")
        $btnReportSoftware  = $adminWindow.FindName("BtnReportSoftware")
        $btnReportMappings  = $adminWindow.FindName("BtnReportMappings")
        $btnMigrationReport = $adminWindow.FindName("BtnMigrationReport")
        $btnReportBattery   = $adminWindow.FindName("BtnReportBattery")
        $ring               = $adminWindow.FindName("WorkRing")
        $workText           = $adminWindow.FindName("WorkText")

        if ($btnClose)           { $btnClose.Add_Click({ $adminWindow.Close() }) }
        if ($btnLogs)            { $btnLogs.Add_Click({ $p = "C:\Windows\CCM\Logs"; if (Test-Path $p) { Start-Process $p } else { [System.Windows.MessageBox]::Show("Path not found: $p","SCCM Logs") } }) }
        if ($btnPsadt)           { $btnPsadt.Add_Click({ $p = "C:\Windows\Logs\Software"; if (Test-Path $p) { Start-Process $p } else { [System.Windows.MessageBox]::Show("Path not found: $p","PSADT Logs") } }) }
        if ($btnMachine) {
        $btnMachine.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-MachinePolicy }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnAppEval) {
        $btnAppEval.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-AppPolicy }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnRepair) {
        $btnRepair.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-SCCMRepair -WorkText $workText }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnReinstall) {
        $btnReinstall.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-SCCMReinstall -WorkText $workText }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnReportSoftware) {
        $btnReportSoftware.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-SoftwareReport }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnReportMappings) {
        $btnReportMappings.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-MappedDrivePrinterAllUsersReport }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnMigrationReport) {
        $btnMigrationReport.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try   { Invoke-MigrationReport }
            finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
        })
    }

    if ($btnReportBattery) {
        $btnReportBattery.Add_Click({
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            try {
                $htmlPath = Show-SaveDialog -Title "Save Battery Report (HTML)" -DefaultFileName "BatteryReport_$env:COMPUTERNAME.html" -Filter "HTML files (*.html)|*.html|All files (*.*)|*.*"
                if (-not $htmlPath) { return }
                & powercfg /batteryreport /output "$htmlPath" | Out-Null
                Show-CopyPopup -Message "Battery report saved:`n$htmlPath"
            }
            catch {
                [System.Windows.MessageBox]::Show("Battery report failed.`n$($_.Exception.Message)", "Reports Error")
            }
            finally {
                [System.Windows.Input.Mouse]::OverrideCursor = $null
            }
        })
    }
        $adminWindow.Topmost = $true
        $null = $adminWindow.ShowDialog()
        Start-Sleep -Milliseconds 50
        $adminWindow.Topmost = $false

    } catch {
        [System.Windows.MessageBox]::Show("Admin Panel failed to open.`n`n$($_.Exception.Message)", "Admin Panel Error")
    }
})

# ---------------------------------------------------------------------------
# Close splash and show main window
# ---------------------------------------------------------------------------
$sync.Splash.Dispatcher.Invoke([action]{ $sync.Splash.Close() })

$window.add_Closed({
    # Shut down the WPF dispatcher
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()

    # End the PowerShell runspace
    [System.Environment]::Exit(0)
})

[void]$app.Run($window)
