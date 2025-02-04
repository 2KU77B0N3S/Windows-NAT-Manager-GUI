# =========================
# NAT Manager GUI for Windows Systems
# =========================

# Following prerequisites are required
#Requires -Version 5.1
#Requires -Modules NetNat
#Requires -RunAsAdministrator

# Check for PowerShell version 5.1 or later
if ($PSVersionTable.PSVersion -lt [Version]"5.1") {
    [System.Windows.Forms.MessageBox]::Show(
        "This script requires PowerShell version 5.1 or later. You are running version $($PSVersionTable.PSVersion).",
        "Requirement Not Met",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Check if the required module 'NetNat' is available
if (-not (Get-Module -ListAvailable -Name NetNat)) {
    [System.Windows.Forms.MessageBox]::Show(
        "The required module 'NetNat' is not available. Please install the module before running this script.",
        "Requirement Not Met",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Check if the script is running with administrator privileges
$currentUser = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show(
        "This script must be run as an Administrator.",
        "Administrator Privileges Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Load necessary assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import Win32 functions to hide the console
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll", ExactSpelling = true)]
    public static extern IntPtr GetConsoleWindow();
}
"@

# Minimize (hide) the PowerShell console
$consolePtr = [Win32]::GetConsoleWindow()
[Win32]::ShowWindow($consolePtr, 0)  # 0 = Hide

# =========================
# MAIN FORM (Static Mappings)
# =========================

$form = New-Object System.Windows.Forms.Form
$form.Text = "NAT Static Mapping Manager"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Size = New-Object System.Drawing.Size(840, 520)  # Slightly taller to fit help text
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# GroupBox for Static Mappings DataGridView
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Text = "Existing NAT Mappings"
$groupBox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$groupBox.Location = New-Object System.Drawing.Point(10, 10)
$groupBox.Size = New-Object System.Drawing.Size(800, 290)
$form.Controls.Add($groupBox)

# DataGridView for Static Mappings
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Size = New-Object System.Drawing.Size(760, 240)
$dataGridView.Location = New-Object System.Drawing.Point(15, 25)
$dataGridView.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$dataGridView.AllowUserToAddRows = $false
$dataGridView.ReadOnly = $true
$dataGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$dataGridView.MultiSelect = $false

# DataGridView styling
$dataGridView.EnableHeadersVisualStyles = $false
$dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(225,225,225)
$dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
$dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dataGridView.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::WhiteSmoke
$dataGridView.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::LightSteelBlue
$dataGridView.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
$groupBox.Controls.Add($dataGridView)

# Panel for main form buttons
$buttonPanel = New-Object System.Windows.Forms.Panel
$buttonPanel.Location = New-Object System.Drawing.Point(10, 310)
$buttonPanel.Size = New-Object System.Drawing.Size(800, 50)
$form.Controls.Add($buttonPanel)

# Buttons: Add/Edit/Delete/Close
$addButton = New-Object System.Windows.Forms.Button
$addButton.Text = "Add"
$addButton.Size = New-Object System.Drawing.Size(75, 30)
$addButton.Location = New-Object System.Drawing.Point(0, 10)

$editButton = New-Object System.Windows.Forms.Button
$editButton.Text = "Edit"
$editButton.Size = New-Object System.Drawing.Size(75, 30)
$editButton.Location = New-Object System.Drawing.Point(90, 10)

$deleteButton = New-Object System.Windows.Forms.Button
$deleteButton.Text = "Delete"
$deleteButton.Size = New-Object System.Drawing.Size(75, 30)
$deleteButton.Location = New-Object System.Drawing.Point(180, 10)

# NAT Networks button
$natNetworksButton = New-Object System.Windows.Forms.Button
$natNetworksButton.Text = "NAT Network"
$natNetworksButton.Size = New-Object System.Drawing.Size(100, 30)
$natNetworksButton.Location = New-Object System.Drawing.Point(270, 10)

# Close button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Size = New-Object System.Drawing.Size(75, 30)
$closeButton.Location = New-Object System.Drawing.Point(380, 10)
$closeButton.Add_Click({ $form.Close() })

$buttonPanel.Controls.Add($addButton)
$buttonPanel.Controls.Add($editButton)
$buttonPanel.Controls.Add($deleteButton)
$buttonPanel.Controls.Add($natNetworksButton)
$buttonPanel.Controls.Add($closeButton)

# ToolTips
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.SetToolTip($addButton, "Add a new NAT mapping")
$toolTip.SetToolTip($editButton, "Edit the selected NAT mapping")
$toolTip.SetToolTip($deleteButton, "Delete the selected NAT mapping")
$toolTip.SetToolTip($natNetworksButton, "Manage NAT Networks")
$toolTip.SetToolTip($closeButton, "Close this window")

# --- Add a label to display info about NAT fields, at bottom ---
$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.AutoSize = $false
$infoLabel.Width = 800
$infoLabel.Height = 90
$infoLabel.Location = New-Object System.Drawing.Point(10, 370)
$infoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$infoLabel.Text = @"
NAT Name: The name of your NAT Network. (Use the 'NAT Network' button above to manage networks.)
External IP Address: By default 0.0.0.0, which covers all external IPs.
External Port: The external port used for NAT.
Internal Port: The internal port used for NAT.
Protocol: TCP or UDP.
"@
$form.Controls.Add($infoLabel)

# --- FOOTER LABEL (Main Form) ---
$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.AutoSize = $true
$footerLabel.Location = New-Object System.Drawing.Point(10, 470)
$footerLabel.Text = "Copyright: Shadow Architect | Discord: shadow_architect_ | Support me: https://bit.ly/ShadowArchitect"
$form.Controls.Add($footerLabel)

# --- Input Dialog for Static Mappings ---
function Show-InputDialog {
    param (
        [string]$title,
        [hashtable]$defaults = @{ }
    )
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $title
    $dialog.Size = New-Object System.Drawing.Size(300, 350)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $controls = @{}
    $y = 10
    foreach ($field in @("NatName", "ExternalIPAddress", "ExternalPort", "InternalIPAddress", "InternalPort", "Protocol")) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $field
        $label.Location = New-Object System.Drawing.Point(10, $y)
        $label.Size = New-Object System.Drawing.Size(120, 20)
        $dialog.Controls.Add($label)

        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Text = $defaults[$field] -as [string]
        $textBox.Location = New-Object System.Drawing.Point(140, $y)
        $textBox.Size = New-Object System.Drawing.Size(120, 20)
        $dialog.Controls.Add($textBox)

        $controls[$field] = $textBox
        $y += 30
    }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(60, $y)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dialog.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(140, $y)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dialog.Controls.Add($cancelButton)

    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return @(
            $controls["NatName"].Text,
            $controls["ExternalIPAddress"].Text,
            $controls["ExternalPort"].Text,
            $controls["InternalIPAddress"].Text,
            $controls["InternalPort"].Text,
            $controls["Protocol"].Text
        )
    }
    else {
        return $null
    }
}

# --- Load Static NAT Mappings ---
function Load-NatMappings {
    $dataGridView.DataSource = $null
    $mappings = Get-NetNatStaticMapping | ForEach-Object {
        [PSCustomObject]@{
            ID                = $_.StaticMappingID
            NatName           = $_.NatName
            Protocol          = $_.Protocol
            ExternalIPAddress = $_.ExternalIPAddress
            ExternalPort      = $_.ExternalPort
            InternalIPAddress = $_.InternalIPAddress
            InternalPort      = $_.InternalPort
            Active            = $_.Active
        }
    }
    $dataTable = New-Object System.Data.DataTable
    if ($mappings.Count -gt 0) {
        $mappings[0].PSObject.Properties.Name | ForEach-Object { $dataTable.Columns.Add($_) }
        $mappings | ForEach-Object {
            $row = $dataTable.NewRow()
            $_.PSObject.Properties | ForEach-Object { $row.($_.Name) = $_.Value }
            $dataTable.Rows.Add($row)
        }
    }
    $dataGridView.DataSource = $dataTable
}

# --- Static Mapping Button Click Handlers ---
$addButton.Add_Click({
    $result = Show-InputDialog -title "Add New NAT Mapping"
    if ($result) {
        $natName, $externalIP, $externalPort, $internalIP, $internalPort, $protocol = $result
        try {
            Add-NetNatStaticMapping -NatName $natName -ExternalIPAddress $externalIP -ExternalPort $externalPort `
                -InternalIPAddress $internalIP -InternalPort $internalPort -Protocol $protocol -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("New mapping added successfully.", "Info")
            Load-NatMappings
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error adding mapping: $($_.Exception.Message)", "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

$editButton.Add_Click({
    $selectedRow = $dataGridView.CurrentRow
    if ($selectedRow) {
        $defaults = @{
            "NatName"           = $selectedRow.Cells["NatName"].Value
            "ExternalIPAddress" = $selectedRow.Cells["ExternalIPAddress"].Value
            "ExternalPort"      = $selectedRow.Cells["ExternalPort"].Value
            "InternalIPAddress" = $selectedRow.Cells["InternalIPAddress"].Value
            "InternalPort"      = $selectedRow.Cells["InternalPort"].Value
            "Protocol"          = $selectedRow.Cells["Protocol"].Value
        }
        $result = Show-InputDialog -title "Edit NAT Mapping" -defaults $defaults
        if ($result) {
            $natName, $externalIP, $externalPort, $internalIP, $internalPort, $protocol = $result
            $id = $selectedRow.Cells["ID"].Value
            try {
                Remove-NetNatStaticMapping -StaticMappingID $id -Confirm:$false -ErrorAction Stop
                Add-NetNatStaticMapping -NatName $natName -ExternalIPAddress $externalIP -ExternalPort $externalPort `
                    -InternalIPAddress $internalIP -InternalPort $internalPort -Protocol $protocol -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Mapping updated successfully.", "Info")
                Load-NatMappings
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error editing mapping: $($_.Exception.Message)", "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("No mapping selected.", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$deleteButton.Add_Click({
    $selectedRow = $dataGridView.CurrentRow
    if ($selectedRow) {
        $id = $selectedRow.Cells["ID"].Value
        try {
            Remove-NetNatStaticMapping -StaticMappingID $id -Confirm:$false -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("Mapping deleted successfully.", "Info")
            Load-NatMappings
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error deleting mapping: $($_.Exception.Message)", "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("No mapping selected.", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Load initial static mappings
Load-NatMappings

# =========================
# NAT NETWORKS MANAGEMENT FORM
# =========================

function Show-NatNetworksForm {

    # Check if WinNAT service is installed. If not, show error and return.
    # If installed but not running, ask the user whether to start it.
    try {
        $winnatService = Get-Service -Name 'WinNAT' -ErrorAction Stop
        if ($winnatService.Status -ne 'Running') {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "WinNAT Service not running. Do you want to start it to proceed?",
                "WinNAT Service",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-Service -Name 'WinNAT'
                Start-Sleep -Seconds 2
            }
            else {
                return  # user chose No => do not open form
            }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "The WinNAT service is not installed or cannot be accessed.
The NAT Networks Manager cannot continue without WinNAT.",
            "WinNAT Service Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    # Create NAT networks form
    $natForm = New-Object System.Windows.Forms.Form
    $natForm.Text = "NAT Networks Manager"
    $natForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $natForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $natForm.MaximizeBox = $false
    $natForm.MinimizeBox = $false
    $natForm.Size = New-Object System.Drawing.Size(840, 500)
    $natForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # GroupBox for NAT networks
    $natGroupBox = New-Object System.Windows.Forms.GroupBox
    $natGroupBox.Text = "NAT Networks"
    $natGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $natGroupBox.Location = New-Object System.Drawing.Point(10, 10)
    $natGroupBox.Size = New-Object System.Drawing.Size(800, 350)
    $natForm.Controls.Add($natGroupBox)
    
    # DataGridView for NAT networks
    $natDataGrid = New-Object System.Windows.Forms.DataGridView
    $natDataGrid.Size = New-Object System.Drawing.Size(760, 310)
    $natDataGrid.Location = New-Object System.Drawing.Point(15, 25)
    $natDataGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $natDataGrid.AllowUserToAddRows = $false
    $natDataGrid.ReadOnly = $true
    $natDataGrid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $natDataGrid.MultiSelect = $false

    # Styling
    $natDataGrid.EnableHeadersVisualStyles = $false
    $natDataGrid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(225,225,225)
    $natDataGrid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
    $natDataGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $natDataGrid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::WhiteSmoke
    $natDataGrid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::LightSteelBlue
    $natDataGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
    $natGroupBox.Controls.Add($natDataGrid)
    
    # Panel for NAT Networks form buttons
    $natButtonPanel = New-Object System.Windows.Forms.Panel
    $natButtonPanel.Location = New-Object System.Drawing.Point(10, 370)
    $natButtonPanel.Size = New-Object System.Drawing.Size(800, 50)
    $natForm.Controls.Add($natButtonPanel)
    
    $natAddButton = New-Object System.Windows.Forms.Button
    $natAddButton.Text = "Add"
    $natAddButton.Size = New-Object System.Drawing.Size(75, 30)
    $natAddButton.Location = New-Object System.Drawing.Point(0, 10)
    
    $natEditButton = New-Object System.Windows.Forms.Button
    $natEditButton.Text = "Edit"
    $natEditButton.Size = New-Object System.Drawing.Size(75, 30)
    $natEditButton.Location = New-Object System.Drawing.Point(90, 10)
    
    $natDeleteButton = New-Object System.Windows.Forms.Button
    $natDeleteButton.Text = "Delete"
    $natDeleteButton.Size = New-Object System.Drawing.Size(75, 30)
    $natDeleteButton.Location = New-Object System.Drawing.Point(180, 10)
    
    $natRefreshButton = New-Object System.Windows.Forms.Button
    $natRefreshButton.Text = "Refresh"
    $natRefreshButton.Size = New-Object System.Drawing.Size(75, 30)
    $natRefreshButton.Location = New-Object System.Drawing.Point(270, 10)
    
    $natCloseButton = New-Object System.Windows.Forms.Button
    $natCloseButton.Text = "Close"
    $natCloseButton.Size = New-Object System.Drawing.Size(75, 30)
    $natCloseButton.Location = New-Object System.Drawing.Point(360, 10)
    $natCloseButton.Add_Click({ $natForm.Close() })
    
    $natButtonPanel.Controls.Add($natAddButton)
    $natButtonPanel.Controls.Add($natEditButton)
    $natButtonPanel.Controls.Add($natDeleteButton)
    $natButtonPanel.Controls.Add($natRefreshButton)
    $natButtonPanel.Controls.Add($natCloseButton)
    
    $natToolTip = New-Object System.Windows.Forms.ToolTip
    $natToolTip.SetToolTip($natAddButton, "Add a new NAT network")
    $natToolTip.SetToolTip($natEditButton, "Edit the selected NAT network")
    $natToolTip.SetToolTip($natDeleteButton, "Delete the selected NAT network")
    $natToolTip.SetToolTip($natRefreshButton, "Refresh the NAT networks list")
    $natToolTip.SetToolTip($natCloseButton, "Close this window")

    # --- Custom Input Dialog for NAT Networks (Wider) ---
    function Show-NatNetworkInputDialog {
        param (
            [string]$title,
            [hashtable]$defaults = @{ }
        )
        $dialog = New-Object System.Windows.Forms.Form
        $dialog.Text = $title
        $dialog.Size = New-Object System.Drawing.Size(420, 250)
        $dialog.StartPosition = "CenterParent"
        $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false
        $dialog.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
        $controls = @{}
        $y = 10
        $fields = @(
            "Name",
            "InternalIPInterfaceAddressPrefix",
            "ExternalIPInterfaceAddressPrefix"
        )
    
        foreach ($field in $fields) {
            $label = New-Object System.Windows.Forms.Label
            $label.Text = $field
            $label.Location = New-Object System.Drawing.Point(10, $y)
            $label.Size = New-Object System.Drawing.Size(200, 20)
            $dialog.Controls.Add($label)
    
            $textBox = New-Object System.Windows.Forms.TextBox
            $textBox.Text = $defaults[$field] -as [string]
            $textBox.Location = New-Object System.Drawing.Point(220, $y)
            $textBox.Size = New-Object System.Drawing.Size(180, 20)
            $dialog.Controls.Add($textBox)
    
            $controls[$field] = $textBox
            $y += 30
        }
    
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Location = New-Object System.Drawing.Point(100, $y)
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Controls.Add($okButton)
    
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Cancel"
        $cancelButton.Location = New-Object System.Drawing.Point(200, $y)
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $dialog.Controls.Add($cancelButton)
    
        $dialog.AcceptButton = $okButton
        $dialog.CancelButton = $cancelButton
    
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return @(
                $controls["Name"].Text,
                $controls["InternalIPInterfaceAddressPrefix"].Text,
                $controls["ExternalIPInterfaceAddressPrefix"].Text
            )
        }
        else {
            return $null
        }
    }

    # --- Load NAT Networks ---
    function Load-NatNetworks {
        $natDataGrid.DataSource = $null
        $natList = @(Get-NetNat | ForEach-Object {
            [PSCustomObject]@{
                Name                             = $_.Name
                ExternalIPInterfaceAddressPrefix = $_.ExternalIPInterfaceAddressPrefix
                InternalIPInterfaceAddressPrefix = $_.InternalIPInterfaceAddressPrefix
                IcmpQueryTimeout                 = $_.IcmpQueryTimeout
                TcpEstablishedConnectionTimeout  = $_.TcpEstablishedConnectionTimeout
                TcpTransientConnectionTimeout    = $_.TcpTransientConnectionTimeout
                TcpFilteringBehavior             = $_.TcpFilteringBehavior
                UdpFilteringBehavior             = $_.UdpFilteringBehavior
                UdpIdleSessionTimeout            = $_.UdpIdleSessionTimeout
                UdpInboundRefresh                = $_.UdpInboundRefresh
                Store                            = $_.Store
                Active                           = $_.Active
            }
        })
    
        $dt = New-Object System.Data.DataTable
        if ($natList.Count -gt 0) {
            $natList[0].PSObject.Properties.Name | ForEach-Object { $dt.Columns.Add($_) }
            foreach ($item in $natList) {
                $row = $dt.NewRow()
                $item.PSObject.Properties | ForEach-Object { $row.($_.Name) = $_.Value }
                $dt.Rows.Add($row)
            }
        }
        $natDataGrid.DataSource = $dt
    }
    
    # Add NAT Network
    $natAddButton.Add_Click({
        # ICS/HNS check
        $icsService = Get-Service -Name SharedAccess -ErrorAction SilentlyContinue
        $hnsService = Get-Service -Name hns -ErrorAction SilentlyContinue

        $needToDisable = $false
        if (($icsService -and $icsService.Status -eq 'Running') -or
            ($hnsService -and $hnsService.Status -eq 'Running')) {
            $needToDisable = $true
        }

        if ($needToDisable) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Windows Services ICS and Host Network Service are running. Do you want to stop and disable them?",
                "ICS/HNS Detected",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                try {
                    # Disable and stop HNS
                    Set-Service -Name hns -StartupType Disabled
                    Stop-Service -Name hns -Confirm:$false
                    # Disable and stop ICS
                    Stop-Service -Name SharedAccess -Confirm:$false
                    Set-Service -Name SharedAccess -StartupType Disabled
                } catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Failed to stop/disable ICS or HNS: $($_.Exception.Message)",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                    return
                }
            } else {
                return
            }
        }

        # Show the Add NAT Network dialog
        $defaults = @{
            "Name"                             = "EXAMPLE"
            "InternalIPInterfaceAddressPrefix" = "192.168.0.0/24"
            "ExternalIPInterfaceAddressPrefix" = ""
        }
        $input = Show-NatNetworkInputDialog -title "Add New NAT Network" -defaults $defaults
        if ($input) {
            try {
                $params = @{
                    Name                             = $input[0]
                    InternalIPInterfaceAddressPrefix = $input[1]
                }
                if ($input[2]) {
                    $params["ExternalIPInterfaceAddressPrefix"] = $input[2]
                }
                New-NetNat @params -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show(
                    "New NAT network added successfully.",
                    "Info",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                Load-NatNetworks
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Error adding NAT network: $($_.Exception.Message)",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    })
    
    # Edit NAT Network
    $natEditButton.Add_Click({
        $selectedRow = $natDataGrid.CurrentRow
        if ($selectedRow) {
            $defaults = @{
                "Name" = $selectedRow.Cells["Name"].Value
                "InternalIPInterfaceAddressPrefix" = $selectedRow.Cells["InternalIPInterfaceAddressPrefix"].Value
                "ExternalIPInterfaceAddressPrefix" = $selectedRow.Cells["ExternalIPInterfaceAddressPrefix"].Value
            }
            $input = Show-NatNetworkInputDialog -title "Edit NAT Network" -defaults $defaults
            if ($input) {
                try {
                    $netName = $selectedRow.Cells["Name"].Value
                    Remove-NetNat -Name $netName -Confirm:$false -ErrorAction Stop

                    $params = @{
                        Name = $input[0]
                        InternalIPInterfaceAddressPrefix = $input[1]
                    }
                    if ($input[2]) {
                        $params["ExternalIPInterfaceAddressPrefix"] = $input[2]
                    }
                    New-NetNat @params -ErrorAction Stop

                    [System.Windows.Forms.MessageBox]::Show(
                        "NAT network updated successfully.",
                        "Info",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                    Load-NatNetworks
                } catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Error editing NAT network: $($_.Exception.Message)",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No NAT network selected.",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })
    
    # Delete NAT Network
    $natDeleteButton.Add_Click({
        $selectedRow = $natDataGrid.CurrentRow
        if ($selectedRow) {
            $netName = $selectedRow.Cells["Name"].Value
            if ($netName) {
                try {
                    Remove-NetNat -Name $netName -Confirm:$false -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show("NAT network deleted successfully.", "Info")
                    Load-NatNetworks
                } catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Error deleting NAT network: $($_.Exception.Message)",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No NAT network selected.",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    # Refresh NAT Networks
    $natRefreshButton.Add_Click({
        Load-NatNetworks
    })

    # Load initial NAT networks data
    Load-NatNetworks

    # --- FOOTER LABEL (NAT Networks Form) ---
    $natFooterLabel = New-Object System.Windows.Forms.Label
    $natFooterLabel.AutoSize = $true
    $natFooterLabel.Location = New-Object System.Drawing.Point(10, 430)
    $natFooterLabel.Text = "Copyright: Shadow Architect | Discord: shadow_architect_ | Support me: https://bit.ly/ShadowArchitect"
    $natForm.Controls.Add($natFooterLabel)

    # Show the NAT Networks form
    [void]$natForm.ShowDialog()
}

# NAT Networks Button on the Main Form
$natNetworksButton.Add_Click({
    Show-NatNetworksForm
})

# Show the main form
[void]$form.ShowDialog()
