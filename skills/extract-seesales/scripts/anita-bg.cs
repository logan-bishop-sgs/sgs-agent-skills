// SendMessage driver for the AniTa canvas. Does not steal focus.
// Built on demand by export-seesales-range.ps1. Do not commit the .exe.
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class AnitaBg {
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h, EnumChildProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern int SendMessage(IntPtr h, uint m, int w, StringBuilder l);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int n);
    delegate bool EnumChildProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }

    const uint WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_CHAR = 0x0102;
    const uint WM_GETTEXT = 0x000D;
    const int SW_SHOWNOACTIVATE = 4;
    const uint SWP_NOSIZE = 0x0001, SWP_NOACTIVATE = 0x0010;
    const int SM_CXSCREEN = 0, SM_CYSCREEN = 1;
    static readonly IntPtr HWND_BOTTOM = new IntPtr(1);

    // Fully on the primary screen (off-screen PrintWindow is empty /
    // AniTa drops the telnet). Behind other windows, no activate, no
    // SetForegroundWindow. Chrome is already off in the hidden wcf.
    // Do not resize (AniTa ignores it without chrome) or minimize.
    static void ParkOffscreen(IntPtr hwnd) {
        RECT r;
        GetWindowRect(hwnd, out r);
        int w = Math.Max(400, r.R - r.L), h = Math.Max(300, r.B - r.T);
        int x = Math.Max(0, GetSystemMetrics(SM_CXSCREEN) - w - 8);
        int y = Math.Max(0, GetSystemMetrics(SM_CYSCREEN) - h - 8);
        ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        SetWindowPos(hwnd, HWND_BOTTOM, x, y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
        Console.WriteLine("park " + x + "," + y + " size=" + w + "x" + h);
    }

    static IntPtr Canvas(IntPtr hwnd) {
        IntPtr c = IntPtr.Zero;
        EnumChildWindows(hwnd, (h, l) => {
            var sb = new StringBuilder(64);
            GetClassName(h, sb, 64);
            if (sb.ToString() == "AniTa") c = h;
            return true;
        }, IntPtr.Zero);
        return c;
    }

    static string CaptureDir() {
        return Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
            + @"\Temp\anita-capture\";
    }

    static void SnapHwnd(IntPtr hwnd, string name) {
        RECT r;
        GetWindowRect(hwnd, out r);
        int w = Math.Max(1, r.R - r.L), h = Math.Max(1, r.B - r.T);
        using (var bmp = new Bitmap(w, h))
        using (var g = Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            PrintWindow(hwnd, hdc, 2);
            g.ReleaseHdc(hdc);
            System.IO.Directory.CreateDirectory(CaptureDir());
            bmp.Save(CaptureDir() + name, ImageFormat.Png);
        }
        Console.WriteLine("snap " + name + " " + w + "x" + h);
    }

    static void Snap(IntPtr hwnd, IntPtr canvas, string name) {
        SnapHwnd(hwnd, name);
        if (canvas != IntPtr.Zero) {
            string canvasName = System.IO.Path.GetFileNameWithoutExtension(name) + "-canvas.png";
            SnapHwnd(canvas, canvasName);
        }
    }

    static void Type(IntPtr canvas, string text, bool enter) {
        foreach (char ch in text) {
            int vk = char.ToUpperInvariant(ch);
            SendMessage(canvas, WM_KEYDOWN, (IntPtr)vk, IntPtr.Zero);
            SendMessage(canvas, WM_CHAR, (IntPtr)ch, IntPtr.Zero);
            SendMessage(canvas, WM_KEYUP, (IntPtr)vk, IntPtr.Zero);
            Thread.Sleep(80);
        }
        if (enter) {
            SendMessage(canvas, WM_KEYDOWN, (IntPtr)0x0D, IntPtr.Zero);
            SendMessage(canvas, WM_CHAR, (IntPtr)0x0D, IntPtr.Zero);
            SendMessage(canvas, WM_KEYUP, (IntPtr)0x0D, IntPtr.Zero);
        }
    }

    static void Key(IntPtr canvas, int vk) {
        SendMessage(canvas, WM_KEYDOWN, (IntPtr)vk, IntPtr.Zero);
        // Skip WM_CHAR when the VK code is a printable glyph.
        // Home=$, Insert=-, Delete=., Left=%, PgUp=!.
        // End (35) still sends CHAR — IFORMS uses it as Commit.
        // No WM_CHAR for editing keys or F1-F12 (F7=118 would type 'v').
        if (vk != 8 && vk != 27 && vk != 33 && vk != 34
            && (vk < 36 || vk > 40) && vk != 45 && vk != 46
            && (vk < 112 || vk > 123))
            SendMessage(canvas, WM_CHAR, (IntPtr)vk, IntPtr.Zero);
        SendMessage(canvas, WM_KEYUP, (IntPtr)vk, IntPtr.Zero);
    }

    static string TakeTitle(ref string[] args) {
        if (args.Length < 2) return "";
        string last = args[args.Length - 1];
        if (last.IndexOf("idb", StringComparison.OrdinalIgnoreCase) < 0
            && last.IndexOf("anita", StringComparison.OrdinalIgnoreCase) < 0)
            return "";
        var kept = new string[args.Length - 1];
        Array.Copy(args, kept, kept.Length);
        args = kept;
        return last;
    }

    static Process FindAnita(string titleNeedle) {
        Process[] ps = Process.GetProcessesByName("Anita");
        if (ps.Length == 0) return null;
        if (string.IsNullOrEmpty(titleNeedle)) {
            if (ps.Length > 1) {
                Console.WriteLine("WARN multiple AniTa windows; pass a title like use-idb059");
                foreach (var x in ps) Console.WriteLine("  pid=" + x.Id + " title=" + x.MainWindowTitle);
            }
            return ps[0];
        }
        foreach (var cand in ps) {
            if (cand.MainWindowTitle.IndexOf(titleNeedle, StringComparison.OrdinalIgnoreCase) >= 0)
                return cand;
        }
        Console.WriteLine("no AniTa title matching " + titleNeedle);
        foreach (var cand in ps) Console.WriteLine("  pid=" + cand.Id + " title=" + cand.MainWindowTitle);
        return null;
    }

    static int Main(string[] args) {
        SetProcessDPIAware();
        string titleNeedle = TakeTitle(ref args);
        string cmd = args.Length > 0 ? args[0] : "status";
        var p = FindAnita(titleNeedle);
        if (p == null) { Console.WriteLine("no AniTa"); return 2; }
        IntPtr hwnd = p.MainWindowHandle;
        IntPtr canvas = Canvas(hwnd);
        if (canvas == IntPtr.Zero && cmd != "status") { Console.WriteLine("no canvas"); return 3; }
        // Never move the window here. SetWindowPos during login: / Password:
        // drops the telnet session. launch-anita-hidden.ps1 parks once.
        if (cmd == "park") {
            ParkOffscreen(hwnd);
            Console.WriteLine("title=" + p.MainWindowTitle);
            return 0;
        }
        Console.WriteLine("title=" + p.MainWindowTitle);

        if (cmd == "snap") {
            Snap(hwnd, canvas, args.Length > 1 ? args[1] : "bg.png");
            return 0;
        }
        if (cmd == "type" || cmd == "chars") {
            string text = args[1];
            if (text.StartsWith("env:", StringComparison.OrdinalIgnoreCase))
                text = Environment.GetEnvironmentVariable(text.Substring(4)) ?? "";
            bool enter = args.Length > 2 && args[2] == "enter";
            if (cmd == "chars") {
                foreach (char ch in text) {
                    SendMessage(canvas, WM_CHAR, (IntPtr)ch, IntPtr.Zero);
                    Thread.Sleep(120);
                }
                if (enter) {
                    SendMessage(canvas, WM_CHAR, (IntPtr)0x0D, IntPtr.Zero);
                    Thread.Sleep(120);
                }
                Console.WriteLine("chars len=" + text.Length + " enter=" + enter);
                return 0;
            }
            Type(canvas, text, enter);
            Console.WriteLine("typed len=" + text.Length + " enter=" + enter);
            return 0;
        }
        if (cmd == "key") {
            Key(canvas, int.Parse(args[1]));
            return 0;
        }
        if (cmd == "host") {
            string spec = args.Length > 1 ? args[1] : "";
            spec = spec.Replace("\\x1b", "\x1b").Replace("\\r", "\r").Replace("\\n", "\n");
            foreach (char ch in spec) {
                SendMessage(canvas, WM_CHAR, (IntPtr)ch, IntPtr.Zero);
                Thread.Sleep(20);
            }
            Console.WriteLine("host sent len=" + spec.Length);
            return 0;
        }
        if (cmd == "status") {
            EnumChildWindows(hwnd, (h, l) => {
                var cls = new StringBuilder(64);
                GetClassName(h, cls, 64);
                var title = new StringBuilder(256);
                GetWindowText(h, title, 256);
                var wm = new StringBuilder(512);
                SendMessage(h, WM_GETTEXT, 512, wm);
                Console.WriteLine("child class=" + cls + " title=" + title + " text=" + wm);
                return true;
            }, IntPtr.Zero);
            return p.MainWindowTitle.IndexOf("Disconnected", StringComparison.OrdinalIgnoreCase) >= 0 ? 4 : 0;
        }
        return 1;
    }
}
