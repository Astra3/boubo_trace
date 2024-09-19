use std::{ffi::c_void, io::IoSliceMut};

use libc::{user_regs_struct, RAX};
use log::{trace, warn};
use nix::{
    errno::Errno,
    sys::{
        ptrace,
        uio::{process_vm_readv, RemoteIoVec},
        wait::{waitpid, WaitStatus},
    },
    unistd::Pid,
};
use strum::EnumIs;

#[derive(Debug, Clone, EnumIs)]
pub enum SysCall {
    Write { fd: usize, buf: String },
    Unknown(user_regs_struct),
}

fn get_return_value(pid: Pid) -> Result<i64, Errno> {
    ptrace::syscall(pid, None)?;
    trace!("parsing return value...");
    match waitpid(pid, None) {
        Ok(WaitStatus::Stopped(_, _)) => ptrace::read_user(pid, (RAX * 8) as *mut c_void),
        _ => panic!(),
    }
}

impl SysCall {
    pub fn parse(pid: Pid) -> Result<SysCall, Errno> {
        trace!("Parsing syscall...");
        match waitpid(pid, None) {
            Ok(WaitStatus::Stopped(_, _)) => {
                let regs = ptrace::getregs(pid)?;
                trace!("registers: {regs:X?}");
                match regs.orig_rax {
                    1 => {
                        let mut data = vec![0; regs.rdx as usize];
                        process_vm_readv(
                            pid,
                            &mut [IoSliceMut::new(&mut data)],
                            &[RemoteIoVec {
                                base: regs.rsi as usize,
                                len: regs.rdx as usize,
                            }],
                        )?;
                        // TODO probably don't just ignore it
                        let ret = get_return_value(pid)?;
                        trace!("return value: {ret}");
                        Ok(SysCall::Write {
                            fd: regs.rdi as usize,
                            buf: String::from_utf8(data).unwrap(),
                        })
                    }
                    _ => {
                        warn!("Unknown syscall was called");
                        get_return_value(pid)?;
                        Ok(SysCall::Unknown(regs))
                    }
                }
            }
            _ => panic!("oopsie"),
        }
    }
}
