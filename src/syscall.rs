use core::str;
use std::{io, time::Duration};

use elf::{ElfBytes, endian::AnyEndian};
use libc::{sockaddr, socklen_t};
use log::{debug, info, trace, warn};
use new_types::{NewTypeSer, SocketType, sockaddr_ser};
use nix::{
    errno::Errno,
    fcntl::{self, OFlag},
    sys::{
        ptrace::Options,
        signal::Signal,
        socket::{self, AddressFamily},
        stat::{self, Mode},
    },
};
pub use parse_error::TraceError;
use rkyv::with;
use thiserror::Error;

use crate::{
    syscall::parse_error::{TraceErrEvt, TraceEvent},
    tracee::{PtraceSyscallInfo, PtraceSyscallInfoData, Tracee, WaitEvents, parse_syscall_error},
};

mod new_types;
pub use new_types::SyscallNewTypeError;

pub mod parse_error;
mod sock_type;

// FIXME many syscalls don't store their return values
#[derive(
    Debug,
    Clone,
    strum::EnumIs,
    strum::EnumDiscriminants,
    rkyv::Archive,
    rkyv::Serialize,
    rkyv::Deserialize,
    PartialEq,
    Eq,
)]
#[rkyv(derive(Debug))]
#[strum_discriminants(derive(strum::Display, rkyv::Archive, rkyv::Serialize, rkyv::Deserialize))]
pub enum SyscallInfo {
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
        #[rkyv(with = NewTypeSer)]
        domain: AddressFamily,
        r#type: SocketType,
        // TODO this could be SockProtocol from nix, if it was easy to parse
        protocol: i32,
    },
    Bind {
        sockfd: i32,
        // TODO the representation of all sockaddr could be a bit more readable by parsing it
        // differently
        #[rkyv(with = with::Map<sockaddr_ser>)]
        addr: Option<sockaddr>,
        addrlen: socklen_t,
    },
    Listen {
        sockfd: i32,
        backlog: i32,
    },
    Accept {
        sockfd: i32,
        // #[rkyv(with = ArchivedOption<Archivedsockaddr>)]
        #[rkyv(with = with::Map<sockaddr_ser>)]
        addr: Option<sockaddr>,
        addrlen: Option<socklen_t>,
    },
    Openat {
        dirfd: i32,
        pathname: Vec<u8>,
        #[rkyv(with = NewTypeSer)]
        flags: OFlag,
        #[rkyv(with = NewTypeSer)]
        mode: Mode,
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
    Unlink {
        pathname: Vec<u8>,
    },
    Unknown {
        id: u64,
        args: [u64; 6],
        return_value: i64,
    },
}

type SyscallDisc = SyscallInfoDiscriminants;

