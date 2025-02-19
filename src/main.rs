use std::process::Command;

use clap::Parser;
use log::{debug, info, LevelFilter};
use nix::unistd::Pid;
use spawn_ptrace::CommandPtraceSpawn;
use tracer::{syscall::{SyscallIter, SyscallIterOpts}, tracee::Tracee};

#[derive(Parser)]
#[command(version, about)]
struct Args {
    /// Don't skip syscalls called before main in captured process
    #[arg(long)]
    no_skip_to_main: bool,
    /// Path to the captured process
    executable: String,
    /// Verbosity, specify the flag more times for more verbosity.
    ///
    /// -v for info messages, -vv for debug messages and -vvv for trace messages.
    ///
    /// If you specify RUST_LOG environment variable, this flag is ignored and the variable's value
    /// is used directly by env_logger.
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
    /// Arguments of the captures process
    args: Vec<String>,
}

fn main() -> Result<(), anyhow::Error> {
    // env_logger::init();
    let args = Args::parse();
    match std::env::var_os("RUST_LOG") {
        Some(_) => env_logger::init(),
        None => {
            let level = match args.verbose {
                0 => LevelFilter::Warn,
                1 => LevelFilter::Info,
                2 => LevelFilter::Debug,
                _ => LevelFilter::Trace,
            };
            env_logger::builder().filter_level(level).try_init()?;
        }
    }
    call_cmd(args)?;

    Ok(())
}

fn call_cmd(args: Args) -> Result<(), anyhow::Error> {
    println!("no skip to main: {:}", &args.no_skip_to_main);
    let cmd = Command::new(args.executable)
        .current_dir("test_programs/build")
        .args(args.args)
        .spawn_ptrace()?;

    let mut called_syscalls = vec![];
    let pid = Pid::from_raw(cmd.id() as i32);
    debug!("traced pid: {pid}");

    let opts = SyscallIterOpts::default().skip_to_main(!args.no_skip_to_main);

    for call in SyscallIter::new(Tracee::new(pid), opts)? {
        info!("Parsed syscall: {call:?}");
        // if let Err(SyscallParseError::ProcessExit(_)) = call {
        //     break;
        // }
        called_syscalls.push(call);
    }
    // let v: Vec<Syscall> = called_syscalls.into_iter().flatten().collect();
    // info!("serialized: {}", serde_json::to_string_pretty(&v).unwrap());
    Ok(())
}
