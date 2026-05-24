use std::{
    ffi::c_void,
    fs::File,
    io::{self, BufRead, BufReader, IoSliceMut},
    mem,
    os::raw::c_ulonglong,
    sync::LazyLock,
};

use libc::{
    PTRACE_EVENT_CLONE, PTRACE_EVENT_EXEC, PTRACE_EVENT_FORK, RAX, c_long, user_regs_struct,
};
use log::{debug, error, trace, warn};
use nix::{
    errno::Errno,
    sys::{
        ptrace::{self},
        signal::Signal,
        uio::{RemoteIoVec, process_vm_readv},
        wait::{WaitStatus, waitpid},
    },
    unistd::Pid,
};
use x86_64::registers::debug::{
    BreakpointCondition, BreakpointSize, DebugAddressRegisterNumber, Dr6Flags, Dr7Flags, Dr7Value,
};

use crate::syscall::{SyscallInfoDiscriminants, TraceError, parse_error::{TraceErrEvt, TraceEvent}};

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
        self.signal.take()
    }
}

#[expect(clippy::cast_precision_loss)]
static CLOCK_TIME: LazyLock<f64> =
    LazyLock::new(|| unsafe { libc::sysconf(libc::_SC_CLK_TCK) as f64 });

// TODO allow configuring this
const MAX_BYTES_CSTRING: usize = 2048 * 1024; // 2 MiB
const BUFFER_SIZE: usize = 128;

type ErrnoResult<T> = Result<T, Errno>;

pub struct Tracee {
    pid: Pid,
    signal: SignalStorage,
}

impl Tracee {
    #[must_use]
    pub fn new(pid: Pid) -> Tracee {
        // TODO apparently it's not possible to use mmap for /proc files, because their file size is
        // 0
        Tracee {
            pid,
            signal: SignalStorage::default(),
        }
    }