impl SyscallInfo {
    #[expect(
        clippy::too_many_lines,
        reason = "I will not be able to make this shorter"
    )]
    pub fn parse_until_return(
        tracee: &mut Tracee,
        syscall_info: PtraceSyscallInfo,
    ) -> Result<SyscallInfo, TraceErrEvt> {
        debug!("Parsing syscall entry...");
        let Some(PtraceSyscallInfoData::Entry {
            syscall_number,
            args,
        }) = syscall_info.data
        else {
            return Err(TraceErrEvt::Error(TraceError::InvalidSyscallInfo(
                syscall_info,
            )));
        };
        match syscall_number.cast_signed() {
            libc::SYS_read => {
                let read = tracee.parse_return(SyscallDisc::Read)?;
                let bytes = tracee.memcpy(args[1], read as usize)?;
                Ok(SyscallInfo::Read {
                    fd: args[0] as libc::c_int,
                    read_bytes: bytes,
                    requested_count: args[2].try_into().unwrap(),
                })
            }
            libc::SYS_write => {
                let text = tracee.memcpy(args[1], args[2] as usize)?;
                tracee.parse_return(SyscallDisc::Write)?;
                Ok(SyscallInfo::Write {
                    fd: args[0] as libc::c_int,
                    buf: text,
                })
            }
            libc::SYS_close => {
                tracee.parse_return(SyscallDisc::Close)?;
                Ok(SyscallInfo::Close {
                    fd: args[0] as libc::c_int,
                })
            }
            libc::SYS_socket => {
                tracee.parse_return(SyscallDisc::Socket)?;
                Ok(SyscallInfo::Socket {
                    domain: socket::AddressFamily::from_i32(args[0] as libc::c_int).unwrap(),
                    r#type: SocketType::try_from(args[1] as libc::c_int)?,
                    protocol: args[2] as libc::c_int,
                })
            }
            libc::SYS_accept => {
                let addrlen = if args[1] == 0 || args[2] == 0 {
                    None
                } else {
                    let bytes = tracee.memcpy(args[2], std::mem::size_of::<socklen_t>())?;
                    Some(socklen_t::from_ne_bytes(bytes.try_into().unwrap()))
                };
                tracee.parse_return(SyscallDisc::Accept)?;
                let sock_addr = tracee.memcpy_struct::<sockaddr>(args[1])?;
                Ok(SyscallInfo::Accept {
                    sockfd: args[0] as libc::c_int,
                    addr: sock_addr,
                    addrlen,
                })
            }
            libc::SYS_bind => {
                let sock_addr = tracee.memcpy_struct::<sockaddr>(args[1])?;
                tracee.parse_return(SyscallDisc::Bind)?;
                Ok(SyscallInfo::Bind {
                    sockfd: args[0] as libc::c_int,
                    addr: sock_addr,
                    addrlen: args[2] as socklen_t,
                })
            }
            libc::SYS_listen => {
                tracee.parse_return(SyscallDisc::Listen)?;
                Ok(SyscallInfo::Listen {
                    sockfd: args[0] as libc::c_int,
                    backlog: args[1] as libc::c_int,
                })
            }
            libc::SYS_clone => {
                // this is ONLY compatible with x86-64 and some other weird ass architectures
                let clone = SyscallInfo::Clone {
                    flags: args[0],
                    stack: args[1].try_into().unwrap(),
                    parent_tid: args[2].try_into().unwrap(),
                    child_tid: args[3].try_into().unwrap(),
                    tls: args[4],
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
            libc::SYS_execve => {
                let pathname = tracee.strcpy(args[0])?;
                bytes_as_string(&pathname);
                // when the process was called and what was its cmdline
                let argv = tracee.strcpy(args[1])?;
                let envp = tracee.strcpy(args[2])?;
                tracee.syscall()?;
                // tracee.parse_return(SyscallDisc::Execve)?;
                // Ok(Syscall::Execve { pathname,  argv, envp })
                if let WaitEvents::Exec = tracee.wait_for_stop()? {
                    tracee.parse_return(SyscallDisc::Execve)?;
                    Ok(SyscallInfo::Execve {
                        pathname,
                        argv,
                        envp,
                    })
                } else {
                    let return_value = tracee.read_rax()?;
                    Err(TraceErrEvt::Event(TraceEvent::SyscallError {
                        syscall: SyscallDisc::Execve,
                        error: parse_syscall_error(return_value),
                        rip: syscall_info.instruction_pointer,
                    }))
                }
            }
            libc::SYS_exit_group => Ok(SyscallInfo::ExitGroup {
                status: args[0] as libc::c_int,
            }),
            libc::SYS_openat => {
                let pathname = tracee.strcpy(args[1])?;
                tracee.parse_return(SyscallDisc::Openat)?;
                Ok(SyscallInfo::Openat {
                    dirfd: args[0] as libc::c_int,
                    pathname,
                    flags: fcntl::OFlag::from_bits(args[2] as libc::c_int).unwrap(),
                    mode: stat::Mode::from_bits(args[3] as libc::mode_t).unwrap(),
                })
            }
            libc::SYS_unlink => {
                let pathname = tracee.strcpy(args[1])?;
                tracee.parse_return(SyscallDisc::Unlink)?;
                Ok(SyscallInfo::Unlink { pathname })
            }
            _ => {
                warn!("Unknown syscall was called");
                tracee.syscall()?;
                tracee.wait_for_stop()?;
                let return_value = tracee.read_rax()?;
                Ok(SyscallInfo::Unknown {
                    id: syscall_number,
                    args,
                    return_value,
                })
            }
        }
    }
}

#[derive(PartialEq, Debug, rkyv::Archive, rkyv::Serialize, rkyv::Deserialize)]
pub struct Syscall {
    syscall: SyscallInfo,
    cpu_time: f64,
    // TODO this is the ELF address, but it should not be linked to 
    virt_addr_offset: usize,
}

impl Syscall {
    pub fn parse(tracee: &mut Tracee) -> Result<Syscall, TraceErrEvt> {
        tracee.wait_for_stop()?;
        let cpu_time = tracee.get_cpu_time();
        let syscall_info: PtraceSyscallInfo = tracee.syscall_info()?.into();
        let syscall = SyscallInfo::parse_until_return(tracee, syscall_info)?;

        let addr = tracee
                .translate_address_from_virtual(
                    syscall_info.instruction_pointer.try_into().unwrap(),
                )
                .unwrap()
                .unwrap();
        Ok(Self {
            syscall,
            cpu_time,
            virt_addr_offset: addr,
        })
    }
}

pub struct SyscallIterOpts {
    skip_to_main: bool,
    kill_on_exit: bool,
}

impl SyscallIterOpts {
    #[must_use]
    pub fn skip_to_main(mut self, value: bool) -> Self {
        self.skip_to_main = value;
        self
    }
    #[must_use]
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

#[derive(Debug, PartialEq, rkyv::Archive, rkyv::Serialize, rkyv::Deserialize)]
pub enum TraceData {
    Event(TraceEvent),
    Syscall(Syscall),
}

// TODO using Try trait could make this conversion not necessary for the design I want
impl TryFrom<Result<Syscall, TraceErrEvt>> for TraceData {
    type Error = TraceError;

    fn try_from(value: Result<Syscall, TraceErrEvt>) -> Result<Self, Self::Error> {
        match value {
            Ok(syscall) => Ok(TraceData::Syscall(syscall)),
            Err(err_evt) => match err_evt {
                TraceErrEvt::Error(trace_error) => Err(trace_error),
                TraceErrEvt::Event(trace_event) => Ok(TraceData::Event(trace_event)),
            },
        }
    }
}

#[derive(Error, Debug)]
pub enum SyscallIterError {
    #[error("error returned from ptrace")]
    PtraceError(#[from] Errno),
    // #[error("error returned from IO libraries")]
    // IOError(#[from] io::Error),
}

pub struct SyscallIter(Tracee);

impl SyscallIter {
    pub fn new(mut tracee: Tracee, opts: &SyscallIterOpts) -> Result<Self, SyscallIterError> {
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
            // this file does always exist, it can be guarded with a permission but that's a good
            // reason for failure anyway
            let file = std::fs::read("/proc/".to_owned() + &tracee.get_pid_string() + "/exe")
                .expect("could not access proc_pid_exe file");
            let elf = ElfBytes::<AnyEndian>::minimal_parse(file.as_slice()).unwrap();
            let entry_point = elf.ehdr.e_entry;

            // address needs to exist
            let main_address = tracee
                .translate_address_to_virtual(entry_point as usize)
                .expect("could not access proc_pid_maps file")
                .unwrap();
            trace!("creating hardware breakpoint on main() at address {main_address:#X}");
            tracee.add_local_breakpoint(main_address)?;

            tracee.cont()?;
            match tracee.wait_for_stop() {
                Ok(WaitEvents::Stopped(Signal::SIGTRAP)) => {
                    tracee.check_and_remove_break()?;
                }
                _ => panic!(),
            }
        }
        Ok(Self(tracee))
    }
}

impl Iterator for SyscallIter {
    type Item = Result<TraceData, TraceError>;

    fn next(&mut self) -> Option<Self::Item> {
        match self.0.syscall() {
            Err(Errno::ESRCH) => {
                return None;
            }
            Err(err) => return Some(Err(err.into())),
            _ => (),
        }
        Some(TraceData::try_from(Syscall::parse(&mut self.0)))
        // Some(Syscall::parse(&mut self.0).try_into())
        // match Syscall::parse(&mut self.0) {
        //     Ok(call) => Some(Ok(call)),
        //     Err(err) => Some(Err(err)),
        // }
    }
}

/// Try to convert a slice of bytes to UTF-8 string and prints it as debug log, if successful
fn bytes_as_string(bytes: &[u8]) {
    let text = str::from_utf8(bytes);
    if let Ok(text) = text {
        debug!("bytes as string: {text:?}");
    }
}
