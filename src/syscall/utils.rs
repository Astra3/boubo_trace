use std::io::IoSliceMut;

use libc::{c_void, RAX};
use log::{debug, trace};
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

use super::SysCallDisc;

pub(super) fn get_return_value(pid: Pid) -> Result<i64, SyscallParseError> {
    debug!("Parsing syscall exit...");
    ptrace::syscall(pid, None)?;
    match waitpid(pid, None) {
        // FIXME it's probably good enough if this returns EAX
        Ok(WaitStatus::Stopped(_, _)) => Ok(ptrace::read_user(pid, (RAX * 8) as *mut c_void)?),
        Ok(WaitStatus::Exited(_, _)) => Err(SyscallParseError::ProcessExit),
        _ => panic!(),
    }
}

pub(super) fn read_string_memory(pid: Pid, base: usize, len: usize) -> Result<Vec<u8>, Errno> {
    let mut data = vec![0; len];
    process_vm_readv(
        pid,
        &mut [IoSliceMut::new(&mut data)],
        &[RemoteIoVec { base, len }],
    )?;
    Ok(data)
}

pub(super) fn read_cstring(pid: Pid, mut addr: usize) -> Result<Vec<u8>, Errno> {
    let mut data = vec![];
    'read: loop {
        // TODO use process_vm_readv here
        let word = ptrace::read(pid, addr as *mut c_void)?;
        for byte in word.to_ne_bytes() {
            if byte == 0 {
                break 'read;
            }
            data.push(byte);
            addr += 1;
        }
    }

    Ok(data)
}

pub(super) fn parse_syscall_error(return_value: i64) -> Errno {
    Errno::from_raw(-return_value as i32)
}

pub(super) fn parse_return(pid: Pid, syscall: SysCallDisc) -> Result<(), SyscallParseError> {
    let ret = get_return_value(pid)?;
    trace!("return value: {ret}");
    if ret < 0 {
        return Err(SyscallParseError::SyscallError {
            syscall,
            error: parse_syscall_error(ret),
        });
    }
    Ok(())
}
