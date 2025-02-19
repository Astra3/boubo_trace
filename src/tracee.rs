use std::{
    ffi::c_void,
    fs::File,
    io::{self, BufRead, BufReader, IoSliceMut},
};

use libc::{PTRACE_EVENT_EXEC, PTRACE_EVENT_FORK, RAX};
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

pub enum WaitEvents {
    Syscall,
    Fork,
    Exec,
    Stopped,
}

const MAX_BYTES_CSTRING: usize = 2048 * 1024; // 2 MiB
const BUFFER_SIZE: usize = 128;

pub struct Tracee {
    pub(crate) pid: Pid,
}

impl Tracee {
    pub fn new(pid: Pid) -> Tracee {
        Tracee { pid }
    }

    pub fn wait_for_stop(&self) -> Result<WaitEvents, SyscallParseError> {
        match waitpid(self.pid, None) {
            Ok(WaitStatus::PtraceEvent(_, Signal::SIGTRAP, PTRACE_EVENT_EXEC)) => {
                warn!("stopped on ptrace event exec");
                Ok(WaitEvents::Exec)
            }
            Ok(WaitStatus::PtraceEvent(_, Signal::SIGTRAP, PTRACE_EVENT_FORK)) => {
                Ok(WaitEvents::Fork)
            }
            Ok(WaitStatus::PtraceSyscall(_)) => Ok(WaitEvents::Syscall),
            Ok(WaitStatus::Stopped(_, _)) => {
                warn!("non-syscall stop");
                Ok(WaitEvents::Stopped)
            }
            Ok(WaitStatus::Exited(_, exit_code)) => {
                info!("Process exited");
                Err(SyscallParseError::ProcessExit(exit_code))
            }
            Ok(status) => Err(SyscallParseError::UnexpectedWaitStatus(status)),
            Err(err) => Err(SyscallParseError::WaitPidError(err)),
        }
    }

    pub fn memcpy(&self, base: usize, len: usize) -> Result<Vec<u8>, Errno> {
        let mut data = vec![0; len];
        process_vm_readv(
            self.pid,
            &mut [IoSliceMut::new(&mut data)],
            &[RemoteIoVec { base, len }],
        )?;
        Ok(data)
    }

    // FIXME does this actually work?
    pub fn memcpy_until<T>(&self, base: usize, function: T) -> Result<Vec<u8>, Errno>
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
        Ok(data)
    }

    pub fn strcpy(&self, base: usize) -> Result<Vec<u8>, Errno> {
        self.memcpy_until(base, |num| *num == 0)
    }

    pub fn get_return_value(&self) -> Result<i64, SyscallParseError> {
        debug!("Parsing syscall exit...");
        ptrace::syscall(self.pid, None)?;
        self.wait_for_stop()?;
        trace!("exit regs: {:?}", ptrace::getregs(self.pid)?);
        Ok(ptrace::read_user(self.pid, (RAX * 8) as *mut c_void)?)
    }

    pub fn parse_return(&self, syscall: SyscallDiscriminants) -> Result<i64, SyscallParseError> {
        let ret = self.get_return_value()?;
        trace!("return value: {ret}");
        if ret < 0 {
            return Err(SyscallParseError::SyscallError {
                syscall,
                error: parse_syscall_error(ret),
            });
        }
        Ok(ret)
    }

    // TODO optimize this
    pub fn translate_address(
        &self,
        requested_addr: usize,
    ) -> Result<Option<usize>, io::Error> {
        let pid_text = self.pid.to_string();
        let file = File::open("/proc/".to_string() + &pid_text + "/task/" + &pid_text + "/maps")?;
        let reader = BufReader::new(file);
        for line in reader.lines() {
            let line = line?;
            let mut it = line.split_whitespace();
            let section = it.next().unwrap();
            let mut numbers = section.split("-");

            // FIXME surely this cannot fail
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
}

pub fn parse_syscall_error(return_value: i64) -> Errno {
    Errno::from_raw(-return_value as i32)
}
