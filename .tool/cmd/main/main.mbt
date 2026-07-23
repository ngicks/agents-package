///|
/// Native process-exit FFI. There is no `@env.exit` in core, so we bind libc
/// `exit` directly (the same idiom argparse uses internally for its
/// print-and-exit paths).
#cfg(any(target="native", target="llvm"))
extern "c" fn exit_code(code : Int) = "exit"

///|
/// Native process-id FFI (libc `getpid`). Used to give `-o` temp files a
/// per-process-unique name without pulling in a Date/random dependency.
#cfg(any(target="native", target="llvm"))
extern "c" fn get_pid() -> Int = "getpid"

///|
/// UsageError carries a display-ready argparse (or dispatch) message. It maps to
/// exit code 2 and its text is written to stderr verbatim (the message already
/// embeds "error: ..." and any contextual help).
suberror UsageError {
  UsageError(String)
}

///|
/// CliError carries a display-ready message for a runtime failure that is not a
/// usage error (e.g. git-derivation failure). It maps to exit code 1; the
/// catch-all prefixes "error: ".
suberror CliError {
  CliError(String)
}

///|
/// Entry point. Parses argv, dispatches to the selected subcommand, and maps
/// every failure to an exit code:
///
/// - success            -> falls off `main`, exit 0
/// - usage error (2)    -> argparse parse failure or unknown/missing subcommand
/// - runtime error (1)  -> discovery / IO / emit / git-derivation failure
///
/// Nothing but the generated document is ever written to stdout; all
/// diagnostics go to stderr.
async fn main {
  run() catch {
    UsageError(msg) => {
      @stdio.stderr.write(msg)
      @stdio.stderr.write("\n")
      exit_code(2)
    }
    CliError(msg) => {
      @stdio.stderr.write("error: \{msg}\n")
      exit_code(1)
    }
    @discover.DiscoverError(msg) => {
      @stdio.stderr.write("error: \{msg}\n")
      exit_code(1)
    }
    @apmyml.EmitError(msg) => {
      @stdio.stderr.write("error: \{msg}\n")
      exit_code(1)
    }
    e => {
      @stdio.stderr.write("error: \{e}\n")
      exit_code(1)
    }
  }
}

///|
/// Build the command tree, parse argv, and dispatch on the selected subcommand.
/// A parse failure is rethrown as a `UsageError` so the top level can map it to
/// exit code 2. Adding a future subcommand is one new `Command` in `build_cli`
/// plus one dispatch arm here.
async fn run() -> Unit {
  let cmd = build_cli()
  let matches = cmd.parse() catch { e => raise UsageError(e.to_string()) }
  match matches.subcommand {
    Some(("gen-apm-yml", sub)) => gen_apm_yml(sub)
    Some((name, _)) => raise UsageError("error: unknown subcommand '\{name}'")
    None => raise UsageError("error: a subcommand is required")
  }
}

///|
/// Build the `tool` command with its single `gen-apm-yml` subcommand.
fn build_cli() -> @argparse.Command {
  let gen = @argparse.Command(
    "gen-apm-yml",
    about="Generate an apm.yml listing every importable package in this repo",
    options=[
      @argparse.OptionArg(
        "root",
        about="Repository root to scan (realpath'd before scanning)",
        default_values=["."],
      ),
      @argparse.OptionArg(
        "name",
        about="Package name in the generated manifest",
        default_values=["agents-package-index"],
      ),
      @argparse.OptionArg(
        "pkg-version",
        about="Package version in the generated manifest",
        default_values=["0.0.1"],
      ),
      @argparse.OptionArg(
        "git",
        about="Override the git reference (default: derived from `git remote get-url origin`)",
      ),
      @argparse.OptionArg("ref", about="Pin every entry to this ref"),
      @argparse.OptionArg(
        "output",
        short='o',
        about="Write the manifest to this path instead of stdout",
      ),
      @argparse.OptionArg(
        "exclude",
        about="Glob of repo-relative paths to skip (repeatable)",
        action=@argparse.Append,
      ),
      @argparse.OptionArg(
        "target",
        about="Deploy target for the template (repeatable; default: claude, codex)",
        action=@argparse.Append,
      ),
    ],
  )
  @argparse.Command(
    "tool",
    about="agents-package repository maintenance CLI",
    subcommands=[gen],
    subcommand_required=true,
  )
}
