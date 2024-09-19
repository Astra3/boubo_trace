use std::process::Command;

use log::{info, trace};
use nix::{
    sys::ptrace::{self},
    unistd::Pid,
};
use spawn_ptrace::CommandPtraceSpawn;
use tracer::SysCall;

fn main() -> Result<(), anyhow::Error> {
    env_logger::init();
    let mut cmd = Command::new("/home/roman/Documents/Škola/bakalářka/tracer/test_program/main")
        .spawn_ptrace()?;

    let pid = Pid::from_raw(cmd.id() as i32);
    trace!("PID: {}", pid);

    let mut v = vec![];
    loop {
        ptrace::syscall(pid, None)?;
        let call = SysCall::parse(pid)?;
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
