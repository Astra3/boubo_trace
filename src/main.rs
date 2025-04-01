use std::{
    fs::{canonicalize, File},
    io::{self},
    path::PathBuf,
    process::Command,
};

use clap::Parser;
use log::{debug, error, info, LevelFilter};
use nix::unistd::Pid;
use serde::Serialize;
use spawn_ptrace::CommandPtraceSpawn;
use tracer::{
    syscall::{Syscall, SyscallIter, SyscallIterOpts, SyscallParseError},
    tracee::Tracee,
};

#[derive(Parser)]
#[command(version, about)]
struct Args {
    /// Save serialized JSON to <FILE>
    ///
    /// Use '-' to write to stdout.
    #[arg(long, short)]
    output: Option<String>,
    /// Use a prettier JSON formatter
    #[arg(long, short, requires = "output")]
    pretty_output: bool,
    /// Don't skip syscalls called before main in captured process
    #[arg(long)]
    no_skip_to_main: bool,
    /// Working directory for <EXECUTABLE>
    ///
    /// If not specified, the current working directory is used.
    #[arg(long, short, value_parser = parse_dir)]
    work_dir: Option<PathBuf>,
    /// Path to executable to capture
    #[arg(value_parser = parse_exec)]
    executable: PathBuf,
    /// Verbosity, specify the flag more times for more verbosity.
    ///
    /// -v for info messages, -vv for debug messages and -vvv for trace messages.
    ///
    /// If you specify RUST_LOG environment variable, this flag is ignored and the variable's value
    /// is used directly by env_logger.
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
    /// Arguments (argv) for <EXECUTABLE>
    args: Vec<String>,
}

fn parse_path(arg: &str) -> Result<PathBuf, &'static str> {
    canonicalize(arg).or(Err("path is not valid"))
}

fn parse_exec(arg: &str) -> Result<PathBuf, &'static str> {
    let path = parse_path(arg)?;
    if !path.exists() {
        return Err("file does not exist");
    }
    Ok(path)
}

fn parse_dir(arg: &str) -> Result<PathBuf, &'static str> {
    let path = parse_path(arg)?;
    if !path.is_dir() {
        return Err("directory is invalid");
    }
    Ok(path)
}

#[derive(serde::Serialize)]
#[serde(untagged)]
enum SyscallWrapper {
    Syscall(Syscall),
    Error { syscall_error: SyscallParseError },
}

impl From<Result<Syscall, SyscallParseError>> for SyscallWrapper {
    fn from(value: Result<Syscall, SyscallParseError>) -> Self {
        match value {
            Ok(syscall) => SyscallWrapper::Syscall(syscall),
            Err(syscall_error) => SyscallWrapper::Error { syscall_error },
        }
    }
}

fn main() -> Result<(), anyhow::Error> {
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
    let app = App::new(args);
    app.call_cmd()?;

    Ok(())
}

struct App {
    args: Args,
}

impl App {
    fn new(args: Args) -> App {
        App { args }
    }

    pub fn call_cmd(&self) -> Result<(), anyhow::Error> {
        let mut cmd = Command::new(canonicalize(&self.args.executable)?);
        cmd.args(&self.args.args);

        if let Some(work_dir) = &self.args.work_dir {
            cmd.current_dir(work_dir);
        }
        let process = cmd.spawn_ptrace()?;

        let mut called_syscalls = vec![];
        let pid = Pid::from_raw(process.id() as i32);
        debug!("traced pid: {pid}");

        let opts = SyscallIterOpts::default().skip_to_main(!self.args.no_skip_to_main);

        for call in SyscallIter::new(Tracee::new(pid), opts)? {
            info!("Parsed syscall: {call:?}");
            called_syscalls.push(call);
        }

        if let Some(path) = &self.args.output {
            let v: Vec<SyscallWrapper> = called_syscalls.into_iter().map(From::from).collect();
            if path == "-" {
                self.serialize_json(io::stdout().lock(), &v)?;
            } else {
                let file = match File::create(path) {
                    Ok(file) => file,
                    Err(err) => {
                        error!("could not create file at path: {path}");
                        return Err(err.into());
                    }
                };
                // TODO bufwriter
                match self.serialize_json(&file, &v) {
                    Ok(file) => file,
                    Err(err) => {
                        error!("could not write to file at path: {path}");
                        return Err(err.into());
                    }
                };
            }
        }
        Ok(())
    }

    fn serialize_json<T, W>(&self, writer: W, value: &T) -> Result<(), serde_json::Error>
        where W: io::Write, T: Serialize {
            if self.args.pretty_output {
                serde_json::to_writer_pretty(writer, value)

            } else {
                serde_json::to_writer(writer, value)
            }
    }
}
