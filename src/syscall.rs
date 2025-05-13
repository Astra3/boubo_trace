use core::str;
use std::io;

use elf::{ElfBytes, endian::AnyEndian};
use libc::{sockaddr, socklen_t};
use log::{debug, error, trace, warn};
use new_types::{AddressFamilySer, ModeSer, OFlagSer, SocketType, sockaddr_ser};
use nix::{
    errno::Errno,
    fcntl,
    sys::{
        ptrace::Options,
        signal::Signal,
        socket::{self},
        stat,
    },
};
pub use parse_error::SyscallParseError;
pub use syscall_args::SyscallArgs;
use thiserror::Error;

use crate::tracee::{Tracee, WaitEvents, parse_syscall_error};

mod new_types;
pub mod parse_error;
mod sock_type;
pub mod syscall_args;

// FIXME many syscalls don't store their return values
#[derive(Debug, Clone, strum::EnumIs, strum::EnumDiscriminants, serde::Serialize)]
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
    Socket {
        domain: AddressFamilySer,
        r#type: SocketType,
        // TODO this could be SockProtocol from nix, if it was easy to parse
        protocol: i32,
    },
    Bind {
        sockfd: i32,
        // TODO the representation of all sockaddr could be a bit more readable by parsing it
        // differently
        addr: Option<sockaddr_ser>,
        addrlen: socklen_t,
    },
    Listen {
        sockfd: i32,
        backlog: i32,
    },
    Accept {
        sockfd: i32,
        addr: Option<sockaddr_ser>,
        addrlen: Option<socklen_t>,
    },
    Openat {
        dirfd: i32,
        pathname: Vec<u8>,
        flags: OFlagSer,
        mode: ModeSer,
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

type SyscallDisc = SyscallDiscriminants;

impl Syscall {
    pub fn parse(tracee: &mut Tracee) -> Result<Syscall, SyscallParseError> {
        debug!("Parsing syscall entry...");
        tracee.wait_for_stop()?;
        let regs = tracee.getregs()?;
        // TODO this could read /proc/pid/syscall
        let args = SyscallArgs::new(&regs);
        trace!("registers: {regs:?}");
        trace!("args: {args:?}");
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
                    domain: socket::AddressFamily::from_i32(args.0 as i32)
                        .unwrap()
                        .into(),
                    r#type: SocketType::from(args.1 as i32),
                    protocol: args.2 as i32,
                })
            }
            43 => {
                let addrlen = if args.1 == 0 || args.2 == 0 {
                    None
                } else {
                    let bytes = tracee.memcpy(args.2, std::mem::size_of::<socklen_t>())?;
                    Some(socklen_t::from_ne_bytes(bytes.try_into().unwrap()))
                };
                tracee.parse_return(SyscallDisc::Accept)?;
                let sock_addr = tracee.memcpy_struct::<sockaddr>(args.1)?;
                Ok(Syscall::Accept {
                    sockfd: args.0 as i32,
                    addr: sock_addr.map(Into::into),
                    addrlen,
                })
            }
            49 => {
                let sock_addr = tracee.memcpy_struct::<sockaddr>(args.1)?;
                tracee.parse_return(SyscallDisc::Bind)?;
                Ok(Syscall::Bind {
                    sockfd: args.0 as i32,
                    addr: sock_addr.map(Into::into),
                    addrlen: args.2 as socklen_t,
                })
            }
            50 => {
                tracee.parse_return(SyscallDisc::Listen)?;
                Ok(Syscall::Listen {
                    sockfd: args.0 as i32,
                    backlog: args.1 as i32,
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
                // when the process was called and what was its cmdline
                let argv = tracee.strcpy(args.1)?;
                let envp = tracee.strcpy(args.2)?;
                tracee.syscall()?;
                // tracee.parse_return(SyscallDisc::Execve)?;
                // Ok(Syscall::Execve { pathname,  argv, envp })
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
                    flags: fcntl::OFlag::from_bits(args.2 as i32).unwrap().into(),
                    // mode: args.3 as u32,
                    mode: stat::Mode::from_bits(args.3 as u32).unwrap().into(),
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
        let mut options = Options::PTRACE_O_TRACESYSGOOD
            // execve is more reliable with this
        | Options::PTRACE_O_TRACEEXEC;
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

            let main_address = tracee.translate_address(entry_point as usize)?.unwrap();
            debug!("creating hardware breakpoint on main() at address {main_address:#X}");
            tracee.add_local_breakpoint(main_address)?;

            tracee.cont()?;
            match tracee.wait_for_stop() {
                Ok(WaitEvents::Stopped(Signal::SIGTRAP)) => {
                    trace!("stopped on main");
                    tracee.check_break()?;
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
            Err(err) => Some(Err(err)),
        }
    }
}

/// Try to convert a slice of bytes to UTF-8 string and prints it as debug log, if successful
fn bytes_as_string(bytes: &[u8]) {
    let text = str::from_utf8(bytes);
    if let Ok(text) = text {
        debug!("bytes as string: {text:?}");
    }
}
