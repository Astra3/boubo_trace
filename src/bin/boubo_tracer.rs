use std::{
    fs::{File, canonicalize}, io::Write, path::PathBuf, process::Command
};

use anyhow::bail;
use boubo_trace::{
    syscall::{
        Syscall, SyscallIter, SyscallIterOpts, new_types::{NewTypeError, sockaddr_ser}
    },
    tracee::Tracee,
};
use clap::Parser;
use log::{LevelFilter, debug, info};
use nix::unistd::Pid;
use spawn_ptrace::CommandPtraceSpawn;

#[derive(Parser)]
#[command(version, about)]
struct Args {
    /// Save captured syscalls to <FILE>
    #[arg(long, short)]
    output: Option<PathBuf>,
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
    /// If you specify `RUST_LOG` environment variable, this flag is ignored and the variable's value
    /// is used directly by ``env_logger``.
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

fn main() -> Result<(), anyhow::Error> {
    let args = Args::parse();
    if std::env::var_os("RUST_LOG").is_some() {
        env_logger::init();
    } else {
        let level = match args.verbose {
            0 => LevelFilter::Warn,
            1 => LevelFilter::Info,
            2 => LevelFilter::Debug,
            _ => LevelFilter::Trace,
        };
        env_logger::builder().filter_level(level).try_init()?;
    }
    let app = App::new(args);
    app.call_cmd()?;

    Ok(())
}

struct App {
    args: Args,
}

#[derive(Debug, rkyv::Serialize, rkyv::Archive, rkyv::Deserialize)]
struct IncrementallyBuilding {
    #[rkyv(with = rkyv::with::Map<sockaddr_ser>)]
    flags: Option<libc::sockaddr>,
    number: u8,
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
        let pid = Pid::from_raw(process.id().cast_signed());
        debug!("traced pid: {pid}");

        let opts = SyscallIterOpts::default().skip_to_main(!self.args.no_skip_to_main);

        for call in SyscallIter::new(Tracee::new(pid), &opts)? {
            match call {
                Ok(call) => {
                    info!("Parsed syscall: {call:?}");
                    called_syscalls.push(call);
                },
                Err(err) => log::warn!("Error while parsing: {err}"),
            }
        }
        
        let bytes = rkyv::to_bytes::<NewTypeError>(&called_syscalls)?;
        
        println!("before archival: {called_syscalls:?}");
        let res = rkyv::from_bytes::<Vec<Syscall>, NewTypeError>(&bytes)?;
        println!("after recovery: {res:?}");
        assert_eq!(called_syscalls, res);

        if let Some(path) = &self.args.output {
            if path.exists() {
                bail!("File {} already exists!", path.display())
            }
            let bytes = rkyv::to_bytes::<NewTypeError>(&called_syscalls)?;
            let mut file = File::create(path)?;
            file.write_all(&bytes)?;
        }
        Ok(())
    }
}
