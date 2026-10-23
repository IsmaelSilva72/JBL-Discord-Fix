# JBL Discord Fix - Monitor Continuo
# Roda em segundo plano e corrige automaticamente quando o Windows troca os perfis

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
internal class MMDeviceEnumeratorClass { }

[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
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
}

[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey {
    public Guid fmtid; public int pid;
    public PropertyKey(Guid f, int p) { fmtid = f; pid = p; }
}

[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
    [FieldOffset(0)] public short vt;
    [FieldOffset(8)] public IntPtr pwszVal;
    public string AsString() { return vt == 31 ? Marshal.PtrToStringUni(pwszVal) : ""; }
}

[ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IPolicyConfig {
    int u1(); int u2(); int u3(); int u4(); int u5(); int u6();
    int u7(); int u8(); int u9(); int u10(); int u11();
    int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int role);
}

[ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
internal class PolicyConfigClient { }

public class AudioMonitor {
    private static readonly PropertyKey PKEY_Name = new PropertyKey(
        new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), 14);

    private static string GetDeviceName(IMMDevice dev) {
        IPropertyStore ps; dev.OpenPropertyStore(0, out ps);
        PropVariant pv; var k = PKEY_Name; ps.GetValue(ref k, out pv);
        return pv.AsString();
    }

    public static string GetDefaultName(int dataFlow) {
        try {
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
            IMMDevice dev;
            enumerator.GetDefaultAudioEndpoint(dataFlow, 0, out dev);
            return GetDeviceName(dev);
        } catch { return ""; }
    }

    public static string FindAndSet(int dataFlow, string mustContain, string mustNotContain) {
        try {
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
            var policy = (IPolicyConfig)new PolicyConfigClient();
            IMMDeviceCollection devs;
            enumerator.EnumAudioEndpoints(dataFlow, 1, out devs);
            int count; devs.GetCount(out count);
            string[] mustNot = mustNotContain.Split('|');
            for (int i = 0; i < count; i++) {
                IMMDevice dev; devs.Item(i, out dev);
                string name = GetDeviceName(dev);
                if (name.IndexOf(mustContain, StringComparison.OrdinalIgnoreCase) < 0) continue;
                bool skip = false;
                foreach (string n in mustNot) {
                    if (n.Length > 0 && name.IndexOf(n, StringComparison.OrdinalIgnoreCase) >= 0) { skip = true; break; }
                }
                if (skip) continue;
                string id; dev.GetId(out id);
                policy.SetDefaultEndpoint(id, 0);
                policy.SetDefaultEndpoint(id, 1);
                policy.SetDefaultEndpoint(id, 2);
                return name;
            }
        } catch {}
        return "";
    }
}
'@ -ErrorAction Stop

$host.UI.RawUI.WindowTitle = "JBL Discord Fix - Monitor"

Write-Host ""
Write-Host "  JBL Discord Fix - Monitor Continuo" -ForegroundColor Cyan
Write-Host "  ===================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Monitorando dispositivos de audio..." -ForegroundColor White
Write-Host "  O script corrige automaticamente quando o Windows troca." -ForegroundColor White
Write-Host "  Feche esta janela para parar." -ForegroundColor DarkGray
Write-Host ""

$lastOut = ""
$lastIn = ""
$fixCount = 0

while ($true) {
    try {
        $currentOut = [AudioMonitor]::GetDefaultName(0)
        $currentIn  = [AudioMonitor]::GetDefaultName(1)

        $needFix = $false

        # Se a saida mudou para Hands-Free ou saiu do JBL Stereo
        if ($currentOut -ne $lastOut) {
            if ($currentOut -match 'Hands-Free|Handsfree|HFP' -or
                ($lastOut -match 'JBL' -and $currentOut -notmatch 'JBL')) {
                $needFix = $true
            }
            $lastOut = $currentOut
        }

        # Se a entrada saiu do JBL
        if ($currentIn -ne $lastIn) {
            if ($lastIn -match 'JBL' -and $currentIn -notmatch 'JBL') {
                $needFix = $true
            }
            $lastIn = $currentIn
        }

        if ($needFix) {
            $fixCount++
            $time = Get-Date -Format "HH:mm:ss"
            Write-Host "  [$time] Detectada troca! Corrigindo... (#$fixCount)" -ForegroundColor Yellow

            $outResult = [AudioMonitor]::FindAndSet(0, "JBL", "Hands-Free|Handsfree|HFP")
            $inResult  = [AudioMonitor]::FindAndSet(1, "JBL", "")

            if ($outResult) {
                Write-Host "  [$time] Saida -> $outResult (Stereo)" -ForegroundColor Green
                $lastOut = $outResult
            }
            if ($inResult) {
                Write-Host "  [$time] Mic   -> $inResult" -ForegroundColor Green
                $lastIn = $inResult
            }
        }
    } catch {
        # Silently continue
    }

    Start-Sleep -Seconds 2
}
