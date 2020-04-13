Add-Type -AssemblyName System.Runtime.WindowsRuntime
$AsTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
[Windows.Devices.WiFi.WiFiAdapter,Windows.Devices.WiFi,ContentType = WindowsRuntime]

#Required to utilise UWP async methods
Function Wait-RunTimeTask($WinRtTask, $ResultType) 
{
    #https://fleexlab.blogspot.com/2018/02/using-winrts-iasyncoperation-in.html
    $AsTask = $AsTaskGeneric.MakeGenericMethod($ResultType)
    $NetTask = $AsTask.Invoke($null, @($WinRtTask))
    $NetTask.Wait(-1) | Out-Null
    $NetTask.Result
}

<#
 .Synopsis
  Gets the WiFi Adapter.

 .Description
  Gets the WiFi Adapter.

 .Example
   # Get the WiFi Adapter.
   Get-WiFiAdapter
#>

Function Get-WiFiAdapter
{
    [CmdletBinding()]
    param()
    #Check that we have access to the Adapters
    if(Wait-RunTimeTask ([Windows.Devices.WiFi.WiFiAdapter]::RequestAccessAsync()) ([Windows.Devices.WiFi.WiFiAccessStatus]))
    {
        #Check that there is a WiFi adaptor
        if($WiFiAdapterList = Wait-RunTimeTask ([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync([Windows.Devices.WiFi.WiFiAdapter]::GetDeviceSelector())) ([Windows.Devices.Enumeration.DeviceInformationCollection]))
        {
            #Grab the first WiFi adapter ID
            Wait-RunTimeTask ([Windows.Devices.WiFi.WiFiAdapter]::FromIdAsync($WiFiAdapterList[0].Id)) ([Windows.Devices.WiFi.WiFiAdapter])
        }
        else
        {
            throw "No adapters found"
        }
    }
    else
    {
        throw "Access denied"
    }
}

<#
 .Synopsis
  Gets the available WiFi Networks.

 .Description
  Gets the available WiFi Networks. Use Invoke-WiFiScan prior to calling this function to populate the available networks list.

 .Example
   # Get the WiFi Networks.
   Get-WiFiNetworks
#>

Function Get-WiFiNetworks
{
    [CmdletBinding()]
    param()

    (Get-WiFiAdapter).NetworkReport.AvailableNetworks
}

<#
 .Synopsis
  Scans for available WiFi Networks.

 .Description
  Scans for available WiFi Networks.

 .Example
   # Scan for WiFi networks
   Invoke-WiFiScan
#>

Function Invoke-WiFiScan
{
    [CmdletBinding()]
    param()
    
    [Void](Get-WiFiAdapter).ScanAsync()
}

<#
 .Synopsis
  Connect to a specific WiFi Network.

 .Description
  Scans for available WiFi Networks.

 .Parameter AvailableNetwork
  An available network returned object returned from Get-WiFiNetworks

 .Parameter ReconnectionKind
  Whether to reconnect to the WiFi network automatically or manually

 .Parameter Password
  Password for WiFi network

 .Example
   # Connect to the WiFi network with the SSID that matches "MyWiFi" using the password 'SuperSecretPassword'
   Connect-WiFi -AvailableNetwork (Get-WiFiNetworks | Where-Object { $_.SSID -match "MyWiFi" }) -Password "SuperSecretPassword"
#>

Function Connect-WiFi
{
    param
    (
        [Parameter(Mandatory=$true)]
        [Windows.Devices.WiFi.WiFiAvailableNetwork]
        $AvailableNetwork,

        [Windows.Devices.WiFi.WiFiReconnectionKind]
        [ValidateSet("Automatic","Manual")]
        $ReconnectionKind = "Manual",
        
        [String]
        $Password = ''
    )

    $Credential = [Windows.Security.Credentials.PasswordCredential]::new()
    $Credential.Password = $Password
    Wait-RunTimeTask ((Get-WiFiAdapter).ConnectAsync($AvailableNetwork, $ReconnectionKind, $Credential)) ([Windows.Devices.WiFi.WiFiConnectionResult])
}

<#
 .Synopsis
  Disconnect from the current WiFi Network.

 .Description
  Disconnect from the current WiFi Network.

 .Example
  Disconnect-WiFi
#>
Function Disconnect-WiFi
{
    (Get-WiFiAdapter).Disconnect()
}

Export-ModuleMember -Function Get-WiFiAdapter
Export-ModuleMember -Function Get-WiFiNetworks
Export-ModuleMember -Function Invoke-WiFiScan
Export-ModuleMember -Function Connect-WiFi
Export-ModuleMember -Function Disconnect-WiFi
