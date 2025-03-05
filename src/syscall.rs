use core::str;
use std::{io, str::Utf8Error};

use clap::error;
use elf::{endian::AnyEndian, ElfBytes};
use libc::{c_void, user_regs_struct, RAX};
use log::{debug, error, trace, warn};
use nix::{
    errno::Errno,
    fcntl,
    sched::CloneFlags,
    sys::{
        ptrace::{self, Options},
        signal::Signal,
        socket::{self, socket},
        stat,
        wait::{waitpid, WaitStatus},
    },
};
use serde::{Deserialize, Serialize};
use sock_type::SocketType;
use thiserror::Error;

use crate::tracee::{parse_syscall_error, Tracee, WaitEvents};

mod sock_type;

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
    Socket {
        domain: socket::AddressFamily,
        r#type: SocketType,
        // FIXME this could be SockProtocol from nix
        protocol: i32,
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
        // TODO eventually use nix::sched::CloneFlags, currently they don't support all the flags
        flags: u64,
        stack: usize,
        /// Pointer to i32 in child
        parent_tid: usize,
        /// Pointer to i32 in child
        child_tid: usize,
        tls: u64,
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
    // FIXME this isn't really a parse error
    #[error("tracee terminated by OS")]
    Terminated { signal: Signal, core_dumped: bool },
}

impl Serialize for SyscallParseError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_u32(20)
    }
}

fn bytes_as_string(bytes: &[u8]) {
    let text = str::from_utf8(bytes);
    if let Ok(text) = text {
        debug!("bytes as string: {text:?}");
    }
}

impl Syscall {
    // TODO wait for next thread syscall from wait
    pub fn parse(tracee: &mut Tracee) -> Result<Syscall, SyscallParseError> {
        debug!("Parsing syscall entry...");
        tracee.wait_for_stop()?;
        let regs = tracee.getregs()?;
        // TODO this could read /proc/pid/syscall
        let args = SyscallArgs::new(&regs);
        trace!("registers: {regs:?}");
        match regs.orig_rax {
            0 => {
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
                bytes_as_string(&text);
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
            41 => {
                tracee.parse_return(SyscallDisc::Socket)?;
                Ok(Syscall::Socket {
                    domain: socket::AddressFamily::from_i32(args.0 as i32).unwrap(),
                    r#type: SocketType::from(args.1 as i32),
                    protocol: args.2 as i32,
                })
            }
            56 => {
                // this is ONLY compatible with x86-64 and some other weird ass architectures
                let clone = Syscall::Clone {
                    flags: args.0 as u64,
                    stack: args.1,
                    parent_tid: args.2,
                    child_tid: args.3,
                    tls: args.4 as u64,
                };
                // FIXME the logic is incorrect, it should check if the second wait is clone
                tracee.parse_return(SyscallDisc::Clone)?;
                Ok(clone)
                // tracee.syscall()?;
                // match tracee.wait_for_stop()? {
                //     WaitEvents::Clone => {
                //         tracee.parse_return(SyscallDisc::Clone)?;
                //         Ok(clone)
                //     }
                //     _ => {
                //         let return_value = ptrace::read_user(tracee.pid, (RAX * 8) as *mut c_void)?;
                //         Err(SyscallParseError::SyscallError {
                //             syscall: SyscallDisc::Clone,
                //             error: parse_syscall_error(return_value),
                //         })
                //     }
                // }
            }
            59 => {
                let pathname = tracee.strcpy(args.0)?;
                bytes_as_string(&pathname);
                // kdo ho zavolal, kdy a jaká je cmdline
                let argv = tracee.strcpy(args.1)?;
                let envp = tracee.strcpy(args.2)?;
                tracee.syscall()?;
                match tracee.wait_for_stop()? {
                    WaitEvents::Exec => {
                        tracee.parse_return(SyscallDisc::Execve)?;
                        Ok(Syscall::Execve {
                            pathname,
                            argv,
                            envp,
                        })
                    }
                    _ => {
                        let return_value = tracee.read_rax()?;
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
                bytes_as_string(&pathname);
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
                tracee.syscall()?;
                tracee.wait_for_stop()?;
                let return_value = tracee.read_rax()?;
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
    pub fn new(mut tracee: Tracee, opts: SyscallIterOpts) -> Result<Self, SyscallIterError> {
        let mut options = Options::PTRACE_O_TRACESYSGOOD;
        // | Options::PTRACE_O_TRACEEXEC
        // | Options::PTRACE_O_TRACEFORK
        // | Options::PTRACE_O_TRACECLONE;
        if opts.kill_on_exit {
            options |= Options::PTRACE_O_EXITKILL;
        }
        tracee.setoptions(options)?;
        if opts.skip_to_main {
            let file = std::fs::read("/proc/".to_owned() + &tracee.get_pid_string() + "/exe")?;
            let elf = ElfBytes::<AnyEndian>::minimal_parse(file.as_slice()).unwrap();
            let entry_point = elf.ehdr.e_entry;

            debug!("creating breakpoint on main()");
            let main_address = tracee.translate_address(entry_point as usize)?.unwrap();
            let main_addr_void = main_address as *mut c_void;
            let original_word = tracee.read(main_addr_void)?;
            trace!("original word: {original_word:#X}");
            // FIXME this isn't gonna be compatible outside of x86
            tracee.write(main_addr_void, 0xCC)?;

            tracee.cont()?;
            match tracee.wait_for_stop() {
                Ok(WaitEvents::Stopped(_)) => {
                    trace!("stopped on main");
                    tracee.write(main_addr_void, original_word)?;
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
        match self.0.syscall() {
            Err(Errno::ESRCH) => {
                return None;
            }
            Err(err) => return Some(Err(err.into())),
            _ => (),
        };
        match Syscall::parse(&mut self.0) {
            Ok(call) => Some(Ok(call)),
            // TODO should process exit end the iterator?
            Err(err) => Some(Err(err)),
        }
    }
}
