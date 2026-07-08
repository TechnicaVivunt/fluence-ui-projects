<#
Combined BitLocker + LAPS Lookup Tool
Fluent UI by Fluence
#>

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -Path (Join-Path $scriptRoot "Fluence.Wpf.dll")

$app = [System.Windows.Application]::Current
if (-not $app) {
    $app = New-Object System.Windows.Application
}

[Fluence.Wpf.ApplicationThemeManager]::Apply(
    [Fluence.Wpf.ApplicationTheme]::Auto,
    [Fluence.Wpf.BackdropType]::Mica,
    $true)

[Fluence.Wpf.ApplicationAccentColorManager]::ApplyCustomAccent(
    [System.Windows.Media.Color]::FromRgb(0x02, 0x3C, 0x74)
)


Import-Module ActiveDirectory -ErrorAction Stop

# -----------------------------
# XAML
# -----------------------------
$xaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="Support Tools"
    Width="820"
    Height="675"
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
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Height" Value="44"/>
            <Setter Property="MinWidth" Value="200"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
        </Style>

        <!-- Section card style -->
        <Style x:Key="SectionCard" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource LayerFillColorDefaultBrush}"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,24"/>
        </Style>

    </ui:FluenceWindow.Resources>


    <!-- PAGE LAYOUT -->
    <DockPanel>

        <!-- Bottom Navigation -->
        <StackPanel DockPanel.Dock="Bottom"
                    Orientation="Horizontal"
                    HorizontalAlignment="Center"
                    Margin="0,20,0,20">

            <ui:Button x:Name="BtnBitLocker"
                       Style="{StaticResource UnifiedButton}"
                       Content="BitLocker"
                       Margin="6,0"/>

            <ui:Button x:Name="BtnLAPS"
                       Style="{StaticResource UnifiedButton}"
                       Content="LAPS"
                       Margin="6,0"/>

            <ui:Button x:Name="BtnClose"
                       Style="{StaticResource UnifiedButton}"
                       Content="Close"
                       Margin="6,0"/>
        </StackPanel>


        <!-- MAIN CONTENT AREA -->
            <StackPanel Margin="40,32,40,24"
                        Width="700"
                        HorizontalAlignment="Center">

                <!-- PAGE HEADER -->
                <StackPanel Margin="0,0,0,24">
                    <TextBlock Text="Support Toolbox"
                               ui:TextBlockExtensions.Typography="TitleLarge"
                               FontSize="30"
                               FontWeight="Bold"
                               Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>

                    <TextBlock x:Name="Subtitle"
                               Text="Ready"
                               ui:TextBlockExtensions.Typography="Subtitle"
                               FontSize="16"
                               Margin="0,6,0,0"
                               Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
                </StackPanel>


                <!-- BITLOCKER PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="BitLockerPanel">

                    <StackPanel>

                        <TextBlock Text="BitLocker Recovery Lookup"
                                   ui:TextBlockExtensions.Typography="Subtitle"
                                   FontSize="20"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,16"/>

                        <TextBlock Text="Computer Name:"
                                   ui:TextBlockExtensions.Typography="Body"/>
                        <TextBox x:Name="BL_ComputerInput"
                                 Height="32"
                                 Margin="0,0,0,12"/>

                        <TextBlock Text="Recovery GUID (optional):"
                                   ui:TextBlockExtensions.Typography="Body"/>
                        <TextBox x:Name="BL_GUIDInput"
                                 Height="32"
                                 Margin="0,0,0,16"/>

                        <ui:Button x:Name="BL_LookupBtn"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Lookup Recovery Keys"/>

                        <Border Background="{DynamicResource LayerFillColorDefaultBrush}"
                                CornerRadius="6"
                                Padding="10"
                                Margin="0,20,0,0">

                            <TextBox x:Name="BL_OutputBox"
                                     AcceptsReturn="True"
                                     VerticalScrollBarVisibility="Auto"
                                     BorderThickness="0"
                                     Background="Transparent"
                                     Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                                     IsReadOnly="True"
                                     TextWrapping="Wrap"
                                     Height="125"/>
                        </Border>


                    </StackPanel>

                </Border>


                <!-- LAPS PANEL -->
                <Border Style="{StaticResource SectionCard}"
                        x:Name="LAPSPanel"
                        Visibility="Collapsed">

                    <StackPanel>

                        <TextBlock Text="Windows LAPS Password Lookup"
                                   ui:TextBlockExtensions.Typography="Subtitle"
                                   FontSize="20"
                                   FontWeight="SemiBold"
                                   Margin="0,0,0,16"/>

                        <TextBlock Text="Computer Name:"
                                   ui:TextBlockExtensions.Typography="Body"/>
                        <TextBox x:Name="LAPS_ComputerInput"
                                 Height="32"
                                 Margin="0,0,0,12"/>

                        <ui:Button x:Name="LAPS_LookupBtn"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Query LAPS Password"/>

                        <ui:Button x:Name="LAPS_ExpireBtn"
                                   Style="{StaticResource UnifiedButton}"
                                   Content="Expire LAPS Password"
                                   Margin="0,12,0,0"/>

                        <Border Background="{DynamicResource LayerFillColorDefaultBrush}"
                                CornerRadius="6"
                                Padding="10"
                                Margin="0,20,0,0">

                            <TextBox x:Name="LAPS_OutputBox"
                                     AcceptsReturn="True"
                                     VerticalScrollBarVisibility="Auto"
                                     BorderThickness="0"
                                     Background="Transparent"
                                     Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                                     IsReadOnly="True"
                                     TextWrapping="Wrap"
                                     Height="100"/>
                        </Border>

                    </StackPanel>

                </Border>

            </StackPanel>
    </DockPanel>

