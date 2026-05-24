use nix::{
    errno::Errno,
    sys::{signal::Signal, wait::WaitStatus},
};
use thiserror::Error;

use crate::{syscall::NewTypeSer, tracee::PtraceSyscallInfo};

use super::SyscallDisc;

#[derive(Error, Debug, PartialEq, Eq, Clone, Copy)]
pub enum TraceError {
    #[error("error in syscall by tracer: {0:?}")]
    PtraceError(#[from] Errno),
    #[error("unexpected status returned by waitpid: {0:?}")]
    UnexpectedWaitStatus(WaitStatus),
    #[error("error returned by waitpid with errno: {0:?}")]
    WaitPidError(Errno),
    #[error("syscall info struct did not contain the required entry, it contained {0:?}")]
    InvalidSyscallInfo(PtraceSyscallInfo),
}

#[derive(
    Error, Debug, PartialEq, Clone, Copy, rkyv::Archive, rkyv::Serialize, rkyv::Deserialize,
)]
pub enum TraceEvent {
    #[error("tracee terminated by OS with signal {signal:?}")]
    Terminated {
        #[rkyv(with = NewTypeSer)]
        signal: Signal,
        core_dumped: bool,
    },
    #[error("tracee process is not running and exited with status code {0}")]
    ProcessExit(i32),
    #[error("syscall {syscall} returned the following error: '{error:?}'")]
    SyscallError {
        syscall: SyscallDisc,
        #[rkyv(with = NewTypeSer)]
        error: Errno,
        cpu_time: f64,
        rip: u64,
    },
}

#[derive(Error, Debug, PartialEq)]
pub enum TraceErrEvt {
    #[error(transparent)]
    Error(#[from] TraceError),
    #[error(transparent)]
    Event(#[from] TraceEvent),
}

impl From<Errno> for TraceErrEvt {
    fn from(value: Errno) -> Self {
        TraceErrEvt::Error(TraceError::PtraceError(value))
    }
}

