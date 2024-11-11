use libc::mode_t;
use log::{debug, error, trace, warn};
use nix::{
    errno::Errno,
    sys::{ptrace, wait::WaitStatus},
    unistd::Pid,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use utils::{get_return_value, parse_return, read_bytes_memory, read_cstring, wait_for_stop};

mod utils;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, strum::EnumIs, strum::EnumDiscriminants)]
#[strum_discriminants(derive(strum::Display))]
#[serde(rename_all = "snake_case")]
pub enum Syscall {
    Read {
        fd: i32,
        read_bytes: Vec<u8>,
        requested_count: usize,
    },
    Write {
        fd: i32,
        buf: Vec<u8>,
    },
    Close {
        fd: i32,
    },
    Openat {
        dirfd: i32,
        pathname: Vec<u8>,
        flags: i32,
        mode: mode_t,
    },
    ExitGroup {
        status: i32,
    },
    Unknown {
        id: u64,
        args: SyscallArgs,
        return_value: i64,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyscallArgs(u64, u64, u64, u64, u64, u64);

type SyscallDisc = SyscallDiscriminants;

#[derive(Error, Debug)]
pub enum SyscallParseError {
    #[error("error in tracee's syscall")]
    SyscallError { syscall: SyscallDisc, error: Errno },
    #[error("error in syscall by tracer: {0:?}")]
    PtraceError(#[from] Errno),
    #[error("tracee process is not running")]
    ProcessExit(i32),
    #[error("unexpected status returned by waitpid")]
    UnexpectedWaitStatus(WaitStatus),
    #[error("error returned by waitpid")]
    WaitPidError(Errno),
}

impl Serialize for SyscallParseError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer {
        serializer.serialize_u32(20)
    }
}

impl Syscall {
    pub fn parse(pid: Pid) -> Result<Syscall, SyscallParseError> {
        debug!("Parsing syscall entry...");
        wait_for_stop(pid)?;
        let regs = ptrace::getregs(pid)?;
        let args = SyscallArgs(regs.rdi, regs.rsi, regs.rdx, regs.r10, regs.r8, regs.r9);
        trace!("registers: {regs:?}");
        match regs.orig_rax {
            0 => {
                // TODO don't read it all
                let read = parse_return(pid, SyscallDisc::Read)?;
                let bytes = read_bytes_memory(pid, args.1 as usize, read as usize)?;
                Ok(Syscall::Read {
                    fd: args.0 as i32,
                    read_bytes: bytes,
                    requested_count: args.2 as usize,
                })
            }
            1 => {
                let text = read_bytes_memory(pid, args.1 as usize, args.2 as usize)?;
                trace!("address : {:#X}", args.1 as usize);
                parse_return(pid, SyscallDisc::Write)?;
                Ok(Syscall::Write {
                    fd: args.0 as i32,
                    buf: text,
                })
            }
            3 => {
                parse_return(pid, SyscallDisc::Close)?;
                Ok(Syscall::Close { fd: args.0 as i32 })
            }
            231 => Ok(Syscall::ExitGroup {
                status: args.0 as i32,
            }),
            257 => {
                trace!("doing openat");
                let pathname = read_cstring(pid, args.1 as usize)?;
                parse_return(pid, SyscallDisc::Openat)?;
                Ok(Syscall::Openat {
                    dirfd: args.0 as i32,
                    pathname,
                    flags: args.2 as i32,
                    mode: args.3 as u32,
                })
            }
            _ => {
                warn!("Unknown syscall was called");
                let return_value = get_return_value(pid)?;
                Ok(Syscall::Unknown { id: regs.orig_rax, args, return_value })
            }
        }
    }
}

pub struct SyscallIter(pub Pid);

impl Iterator for SyscallIter {
    type Item = Result<Syscall, SyscallParseError>;

    fn next(&mut self) -> Option<Self::Item> {
        match ptrace::syscall(self.0, None) {
            Err(Errno::ESRCH) => {
                error!("wtf");
                return None
            },
            Err(err) => return Some(Err(err.into())),
            _ => (),
        };
        match Syscall::parse(self.0) {
            Ok(call) => Some(Ok(call)),
            // TODO should process exit end the iterator?
            Err(err) => Some(Err(err)),
        }
    }
}
