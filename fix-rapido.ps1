# Fix rapido - aplica automaticamente sem menu
# Clique duplo ou crie um atalho para este script

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

public class QuickFix {
    private static readonly PropertyKey PKEY_Name = new PropertyKey(
        new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), 14);

    public static string Apply() {
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
        var policy = (IPolicyConfig)new PolicyConfigClient();
        string result = "";

        // Find JBL output
        IMMDeviceCollection outDevs;
        enumerator.EnumAudioEndpoints(0, 1, out outDevs);
        int outCount; outDevs.GetCount(out outCount);
        for (int i = 0; i < outCount; i++) {
            IMMDevice dev; outDevs.Item(i, out dev);
            string id; dev.GetId(out id);
            IPropertyStore ps; dev.OpenPropertyStore(0, out ps);
            PropVariant pv; var k = PKEY_Name; ps.GetValue(ref k, out pv);
            string name = pv.AsString();
            if (name.IndexOf("JBL", StringComparison.OrdinalIgnoreCase) >= 0 &&
                name.IndexOf("Hands-Free", StringComparison.OrdinalIgnoreCase) < 0 &&
                name.IndexOf("Handsfree", StringComparison.OrdinalIgnoreCase) < 0 &&
                name.IndexOf("HFP", StringComparison.OrdinalIgnoreCase) < 0) {
                // Use o perfil Stereo/A2DP para saida (qualidade alta)
                policy.SetDefaultEndpoint(id, 0);
                policy.SetDefaultEndpoint(id, 1);
                policy.SetDefaultEndpoint(id, 2);
                result += "Saida (Stereo/A2DP): " + name + "\n";
                break;
            }
        }

        // Find JBL Hands-Free mic (HFP profile)
        IMMDeviceCollection inDevs;
        enumerator.EnumAudioEndpoints(1, 1, out inDevs);
        int inCount; inDevs.GetCount(out inCount);
        for (int i = 0; i < inCount; i++) {
            IMMDevice dev; inDevs.Item(i, out dev);
            string id; dev.GetId(out id);
            IPropertyStore ps; dev.OpenPropertyStore(0, out ps);
            PropVariant pv; var k = PKEY_Name; ps.GetValue(ref k, out pv);
            string name = pv.AsString();
            if (name.IndexOf("JBL", StringComparison.OrdinalIgnoreCase) >= 0) {
                // Usa o mic do JBL (Hands-Free/HFP)
                policy.SetDefaultEndpoint(id, 0);
                policy.SetDefaultEndpoint(id, 1);
                policy.SetDefaultEndpoint(id, 2);
                result += "Mic: " + name + "\n";
                break;
            }
        }

        return result == "" ? "Nenhum dispositivo encontrado" : result;
    }
}
'@ -ErrorAction Stop

$result = [QuickFix]::Apply()

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
    "Fix aplicado!`n`n$result`nSaida = JBL Stereo (A2DP, qualidade alta)`nMic = JBL Hands-Free`n`nNo Discord, confirme:`n- Dispositivo de saida: JBL (Stereo)`n- Dispositivo de entrada: JBL (Hands-Free)`n`nSe o audio ainda abafar, o Bluetooth do seu PC`npode nao suportar A2DP + HFP simultaneo.`nNesse caso, use o mic do notebook.",
    "JBL Discord Fix",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