</ui:FluenceWindow>

"@


[xml]$xml = $xaml
$window = [System.Windows.Markup.XamlReader]::Parse($xaml)


# Controls
$BtnBitLocker = $window.FindName("BtnBitLocker")
$BtnLAPS = $window.FindName("BtnLAPS")
$BtnClose = $window.FindName("BtnClose")
$Subtitle = $window.FindName("Subtitle")

$BitLockerPanel = $window.FindName("BitLockerPanel")
$LAPSPanel = $window.FindName("LAPSPanel")

$BL_ComputerInput = $window.FindName("BL_ComputerInput")
$BL_GUIDInput = $window.FindName("BL_GUIDInput")
$BL_LookupBtn = $window.FindName("BL_LookupBtn")
$BL_OutputBox = $window.FindName("BL_OutputBox")

$LAPS_ComputerInput = $window.FindName("LAPS_ComputerInput")
$LAPS_LookupBtn = $window.FindName("LAPS_LookupBtn")
$LAPS_ExpireBtn = $window.FindName("LAPS_ExpireBtn")
$LAPS_OutputBox = $window.FindName("LAPS_OutputBox")

# Panel switching
$BtnBitLocker.Add_Click({
    $BitLockerPanel.Visibility = "Visible"
    $LAPSPanel.Visibility = "Collapsed"
    $Subtitle.Text = "BitLocker Mode"
})

$BtnLAPS.Add_Click({
    $BitLockerPanel.Visibility = "Collapsed"
    $LAPSPanel.Visibility = "Visible"
    $Subtitle.Text = "LAPS Mode"
})

$BtnClose.Add_Click({ $window.Close() })

