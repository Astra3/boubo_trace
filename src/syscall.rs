use core::str;
use std::io;

use elf::{endian::AnyEndian, ElfBytes};
use libc::{c_void, user_regs_struct, RAX};
use log::{debug, error, trace, warn};
use nix::{
    errno::Errno,
    fcntl,
    sched::CloneFlags,
    sys::{
        ptrace::{self, Options},
        stat,
        wait::{waitpid, WaitStatus},
    },
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::tracee::{parse_syscall_error, Tracee, WaitEvents};

#[derive(Debug, Clone, PartialEq, strum::EnumIs, strum::EnumDiscriminants)]
#[strum_discriminants(derive(strum::Display))]
// #[serde(rename_all = "snake_case")]
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
        flags: fcntl::OFlag,
        mode: stat::Mode,
    },
    Execve {
        pathname: Vec<u8>,
        argv: Vec<u8>,
        envp: Vec<u8>,
    },
    // this is ONLY FOR x86-64
    Clone {
        flags: CloneFlags,
        stack: usize,
        /// Pointer to i32 in child
        parent_tid: usize,
        tls: u64,
        /// Pointer to i32 in child
        child_tid: usize,
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

impl SyscallArgs {
    pub fn new(regs: &user_regs_struct) -> SyscallArgs {
        SyscallArgs(
            regs.rdi as usize,
            regs.rsi as usize,
            regs.rdx as usize,
            regs.r10 as usize,
            regs.r8 as usize,
            regs.r9 as usize,
        )
    }
}

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
    pub fn parse(tracee: &Tracee) -> Result<Syscall, SyscallParseError> {
        debug!("Parsing syscall entry...");
        tracee.wait_for_stop()?;
        let regs = ptrace::getregs(tracee.pid)?;
        // TODO this could read /proc/pid/syscall
        let args = SyscallArgs::new(&regs);
        trace!("registers: {regs:?}");
        match regs.orig_rax {
            0 => {
                // TODO don't read it all
                let read = tracee.parse_return(SyscallDisc::Read)?;
                let bytes = tracee.memcpy(args.1, read as usize)?;
                Ok(Syscall::Read {
                    fd: args.0 as i32,
                    read_bytes: bytes,
                    requested_count: args.2,
                })
            }
            1 => {
                let text = tracee.memcpy(args.1, args.2)?;
                trace!("address : {:#X}", args.1);
                tracee.parse_return(SyscallDisc::Write)?;
                Ok(Syscall::Write {
                    fd: args.0 as i32,
                    buf: text,
                })
            }
            3 => {
                tracee.parse_return(SyscallDisc::Close)?;
                Ok(Syscall::Close { fd: args.0 as i32 })
            }
            // 56 => {
            //     // this is ONLY compatible with x86-64 and some other weird ass architectures
            //     let clone = Syscall::Clone {
            //         flags: CloneFlags::empty(),
            //         stack: args.1,
            //         parent_tid: args.2,
            //         tls: args.3 as u64,
            //         child_tid: args.4,
            //     };
            //     trace!(
            //         "clone flags: {}, {:#?}",
            //         args.0 as i32,
            //         CloneFlags::from_bits_truncate(args.0 as i32)
            //     );
            //     ptrace::cont(tracee.pid, None)?;
            //     tracee.wait_for_stop()?;
            //     tracee.parse_return(SyscallDisc::Clone)?;
            //     Ok(clone)
            // }
            59 => {
                let pathname = tracee.strcpy(args.0)?;
                trace!("pathname: {}", str::from_utf8(&pathname).unwrap_or("cannot decode"));
                let argv = tracee.strcpy(args.1)?;
                let envp = tracee.strcpy(args.2)?;
                ptrace::syscall(tracee.pid, None)?;
                let wait = tracee.wait_for_stop()?;
                tracee.parse_return(SyscallDisc::Execve)?;
                match wait {
                    WaitEvents::Exec => Ok(Syscall::Execve {
                        pathname,
                        argv,
                        envp,
                    }),
                    _ => {
                        let return_value = ptrace::read_user(tracee.pid, (RAX * 8) as *mut c_void)?;
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
                let pathname = tracee.strcpy(args.1)?;
                tracee.parse_return(SyscallDisc::Openat)?;
                Ok(Syscall::Openat {
                    dirfd: args.0 as i32,
                    pathname,
                    // flags: args.2 as i32,
                    flags: fcntl::OFlag::from_bits(args.2 as i32).unwrap(),
                    // mode: args.3 as u32,
                    mode: stat::Mode::from_bits(args.3 as u32).unwrap(),
                })
            }
            _ => {
                warn!("Unknown syscall was called");
                let return_value = tracee.get_return_value()?;
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

pub struct SyscallIter(Tracee);

impl SyscallIter {
    pub fn new(tracee: Tracee, opts: SyscallIterOpts) -> Result<Self, SyscallIterError> {
        let mut options = Options::PTRACE_O_TRACESYSGOOD
            | Options::PTRACE_O_TRACEEXEC
            | Options::PTRACE_O_TRACEFORK
            | Options::PTRACE_O_TRACECLONE;
        if opts.kill_on_exit {
            options |= Options::PTRACE_O_EXITKILL;
        }
        ptrace::setoptions(tracee.pid, options)?;
        if opts.skip_to_main {
            let file = std::fs::read("/proc/".to_owned() + &tracee.pid.to_string() + "/exe")?;
            let elf = ElfBytes::<AnyEndian>::minimal_parse(file.as_slice()).unwrap();
            let entry_point = elf.ehdr.e_entry;

            debug!("creating breakpoint on main()");
            let main_address = tracee.translate_address(entry_point as usize)?.unwrap();
            let main_addr_void = main_address as *mut c_void;
            let original_word = ptrace::read(tracee.pid, main_addr_void)?;
            trace!("original word: {original_word:#X}");
            // FIXME this isn't gonna be compatible outside of x86
            ptrace::write(tracee.pid, main_addr_void, 0xCC)?;

            ptrace::cont(tracee.pid, None)?;
            match waitpid(tracee.pid, None) {
                Ok(WaitStatus::Stopped(_, _)) => {
                    trace!("stopped on main");
                    ptrace::write(tracee.pid, main_addr_void, original_word)?;
                }
                _ => panic!(),
            }
        }
        Ok(Self(tracee))
    }
}

impl Iterator for SyscallIter {
    type Item = Result<Syscall, SyscallParseError>;

    fn next(&mut self) -> Option<Self::Item> {
        match ptrace::syscall(self.0.pid, None) {
            Err(Errno::ESRCH) => {
                return None;
            }
            Err(err) => return Some(Err(err.into())),
            _ => (),
        };
        match Syscall::parse(&self.0) {
            Ok(call) => Some(Ok(call)),
            // TODO should process exit end the iterator?
            Err(err) => Some(Err(err)),
        }
    }
}
