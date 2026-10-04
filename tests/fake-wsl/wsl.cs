// Stand-in for wsl.exe, for the lifecycle suites: every call goes into the log
// FAKE_WSL_LOG names, and the answers are read back from it - a distribution
// counts as running once a boot command has gone through. The name it answers
// with comes from FAKE_WSL_INSTANCE; the suite sets both, and compiles this
// file into a real wsl.exe - the scripts call `wsl.exe` with its extension, so
// only a binary of that name can stand in for it.
//
// The tool builds its lists as "--list --quiet [--running]", and that branch
// is all there is: everything else - a boot (--exec), a --terminate - answers
// zero and changes nothing. Two calls leave something behind, because the
// commands read it back: an --export writes a small file where a real one
// would write the archive, and an --import creates the install folder a real
// one would register. Nothing here is real.
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
            // The raw command line too: real wsl.exe parses its own and does not
            // strip quotes, which the joined arguments above cannot show.
            File.AppendAllText(log, "raw: " + Environment.CommandLine + Environment.NewLine);
        }

        // --export <name> <path> [--format f]: the archive the caller will read
        // back - its size, its presence - lands where it asked.
        if (args.Length >= 3 && args[0] == "--export")
        {
            File.WriteAllText(args[2], "fake-export of " + args[1]);
            return 0;
        }

        // --import <name> <installPath> <tar> [--version N]: the folder exists
        // afterwards on a real machine, and the caller marks it and writes the
        // look into it, so it must exist here too.
        if (args.Length >= 4 && args[0] == "--import")
        {
            Directory.CreateDirectory(args[2]);
            File.WriteAllText(Path.Combine(args[2], "ext4.vhdx"), "fake-disk");
            return 0;
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
