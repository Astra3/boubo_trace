use std::{
    ffi::c_void,
    fs::File,
    io::{self, BufRead, BufReader, IoSliceMut},
};

use libc::{
    c_long, user_regs_struct, PTRACE_EVENT_CLONE, PTRACE_EVENT_EXEC, PTRACE_EVENT_FORK, RAX,
};
use log::{debug, info, trace, warn};
use nix::{
    errno::Errno,
    sys::{
        ptrace,
        signal::Signal,
        uio::{process_vm_readv, RemoteIoVec},
        wait::{waitpid, WaitStatus},
    },
    unistd::Pid,
};

use crate::syscall::{SyscallDiscriminants, SyscallParseError};

#[derive(strum::EnumIs)]
pub enum WaitEvents {
    Syscall,
    Fork,
    Exec,
    Stopped(Signal),
    Clone,
}

#[derive(Default)]
struct SignalStorage {
    signal: Option<Signal>,
}

impl SignalStorage {
    pub fn store(&mut self, signal: Signal) {
        if signal != Signal::SIGTRAP {
            self.signal = Some(signal);
        }
    }

    pub fn get(&mut self) -> Option<Signal> {
        let signal = self.signal;
        self.signal = None;
        signal
    }
}

// TODO allow configuring this
const MAX_BYTES_CSTRING: usize = 2048 * 1024; // 2 MiB
const BUFFER_SIZE: usize = 128;

type ErrnoResult<T> = Result<T, Errno>;

pub struct Tracee {
    pid: Pid,
    signal: SignalStorage,
}

impl Tracee {
    pub fn new(pid: Pid) -> Tracee {
        Tracee {
            pid,
            signal: SignalStorage::default(),
        }
    }

    // TODO add a wait_for_syscall_stop type of method here, apply this for SIGTRAP
    pub fn wait_for_stop(&mut self) -> Result<WaitEvents, SyscallParseError> {
        match waitpid(self.pid, None) {
            Ok(WaitStatus::PtraceEvent(_, Signal::SIGTRAP, PTRACE_EVENT_EXEC)) => {
                warn!("stopped on ptrace event exec");
                Ok(WaitEvents::Exec)
            }
            Ok(WaitStatus::PtraceEvent(_, Signal::SIGTRAP, PTRACE_EVENT_FORK)) => {
                Ok(WaitEvents::Fork)
            }
            Ok(WaitStatus::PtraceEvent(_, Signal::SIGTRAP, PTRACE_EVENT_CLONE)) => {
                Ok(WaitEvents::Clone)
            }
            Ok(WaitStatus::PtraceSyscall(_)) => Ok(WaitEvents::Syscall),
            Ok(WaitStatus::Stopped(_, signal)) => {
                trace!("tracee stopped on signal {signal:?}");
                self.signal.store(signal);
                // FIXME this is here to be able to run programs with fork in them
                if signal == Signal::SIGCHLD {
                    trace!("continuing on SIGCHLD");
                    self.syscall()?;
                    return self.wait_for_stop()
                }
                Ok(WaitEvents::Stopped(signal))
            }
            Ok(WaitStatus::Exited(_, exit_code)) => {
                info!("Process exited");
                Err(SyscallParseError::ProcessExit(exit_code))
            }
            Ok(WaitStatus::Signaled(pid, signal, core_dumped)) => {
                warn!("tracee {pid:?} was signaled {signal:?} and dumped core: {core_dumped}");
                Err(SyscallParseError::Terminated {
                    signal,
                    core_dumped,
                })
            }
            Ok(status) => Err(SyscallParseError::UnexpectedWaitStatus(status)),
            Err(err) => Err(SyscallParseError::WaitPidError(err)),
        }
    }

    pub fn memcpy(&self, base: usize, len: usize) -> ErrnoResult<Vec<u8>> {
        let mut data = vec![0; len];
        if base == 0 { return Ok(vec![0]) }
        process_vm_readv(
            self.pid,
            &mut [IoSliceMut::new(&mut data)],
            &[RemoteIoVec { base, len }],
        )?;
        Ok(data)
    }

