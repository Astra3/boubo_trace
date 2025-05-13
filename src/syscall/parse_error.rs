use nix::{
    errno::Errno,
    sys::{signal::Signal, wait::WaitStatus},
};
use serde::Serialize;
use thiserror::Error;

use super::SyscallDisc;

#[derive(Error, Debug)]
pub enum SyscallParseError {
    #[error("error '{error:?}' on syscall {syscall}")]
    SyscallError { syscall: SyscallDisc, error: Errno },
    #[error("error in syscall by tracer: {0:?}")]
    PtraceError(#[from] Errno),
    #[error("tracee process is not running and exited with status code {0}")]
    ProcessExit(i32),
    #[error("unexpected status returned by waitpid: {0:?}")]
    UnexpectedWaitStatus(WaitStatus),
    #[error("error returned by waitpid with errno: {0:?}")]
    WaitPidError(Errno),
    // FIXME this isn't really a parse error
    #[error("tracee terminated by OS with signal {signal:?}")]
    Terminated { signal: Signal, core_dumped: bool },
}

impl Serialize for SyscallParseError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.to_string())
    }
}
