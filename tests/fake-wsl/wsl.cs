// Stand-in for wsl.exe, for the lifecycle suites: every call goes into the log
// FAKE_WSL_LOG names, and the answers are read back from it - a distribution
// counts as running once a boot command has gone through. The name it answers
// with comes from FAKE_WSL_INSTANCE; the suite sets both, and compiles this
// file into a real wsl.exe - the scripts call `wsl.exe` with its extension, so
// only a binary of that name can stand in for it.
//
// The tool builds its lists as "--list --quiet [--running]", and that branch
// is all there is: everything else - a boot (--exec), a --terminate - answers
// zero and changes nothing. Nothing here is real.
using System;
using System.IO;

public class Program
{
    public static int Main(string[] args)
    {
        string log = Environment.GetEnvironmentVariable("FAKE_WSL_LOG");
        if (!String.IsNullOrEmpty(log))
        {
            File.AppendAllText(log, String.Join(" ", args) + Environment.NewLine);
        }

        if (args.Length >= 1 && args[0] == "--list")
        {
            bool askRunning = args.Length >= 3 && args[2] == "--running";
            bool seenBoot = File.Exists(log) && File.ReadAllText(log).Contains("--exec");
            if (askRunning && !seenBoot)
            {
                return 0;
            }
            string name = Environment.GetEnvironmentVariable("FAKE_WSL_INSTANCE");
            if (!String.IsNullOrEmpty(name))
            {
                Console.WriteLine(name);
            }
        }
        return 0;
    }
}