    pub fn memcpy_struct<T>(&self, base: usize) -> ErrnoResult<Option<T>>
    where
        T: Clone + Copy,
    {
        if base == 0 { return Ok(None) }
        let bytes = self.memcpy(base, std::mem::size_of::<T>())?;
        let (_, sock_addr, _) = unsafe { bytes.align_to::<T>() };
        Ok(Some(sock_addr[0]))
    }

    // FIXME does this actually work?
    pub fn memcpy_until<T>(&self, base: usize, function: T) -> ErrnoResult<Vec<u8>>
    where
        T: Fn(&u8) -> bool,
    {
        if base == 0 {
            return Ok(vec![0]);
        }
        let mut data = vec![];
        let mut buf = [0; BUFFER_SIZE];
        let mut total_bytes_read = 0usize;

        while data.len() < MAX_BYTES_CSTRING {
            total_bytes_read += process_vm_readv(
                self.pid,
                &mut [IoSliceMut::new(&mut buf)],
                &[RemoteIoVec {
                    base: base + total_bytes_read,
                    len: BUFFER_SIZE,
                }],
            )?;

            // if let Some(index) = buf.iter().position(|num| *num == 0) {
            if let Some(index) = buf.iter().position(&function) {
                data.extend_from_slice(&buf[..index + 1]);
                break;
            }
            data.extend_from_slice(&buf);
        }
        if data.len() >= MAX_BYTES_CSTRING - 1 {
            debug!("reached memcpy_until byte read limit");
        }
        Ok(data)
    }

    pub fn strcpy(&self, base: usize) -> ErrnoResult<Vec<u8>> {
        self.memcpy_until(base, |num| *num == 0)
    }

    pub fn read_rax(&self) -> Result<i64, SyscallParseError> {
        Ok(ptrace::read_user(self.pid, (RAX * 8) as *mut c_void)?)
    }

    pub fn getregs(&self) -> ErrnoResult<user_regs_struct> {
        ptrace::getregs(self.pid)
    }

    pub fn read(&self, addr: usize) -> ErrnoResult<c_long> {
        ptrace::read(self.pid, addr as *mut c_void)
    }

    pub fn write(&self, addr: usize, data: c_long) -> ErrnoResult<()> {
        ptrace::write(self.pid, addr as *mut c_void, data)
    }

    pub fn setoptions(&self, options: ptrace::Options) -> ErrnoResult<()> {
        ptrace::setoptions(self.pid, options)
    }

    pub fn parse_return(
        &mut self,
        syscall: SyscallDiscriminants,
    ) -> Result<i64, SyscallParseError> {
        debug!("parsing return...");
        self.syscall()?;
        self.wait_for_stop()?;
        trace!("exit regs: {:?}", ptrace::getregs(self.pid)?);

        let ret = self.read_rax()?;
        debug!("return value: {ret}");
        if ret < 0 {
            return Err(SyscallParseError::SyscallError {
                syscall,
                error: parse_syscall_error(ret),
            });
        }
        Ok(ret)
    }

    pub fn syscall(&mut self) -> ErrnoResult<()> {
        ptrace::syscall(self.pid, self.signal.get())
    }

    pub fn cont(&mut self) -> ErrnoResult<()> {
        ptrace::cont(self.pid, self.signal.get())
    }

    pub fn translate_address(&self, requested_addr: usize) -> Result<Option<usize>, io::Error> {
        let pid_text = self.pid.to_string();
        let file = File::open("/proc/".to_string() + &pid_text + "/task/" + &pid_text + "/maps")?;
        let reader = BufReader::new(file);
        for line in reader.lines() {
            let line = line?;
            let mut it = line.split_whitespace();
            let section = it.next().unwrap();
            let mut numbers = section.split("-");

            let start = usize::from_str_radix(numbers.next().unwrap(), 16).unwrap();
            let stop = usize::from_str_radix(numbers.next().unwrap(), 16).unwrap();

            // permissions
            it.next();
            let offset = usize::from_str_radix(it.next().unwrap(), 16).unwrap();
            if requested_addr < offset {
                continue;
            }

            let difference = stop - start;
            if requested_addr <= offset + difference {
                return Ok(Some(start + requested_addr - offset));
            }
            continue;
        }

        Ok(None)
    }

    pub fn get_pid_string(&self) -> String {
        self.pid.to_string()
    }
}

pub fn parse_syscall_error(return_value: i64) -> Errno {
    Errno::from_raw(-return_value as i32)
}
