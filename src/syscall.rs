use std::io;

use elf::{endian::AnyEndian, ElfBytes};
use libc::{c_void, mode_t, RAX};
use log::{debug, error, trace, warn};
use nix::{
    errno::Errno,
    sys::{
        ptrace::{self, Options},
        wait::{waitpid, WaitStatus},
    },
    unistd::Pid,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use utils::{
    get_return_value, parse_return, parse_syscall_error, read_bytes_memory, read_cstring,
    translate_address, wait_for_stop, WaitEvents,
};

mod utils;

#[derive(
    Debug, Clone, PartialEq, Serialize, Deserialize, strum::EnumIs, strum::EnumDiscriminants,
)]
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
    Execve {
        pathname: Vec<u8>,
        argv: Vec<u8>,
        envd: Vec<u8>,
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
pub struct SyscallArgs(usize, usize, usize, usize, usize, usize);

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
        S: serde::Serializer,
    {
        serializer.serialize_u32(20)
    }
}

impl Syscall {
    // TODO wait for next thread syscall from wait
    pub fn parse(pid: Pid) -> Result<Syscall, SyscallParseError> {
        debug!("Parsing syscall entry...");
        wait_for_stop(pid)?;
        let regs = ptrace::getregs(pid)?;
        // TODO this could read /proc/pid/syscall
        let args = SyscallArgs(
            regs.rdi as usize,
            regs.rsi as usize,
            regs.rdx as usize,
            regs.r10 as usize,
            regs.r8 as usize,
            regs.r9 as usize,
        );
        trace!("registers: {regs:?}");
        match regs.orig_rax {
            0 => {
                // TODO don't read it all
                let read = parse_return(pid, SyscallDisc::Read)?;
                let bytes = read_bytes_memory(pid, args.1, read as usize)?;
                Ok(Syscall::Read {
                    fd: args.0 as i32,
                    read_bytes: bytes,
                    requested_count: args.2,
                })
            }
            1 => {
                let text = read_bytes_memory(pid, args.1, args.2)?;
                trace!("address : {:#X}", args.1);
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
            59 => {
                let pathname = read_cstring(pid, args.0)?;
                let argv = read_cstring(pid, args.1)?;
                let envd = read_cstring(pid, args.2)?;
                ptrace::syscall(pid, None)?;
                let wait = wait_for_stop(pid)?;
                let ret = parse_return(pid, SyscallDisc::Execve)?;
                trace!("return value: {ret}");
                match wait {
                    WaitEvents::Exec => Ok(Syscall::Execve {
                        pathname,
                        argv,
                        envd,
                    }),
                    _ => {
                        let return_value = ptrace::read_user(pid, (RAX * 8) as *mut c_void)?;
                        Err(SyscallParseError::SyscallError {
                            syscall: SyscallDisc::Execve,
                            error: parse_syscall_error(return_value),
                        })
                    }
                }
            }
            231 => Ok(Syscall::ExitGroup {
                status: args.0 as i32,
            }),
            257 => {
                let pathname = read_cstring(pid, args.1)?;
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
                Ok(Syscall::Unknown {
                    id: regs.orig_rax,
                    args,
                    return_value,
                })
            }
        }
    }
}

pub struct SyscallIterOpts {
    skip_to_main: bool,
    kill_on_exit: bool,
}

impl SyscallIterOpts {
    pub fn skip_to_main(mut self, value: bool) -> Self {
        self.skip_to_main = value;
        self
    }
    pub fn kill_on_exit(mut self, value: bool) -> Self {
        self.kill_on_exit = value;
        self
    }
}

impl Default for SyscallIterOpts {
    fn default() -> Self {
        Self {
            skip_to_main: true,
            kill_on_exit: true,
        }
    }
}

#[derive(Error, Debug)]
pub enum SyscallIterError {
    #[error("error returned from ptrace")]
    PtraceError(#[from] Errno),
    #[error("error returned from IO libraries")]
    IOError(#[from] io::Error),
}

pub struct SyscallIter(Pid);

impl SyscallIter {
    pub fn new(pid: Pid, opts: SyscallIterOpts) -> Result<Self, SyscallIterError> {
        let mut options = Options::PTRACE_O_TRACESYSGOOD
            | Options::PTRACE_O_TRACEEXEC
            | Options::PTRACE_O_TRACEFORK
            | Options::PTRACE_O_TRACECLONE;
        if opts.kill_on_exit {
            options |= Options::PTRACE_O_EXITKILL;
        }
        ptrace::setoptions(pid, options)?;
        if opts.skip_to_main {
            let file = std::fs::read("/proc/".to_owned() + &pid.to_string() + "/exe")?;
            let elf = ElfBytes::<AnyEndian>::minimal_parse(file.as_slice()).unwrap();
            let entry_point = elf.ehdr.e_entry;

            debug!("creating breakpoint on main()");
            let main_address = translate_address(pid, entry_point as usize)?.unwrap();
            let main_addr_void = main_address as *mut c_void;
            let original_word = ptrace::read(pid, main_addr_void)?;
            trace!("original word: {original_word:#X}");
            // FIXME this isn't gonna be compatible outside of x86
            ptrace::write(pid, main_addr_void, 0xCC)?;

            ptrace::cont(pid, None)?;
            match waitpid(pid, None) {
                Ok(WaitStatus::Stopped(_, _)) => {
                    trace!("stopped on main");
                    ptrace::write(pid, main_addr_void, original_word)?;
                }
                _ => panic!(),
            }
        }
        Ok(Self(pid))
    }
}

impl Iterator for SyscallIter {
    type Item = Result<Syscall, SyscallParseError>;

    fn next(&mut self) -> Option<Self::Item> {
        match ptrace::syscall(self.0, None) {
            Err(Errno::ESRCH) => {
                return None;
            }
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
