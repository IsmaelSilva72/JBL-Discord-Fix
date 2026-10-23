# JBL Discord Audio Fix
# Força saída no JBL (A2DP) e entrada no microfone do notebook
# Evita que o Bluetooth mude para perfil HFP (áudio abafado)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
internal class MMDeviceEnumeratorClass { }

[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
    // ...
}

[ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IMMDeviceCollection {
    int GetCount(out int count);
    int Item(int index, out IMMDevice device);
}

[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IMMDevice {
    int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    int OpenPropertyStore(int access, out IPropertyStore props);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetState(out int state);
}

[ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IPropertyStore {
    int GetCount(out int count);
    int GetAt(int index, out PropertyKey key);
    int GetValue(ref PropertyKey key, out PropVariant value);
    // ...
}

[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey {
    public Guid fmtid;
    public int pid;
    public PropertyKey(Guid fmtid, int pid) { this.fmtid = fmtid; this.pid = pid; }
}

[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
    [FieldOffset(0)] public short vt;
    [FieldOffset(8)] public IntPtr pwszVal;
    public string AsString() {
        if (vt == 31) return Marshal.PtrToStringUni(pwszVal);
        return "";
    }
}

[ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IPolicyConfig {
    // cycled methods to reach SetDefaultEndpoint at index 12
    int unused1(); int unused2(); int unused3(); int unused4();
    int unused5(); int unused6(); int unused7(); int unused8();
    int unused9(); int unused10(); int unused11();
    int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int role);
}

[ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
internal class PolicyConfigClient { }

public class AudioDeviceManager {
    private static readonly PropertyKey PKEY_DeviceFriendlyName = new PropertyKey(
        new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), 14);

    public static string[] ListDevices(int dataFlow) {
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
        IMMDeviceCollection collection;
        enumerator.EnumAudioEndpoints(dataFlow, 1, out collection); // 1 = ACTIVE
        int count;
        collection.GetCount(out count);
        var results = new string[count];
        for (int i = 0; i < count; i++) {
            IMMDevice device;
            collection.Item(i, out device);
            string id;
            device.GetId(out id);
            IPropertyStore props;
            device.OpenPropertyStore(0, out props);
            PropVariant name;
            var key = PKEY_DeviceFriendlyName;
            props.GetValue(ref key, out name);
            results[i] = id + "|" + name.AsString();
        }
        return results;
    }

    public static string GetDefaultDevice(int dataFlow) {
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
        IMMDevice device;
        enumerator.GetDefaultAudioEndpoint(dataFlow, 0, out device);
        string id;
        device.GetId(out id);
        IPropertyStore props;
        device.OpenPropertyStore(0, out props);
        PropVariant name;
        var key = PKEY_DeviceFriendlyName;
        props.GetValue(ref key, out name);
        return id + "|" + name.AsString();
    }

    public static void SetDefaultDevice(string deviceId) {
        var policy = (IPolicyConfig)new PolicyConfigClient();
        policy.SetDefaultEndpoint(deviceId, 0); // eConsole
        policy.SetDefaultEndpoint(deviceId, 1); // eMultimedia
        policy.SetDefaultEndpoint(deviceId, 2); // eCommunications
    }
}
'@ -ErrorAction Stop

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   JBL Discord Audio Fix                     ║" -ForegroundColor Cyan
    Write-Host "  ║   Corrige audio abafado no Discord           ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Current defaults
    try {
        $outDefault = [AudioDeviceManager]::GetDefaultDevice(0)  # eRender
        $inDefault  = [AudioDeviceManager]::GetDefaultDevice(1)  # eCapture
        $outName = $outDefault.Split('|',2)[1]
        $inName  = $inDefault.Split('|',2)[1]
        Write-Host "  Saida atual:   $outName" -ForegroundColor Yellow
        Write-Host "  Entrada atual: $inName" -ForegroundColor Yellow
    } catch {
        Write-Host "  (nao foi possivel ler dispositivos atuais)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  [1] Aplicar fix (JBL Stereo = saida, JBL mic = entrada)" -ForegroundColor Green
    Write-Host "  [2] Listar dispositivos de saida" -ForegroundColor White
    Write-Host "  [3] Listar dispositivos de entrada" -ForegroundColor White
    Write-Host "  [4] Escolher saida manualmente" -ForegroundColor White
    Write-Host "  [5] Escolher entrada manualmente" -ForegroundColor White
    Write-Host "  [0] Sair" -ForegroundColor DarkGray
    Write-Host ""
}

function List-Devices($dataFlow, $label) {
    $devices = [AudioDeviceManager]::ListDevices($dataFlow)
    Write-Host ""
    Write-Host "  Dispositivos de $label`:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $devices.Count; $i++) {
        $parts = $devices[$i].Split('|',2)
        Write-Host "    [$i] $($parts[1])" -ForegroundColor White
    }
    Write-Host ""
    return $devices
}

function Choose-Device($dataFlow, $label) {
    $devices = List-Devices $dataFlow $label
    if ($devices.Count -eq 0) { Write-Host "  Nenhum dispositivo encontrado." -ForegroundColor Red; return }
    $idx = Read-Host "  Escolha o numero"
    if ($idx -match '^\d+$' -and [int]$idx -lt $devices.Count) {
        $parts = $devices[[int]$idx].Split('|',2)
        [AudioDeviceManager]::SetDefaultDevice($parts[0])
        Write-Host "  OK! $label definido para: $($parts[1])" -ForegroundColor Green
    } else {
        Write-Host "  Numero invalido." -ForegroundColor Red
    }
}

function Apply-Fix {
    Write-Host ""
    Write-Host "  Procurando JBL na saida..." -ForegroundColor Cyan
    $outDevices = [AudioDeviceManager]::ListDevices(0)
    $inDevices  = [AudioDeviceManager]::ListDevices(1)

    # Procura JBL Stereo (A2DP) para saida - exclui Hands-Free
    $jblStereo = $null
    foreach ($d in $outDevices) {
        if ($d -match 'JBL' -and $d -notmatch 'Hands-Free|Handsfree|HFP') {
            $jblStereo = $d; break
        }
    }

    # Procura JBL mic na entrada (Hands-Free/HFP)
    $jblMic = $null
    foreach ($d in $inDevices) {
        if ($d -match 'JBL') { $jblMic = $d; break }
    }

    if (-not $jblStereo) {
        Write-Host "  JBL Stereo nao encontrado na saida! Conecte o fone e tente novamente." -ForegroundColor Red
        Write-Host "  Dispositivos disponiveis:" -ForegroundColor Yellow
        foreach ($d in $outDevices) { Write-Host "    - $($d.Split('|',2)[1])" }
        return
    }

    $jblParts = $jblStereo.Split('|',2)
    [AudioDeviceManager]::SetDefaultDevice($jblParts[0])
    Write-Host "  Saida definida para: $($jblParts[1]) (Stereo/A2DP)" -ForegroundColor Green

    if ($jblMic) {
        $micParts = $jblMic.Split('|',2)
        [AudioDeviceManager]::SetDefaultDevice($micParts[0])
        Write-Host "  Mic definido para: $($micParts[1]) (JBL Hands-Free)" -ForegroundColor Green
    } else {
        Write-Host "  Mic JBL nao encontrado na entrada." -ForegroundColor Yellow
        Write-Host "  Use a opcao [5] para escolher manualmente." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  FIX APLICADO! No Discord:" -ForegroundColor Green
    Write-Host "  - Saida: JBL Stereo (A2DP = qualidade alta)" -ForegroundColor White
    Write-Host "  - Mic: JBL Hands-Free" -ForegroundColor White
    Write-Host ""
    Write-Host "  NOTA: Se o audio ainda abafar, seu Bluetooth pode nao" -ForegroundColor Yellow
    Write-Host "  suportar A2DP + HFP ao mesmo tempo. Nesse caso, use" -ForegroundColor Yellow
    Write-Host "  o mic do notebook (opcao [5])." -ForegroundColor Yellow
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "  Opcao"
    switch ($choice) {
        '1' { Apply-Fix; Read-Host "  Enter para continuar" }
        '2' { List-Devices 0 "saida"; Read-Host "  Enter para continuar" }
        '3' { List-Devices 1 "entrada"; Read-Host "  Enter para continuar" }
        '4' { Choose-Device 0 "Saida"; Read-Host "  Enter para continuar" }
        '5' { Choose-Device 1 "Entrada"; Read-Host "  Enter para continuar" }
        '0' { break }
    }
} while ($choice -ne '0')
