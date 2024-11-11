use std::io::IoSliceMut;

use libc::{c_void, RAX};
use log::{debug, info, trace};
use nix::{
    errno::Errno,
    sys::{
        ptrace,
        uio::{process_vm_readv, RemoteIoVec},
        wait::{waitpid, WaitStatus},
    },
    unistd::Pid,
};

use crate::syscall::SyscallParseError;

use super::SyscallDisc;

pub(super) fn wait_for_stop(pid: Pid) -> Result<(), SyscallParseError> {
    match waitpid(pid, None) {
        Ok(WaitStatus::Stopped(_, _)) => Ok(()),
        Ok(WaitStatus::Exited(_, exit_code)) => {
            info!("Process exited");
            Err(SyscallParseError::ProcessExit(exit_code))
        }
        Ok(status) => Err(SyscallParseError::UnexpectedWaitStatus(status)),
        Err(err) => Err(SyscallParseError::WaitPidError(err)),
    }
}

pub(super) fn read_bytes_memory(pid: Pid, base: usize, len: usize) -> Result<Vec<u8>, Errno> {
    let mut data = vec![0; len];
    process_vm_readv(
        pid,
        &mut [IoSliceMut::new(&mut data)],
        &[RemoteIoVec { base, len }],
    )?;
    Ok(data)
}

const MAX_BYTES_CSTRING: usize = 2048 * 1024; // 2 MiB
const BUFFER_SIZE: usize = 128;

// FIXME does this actually work?
pub(super) fn read_cstring(pid: Pid, base: usize) -> Result<Vec<u8>, Errno> {
    let mut data = vec![];
    let mut buf = [0; BUFFER_SIZE];
    let mut total_bytes_read = 0usize;

    while data.len() < MAX_BYTES_CSTRING {
        total_bytes_read += process_vm_readv(
            pid,
            &mut [IoSliceMut::new(&mut buf)],
            &[RemoteIoVec {
                base: base + total_bytes_read,
                len: BUFFER_SIZE,
            }],
        )?;

        if let Some(index) = buf.iter().position(|num| *num == 0) {
            data.extend_from_slice(&buf[..index + 1]);
            break;
        }
        data.extend_from_slice(&buf);
    }
    Ok(data)
}

pub(super) fn get_return_value(pid: Pid) -> Result<i64, SyscallParseError> {
    debug!("Parsing syscall exit...");
    ptrace::syscall(pid, None)?;
    wait_for_stop(pid)?;
    trace!("exit regs: {:?}", ptrace::getregs(pid)?);
    Ok(ptrace::read_user(pid, (RAX * 8) as *mut c_void)?)
}

pub(super) fn parse_syscall_error(return_value: i64) -> Errno {
    Errno::from_raw(-return_value as i32)
}

pub(super) fn parse_return(pid: Pid, syscall: SyscallDisc) -> Result<i64, SyscallParseError> {
    let ret = get_return_value(pid)?;
    trace!("return value: {ret}");
    if ret < 0 {
        return Err(SyscallParseError::SyscallError {
            syscall,
            error: parse_syscall_error(ret),
        });
    }
    Ok(ret)
}