    // TODO add a wait_for_syscall_stop type of method here, apply this for SIGTRAP
    pub fn wait_for_stop(&mut self) -> Result<WaitEvents, TraceErrEvt> {
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
                    return self.wait_for_stop();
                }
                Ok(WaitEvents::Stopped(signal))
            }
            Ok(WaitStatus::Exited(_, exit_code)) => {
                debug!("Process exited");
                Err(TraceErrEvt::Event(TraceEvent::ProcessExit(exit_code)))
            }
            Ok(WaitStatus::Signaled(pid, signal, core_dumped)) => {
                warn!("tracee {pid:?} was signaled {signal:?} and dumped core: {core_dumped}");
                Err(TraceErrEvt::Event(TraceEvent::Terminated {
                    signal,
                    core_dumped,
                }))
            }
            Ok(status) => Err(TraceErrEvt::Error(TraceError::UnexpectedWaitStatus(status))),
            Err(err) => Err(TraceErrEvt::Error(TraceError::WaitPidError(err))),
        }
    }

    pub fn memcpy(&self, base: u64, len: usize) -> ErrnoResult<Vec<u8>> {
        let base = base.try_into().unwrap();
        let mut data = vec![0; len];
        if base == 0 {
            return Ok(vec![0]);
        }
        process_vm_readv(
            self.pid,
            &mut [IoSliceMut::new(&mut data)],
            &[RemoteIoVec { base, len }],
        )?;
        Ok(data)
    }

    #[must_use]
    pub fn get_cpu_time(&self) -> f64 {
        let stat_file = std::fs::read_to_string(format!("/proc/{}/stat", self.pid)).unwrap();
        stat_file
            .split_whitespace()
            .nth(13)
            .unwrap()
            .parse::<f64>()
            .unwrap()
            / *CLOCK_TIME
    }

    pub fn memcpy_struct<T>(&self, base: u64) -> ErrnoResult<Option<T>>
    where
        T: Clone + Copy,
    {
        if base == 0 {
            return Ok(None);
        }
        let bytes = self.memcpy(base, std::mem::size_of::<T>())?;
        let (_, sock_addr, _) = unsafe { bytes.align_to::<T>() };
        Ok(Some(sock_addr[0]))
    }

    pub fn memcpy_until<T>(&self, base: u64, function: T) -> ErrnoResult<Vec<u8>>
    where
        T: Fn(&u8) -> bool,
    {
        if base == 0 {
            return Ok(vec![0]);
        }
        let mut data = vec![];
        let mut buf = [0; BUFFER_SIZE];
        let mut total_bytes_read = 0usize;

        let base: usize = base.try_into().unwrap();

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
                data.extend_from_slice(&buf[..=index]);
                break;
            }
            data.extend_from_slice(&buf);
        }
        if data.len() >= MAX_BYTES_CSTRING - 1 {
            debug!("reached memcpy_until byte read limit");
        }
        Ok(data)
    }

    pub fn strcpy(&self, base: u64) -> ErrnoResult<Vec<u8>> {
        self.memcpy_until(base, |num| *num == 0)
    }

    pub fn read_rax(&self) -> Result<i64, TraceError> {
        Ok(ptrace::read_user(self.pid, (RAX * 8) as *mut c_void)?)
    }

    pub fn getregs(&self) -> ErrnoResult<user_regs_struct> {
        ptrace::getregs(self.pid)
    }

    pub fn read(&self, addr: usize) -> ErrnoResult<c_long> {
        ptrace::read(self.pid, addr as *mut c_void)
    }

    pub fn read_user(&self, addr: usize) -> ErrnoResult<c_long> {
        ptrace::read_user(self.pid, addr as *mut c_void)
    }

    pub fn write(&self, addr: usize, data: c_long) -> ErrnoResult<()> {
        ptrace::write(self.pid, addr as *mut c_void, data)
    }

    pub fn write_user(&self, addr: usize, data: c_long) -> ErrnoResult<()> {
        ptrace::write_user(self.pid, addr as *mut c_void, data)
    }

    pub fn setoptions(&self, options: ptrace::Options) -> ErrnoResult<()> {
        ptrace::setoptions(self.pid, options)
    }

    pub fn parse_return(
        &mut self,
        syscall: SyscallInfoDiscriminants,
    ) -> Result<i64, TraceErrEvt> {
        debug!("Parsing syscall return...");
        self.syscall()?;
        self.wait_for_stop()?;
        let syscall_info: PtraceSyscallInfo = self.syscall_info()?.into();
        let Some(PtraceSyscallInfoData::Exit {
            return_value,
            is_error,
        }) = syscall_info.data
        else {
            return Err(TraceErrEvt::Error(TraceError::InvalidSyscallInfo(syscall_info)));
        };
        if is_error {
            return Err(TraceErrEvt::Event(TraceEvent::SyscallError {
                syscall,
                error: parse_syscall_error(return_value),
                rip: syscall_info.instruction_pointer,
                cpu_time: self.get_cpu_time()
            }));
        }
        Ok(return_value)
    }

    pub fn syscall(&mut self) -> ErrnoResult<()> {
        ptrace::syscall(self.pid, self.signal.get())
    }

    pub fn cont(&mut self) -> ErrnoResult<()> {
        ptrace::cont(self.pid, self.signal.get())
    }

    fn translate_address(&self, mut func: impl FnMut((usize, usize), usize) -> Option<usize>) -> Result<Option<usize>, io::Error> {
        let file = File::open(format!("/proc/{pid}/task/{pid}/maps", pid = self.pid))?;
        let reader = BufReader::new(file);
        for line in reader.lines() {
            let line = line?;
            let mut it = line.split_whitespace();
            let virt_addresses = it.next().unwrap();

            let (start, stop) = virt_addresses.split_once('-').unwrap();
            let start = usize::from_str_radix(start, 16).unwrap();
            let stop = usize::from_str_radix(stop, 16).unwrap();

            // permissions
            it.next();
            let elf_offset = usize::from_str_radix(it.next().unwrap(), 16).unwrap();

            let func_res = func((start, stop), elf_offset);
            if func_res.is_some() {
                return Ok(func_res)
            }
        }
        Ok(None)

    }

    pub fn translate_address_to_virtual(&self, requested_addr: usize) -> Result<Option<usize>, io::Error> {
        self.translate_address(|(start, stop), elf_offset| {
            if requested_addr < elf_offset { return None; }

            let difference = stop - start;
            if requested_addr <= elf_offset + difference {
                return Some(start + requested_addr - elf_offset)
            }
            None
        })
    }

    pub fn translate_address_from_virtual(&self, requested_addr: usize) -> Result<Option<usize>, io::Error> {
        self.translate_address(|(start, stop), elf_offset| {
            let range = start..=stop;
            if range.contains(&requested_addr) {
                Some(requested_addr - start + elf_offset)
            } else {
                None
            }
        })
    }

    // this isn't gonna be compatible outside of x86, just like many other code around here
    pub fn add_local_breakpoint(&self, break_address: usize) -> ErrnoResult<()> {
        // break_address gets written to Dr0
        // let break_register = Dr0::write(break_address.try_into().unwrap());
        let bits = self.read_user(debugreg_offset(7))?;
        let mut dr7 = Dr7Value::from_bits(bits.cast_unsigned()).unwrap();
        dr7.set_flags(Dr7Flags::LOCAL_BREAKPOINT_0_ENABLE, true);
        dr7.set_condition(
            DebugAddressRegisterNumber::Dr0,
            BreakpointCondition::InstructionExecution,
        );
        dr7.set_size(DebugAddressRegisterNumber::Dr0, BreakpointSize::Length1B);

        self.write_user(debugreg_offset(0), break_address as i64)?;
        self.write_user(debugreg_offset(7), dr7.bits().cast_signed())?;
        Ok(())
    }

    pub fn check_and_remove_break(&self) -> ErrnoResult<()> {
        let dr6 = self.read_user(debugreg_offset(6))?;
        let dr6 = Dr6Flags::from_bits_truncate(dr6.cast_unsigned());
        if !dr6.contains(Dr6Flags::TRAP0) {
            error!("Breakpoint was not triggered when it was expected to trigger!");
        }

        // disable breakpoint
        let bits = self.read_user(debugreg_offset(7))?;
        let mut dr7 = Dr7Value::from_bits(bits.cast_unsigned()).unwrap();
        dr7.set_flags(Dr7Flags::LOCAL_BREAKPOINT_0_ENABLE, false);
        self.write_user(debugreg_offset(7), dr7.bits().cast_signed())?;
        Ok(())
    }

    pub fn syscall_info(&self) -> ErrnoResult<libc::ptrace_syscall_info> {
        ptrace::syscall_info(self.pid)
    }

    #[must_use]
    pub fn get_pid_string(&self) -> String {
        self.pid.to_string()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PtraceSyscallInfo {
    pub flags: u16,
    pub arch: u32,
    pub instruction_pointer: u64,
    pub stack_pointer: u64,
    pub data: Option<PtraceSyscallInfoData>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PtraceSyscallInfoData {
    Entry {
        syscall_number: u64,
        args: [u64; 6],
    },
    Exit {
        return_value: i64,
        is_error: bool,
    },
    Seccomp {
        syscall_number: u64,
        args: [u64; 6],
        ret_data: u32,
    },
}

impl From<libc::ptrace_syscall_info> for PtraceSyscallInfo {
    fn from(value: libc::ptrace_syscall_info) -> Self {
        let data = match value.op {
            libc::PTRACE_SYSCALL_INFO_ENTRY => {
                let data = unsafe { value.u.entry };
                Some(PtraceSyscallInfoData::Entry {
                    syscall_number: data.nr,
                    args: data.args,
                })
            }
            libc::PTRACE_SYSCALL_INFO_EXIT => {
                let data = unsafe { value.u.exit };
                Some(PtraceSyscallInfoData::Exit {
                    return_value: data.sval,
                    is_error: data.is_error != 0,
                })
            }
            libc::PTRACE_SYSCALL_INFO_SECCOMP => {
                let data = unsafe { value.u.seccomp };
                Some(PtraceSyscallInfoData::Seccomp {
                    syscall_number: data.nr,
                    args: data.args,
                    ret_data: data.ret_data,
                })
            }
            libc::PTRACE_SYSCALL_INFO_NONE => None,
            _ => panic!("{} is invalid value for ptrace_syscall_info.op", value.op),
        };
        PtraceSyscallInfo {
            flags: value.flags,
            arch: value.arch,
            instruction_pointer: value.instruction_pointer,
            stack_pointer: value.stack_pointer,
            data,
        }
    }
}

const fn debugreg_offset(reg_pos: usize) -> usize {
    assert!(
        reg_pos < 8,
        "There are only 8 debug registers counting from DR0 to DR7."
    );
    mem::offset_of!(libc::user, u_debugreg) + reg_pos * mem::size_of::<c_ulonglong>()
}

#[must_use]
pub fn parse_syscall_error(return_value: i64) -> Errno {
    Errno::from_raw(-return_value as i32)
}