# -----------------------------
# BitLocker function
# -----------------------------
function Get-BitLockerRecoveryKey {
    param([string]$ComputerName)

    try {
        $gc = "$((Get-ADForest).RootDomainNamingContext):3268"
        $searchName = "$ComputerName$"

        $objComputer = Get-ADComputer -Filter "sAMAccountName -eq '$searchName'" `
            -Server $gc `
            -Properties DNSHostName -ErrorAction Stop

        $domain = ($objComputer.DistinguishedName -replace '^.+?,DC=', '' -replace ',DC=', '.')

        $Bitlocker_Object = Get-ADObject -Filter { objectclass -eq 'msFVE-RecoveryInformation' } `
            -SearchBase $objComputer.DistinguishedName `
            -Properties 'msFVE-RecoveryPassword','msFVE-RecoveryGuid','whenCreated' `
            -Server $domain

        if ($Bitlocker_Object) {
            return $Bitlocker_Object | Sort-Object whenCreated -Descending | ForEach-Object {
                [PSCustomObject]@{
                    ComputerName = $ComputerName
                    RecoveryGuid = [Guid]($_.'msFVE-RecoveryGuid')
                    RecoveryKey  = $_.'msFVE-RecoveryPassword'
                    Published    = $_.whenCreated
                }
            }
        }
        else {
            return "No BitLocker recovery information found."
        }
    }
    catch {
        return "Error: $_"
    }
}

# -----------------------------
# UPDATED CLICK (FILTER HERE)
# -----------------------------
$BL_LookupBtn.Add_Click({
    $name = $BL_ComputerInput.Text.Trim()
    $guid = $BL_GUIDInput.Text.Trim()

    if (-not $name) {
        $BL_OutputBox.Text = "Please enter a computer name."
        return
    }

    if ($guid) {
        $guid = $guid -replace '[{} ]',''
        $Subtitle.Text = "BitLocker → $name (Filtered)"
    } else {
        $Subtitle.Text = "BitLocker → $name"
    }

    $BL_OutputBox.Text = "Querying Active Directory..."

    $result = Get-BitLockerRecoveryKey -ComputerName $name

    if ($result -is [string]) {
        $BL_OutputBox.Text = $result
        return
    }

    # Apply filter ONLY if GUID provided
    if ($guid) {
        $result = $result | Where-Object {
            $_.RecoveryGuid.ToString() -like "*$guid*"
        }

        if (-not $result) {
            $BL_OutputBox.Text = "No matching recovery key found for that GUID."
            return
        }
    }

    $BL_OutputBox.FontFamily = "Consolas"

    $BL_OutputBox.Text = (
        $result | ForEach-Object {
@"
Computer Name : $($_.ComputerName)
Recovery GUID : $($_.RecoveryGuid)
Recovery Key  : $($_.RecoveryKey)
Published Date: $($_.Published)
"@
        }
    ) -join "`r`n"
})

# -----------------------------
# LAPS logic
# -----------------------------
function LAPS_WriteLog {
    param([string]$Message)
    $LAPS_OutputBox.Text += "$Message`r`n"
}

function Find-ComputerInForest {
    param([string]$Name)
    try {
        return Get-ADComputer -Filter "Name -eq '$Name'" -Server "ds.ky.gov:3268"
    }
    catch {
        LAPS_WriteLog "Forest search failed: $($_.Exception.Message)"
        return $null
    }
}

function Get-WindowsLapsPassword {
    param([string]$Name, [string]$Domain)
    try {
        return Get-LapsADPassword -Identity $Name -DomainController $Domain -AsPlainText
    }
    catch {
        LAPS_WriteLog "LAPS retrieval failed: $($_.Exception.Message)"
        return $null
    }
}

$LAPS_LookupBtn.Add_Click({
    $LAPS_OutputBox.Text = ""
    $hostname = $LAPS_ComputerInput.Text.Trim()

    if (-not $hostname) {
        LAPS_WriteLog "Please enter a computer name."
        return
    }

    $Subtitle.Text = "LAPS → $hostname"

    $comp = Find-ComputerInForest -Name $hostname
    if (-not $comp) {
        LAPS_WriteLog "Computer not found."
        return
    }

    $domain = ($comp.DistinguishedName -split "DC=" | Select-Object -Skip 1) -replace ",","" -join "."

    $laps = Get-WindowsLapsPassword -Name $hostname -Domain $domain
    if (-not $laps) {
        LAPS_WriteLog "Unable to retrieve LAPS password."
        return
    }

    LAPS_WriteLog "Computer Name: $hostname"
    LAPS_WriteLog "Password: $($laps.Password)"
    LAPS_WriteLog "Expires:  $($laps.PasswordUpdateTime)"
})

$LAPS_ExpireBtn.Add_Click({
    $LAPS_OutputBox.Text = ""
    $hostname = $LAPS_ComputerInput.Text.Trim()

    if (-not $hostname) {
        LAPS_WriteLog "Please enter a computer name."
        return
    }

    $Subtitle.Text = "LAPS Expire → $hostname"
    LAPS_WriteLog "Expiring LAPS password → $hostname..."

    try {
        Invoke-Command -ComputerName $hostname -ScriptBlock { Reset-LapsPassword }
        LAPS_WriteLog "Password expiration request sent successfully."
        LAPS_WriteLog "The device will rotate its password on next policy refresh."
    }
    catch {
        LAPS_WriteLog "Failed to expire password: $($_.Exception.Message)"
    }
})

$window.add_Closed({
    # Shut down the WPF dispatcher
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()

    # End the PowerShell runspace
    [System.Environment]::Exit(0)
})

# Show
[void]$app.Run($window)