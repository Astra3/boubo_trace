use std::process::Command;

use log::{info, trace};
use nix::{
    sys::ptrace::{self, Options},
    unistd::Pid,
};
use spawn_ptrace::CommandPtraceSpawn;
use tracer::syscall::{SysCall, SyscallParseError};

fn main() -> Result<(), anyhow::Error> {
    env_logger::init();
    let mut cmd = Command::new("/home/roman/Documents/Škola/bakalářka/tracer/test_program/main")
        .current_dir("test_program/")
        .spawn_ptrace()?;

    let pid = Pid::from_raw(cmd.id() as i32);
    ptrace::setoptions(pid, Options::PTRACE_O_EXITKILL)?;
    trace!("PID: {}", pid);

    let mut v = vec![];
    loop {
        ptrace::syscall(pid, None)?;
        let call = match SysCall::parse(pid) {
            Ok(it) => it,
            Err(SyscallParseError::SyscallError { syscall, error}) => {
                info!("Syscall {syscall} returned an error: {error}");
                continue;
            },
            Err(err) => return Err(err.into())
        };
        info!("Parsed syscall: {call:?}");
        if call.is_write() {
            v.push(call);
            if v.len() == 2 {
                break;
            }
        }
    }

    ptrace::cont(pid, None)?;
    cmd.wait()?;
    Ok(())
}
