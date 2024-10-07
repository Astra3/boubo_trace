use libc::{mode_t, user_regs_struct};
use log::{debug, trace, warn};
use nix::{
    errno::Errno,
    sys::{
        ptrace,
        wait::{waitpid, WaitStatus},
    },
    unistd::Pid,
};
use thiserror::Error;
use utils::{get_return_value, parse_return, read_cstring, read_string_memory};

mod utils;

#[derive(Debug, Clone, strum::EnumIs, strum::EnumDiscriminants)]
#[strum_discriminants(derive(strum::Display))]
pub enum SysCall {
    Write {
        fd: usize,
        buf: Vec<u8>,
    },
    OpenAt {
        dirfd: i32,
        pathname: Vec<u8>,
        flags: i32,
        mode: mode_t,
    },
    SysExitGroup {
        status: i32,
    },
    Unknown(user_regs_struct),
}

type SysCallDisc = SysCallDiscriminants;

#[derive(Error, Debug)]
pub enum SyscallParseError {
    #[error("error in tracee's syscall")]
    SyscallError {
        syscall: SysCallDiscriminants,
        error: Errno,
    },
    #[error("error in ptrace call: {0:?}")]
    PtraceError(#[from] Errno),
    #[error("tracee process is not running")]
    ProcessExit,
}

impl SysCall {
    // TODO handle syscall errors
    pub fn parse(pid: Pid) -> Result<SysCall, SyscallParseError> {
        debug!("Parsing syscall entry...");
        match waitpid(pid, None) {
            Ok(WaitStatus::Stopped(_, _)) => {
                let regs = ptrace::getregs(pid)?;
                let args = (regs.rdi, regs.rsi, regs.rdx, regs.r10, regs.r8, regs.r9);
                trace!("registers: {regs:X?}");
                match regs.orig_rax {
                    1 => {
                        let text = read_string_memory(pid, args.1 as usize, args.2 as usize)?;
                        parse_return(pid, SysCallDisc::Write)?;
                        Ok(SysCall::Write {
                            fd: args.0 as usize,
                            buf: text,
                        })
                    }
                    231 => Ok(SysCall::SysExitGroup {
                        status: args.0 as i32,
                    }),
                    257 => {
                        let pathname = read_cstring(pid, args.1 as usize)?;
                        parse_return(pid, SysCallDisc::OpenAt)?;
                        Ok(SysCall::OpenAt {
                            dirfd: args.0 as i32,
                            pathname,
                            flags: args.2 as i32,
                            mode: mode_t::from(args.3 as u32),
                        })
                    }
                    _ => {
                        warn!("Unknown syscall was called");
                        get_return_value(pid)?;
                        Ok(SysCall::Unknown(regs))
                    }
                }
            }
            Ok(WaitStatus::Exited(_, _)) => Err(SyscallParseError::ProcessExit),
            _ => panic!(),
        }
    }
}

