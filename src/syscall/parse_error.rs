use nix::{
    errno::Errno,
    sys::{signal::Signal, wait::WaitStatus},
};
use rkyv::{
    Archive, Serialize, rancor::{self, Fallible}, ser, string::{ArchivedString, StringResolver}
};
use thiserror::Error;

use crate::tracee::PtraceSyscallInfo;

use super::SyscallDisc;

#[derive(Error, Debug)]
pub enum SyscallParseError {
    // FIXME this is not really an error
    #[error("error '{error:?}' on syscall {syscall}")]
    SyscallError { syscall: SyscallDisc, error: Errno },
    #[error("error in syscall by tracer: {0:?}")]
    PtraceError(#[from] Errno),
    // FIXME this isn't really a parse error
    #[error("tracee process is not running and exited with status code {0}")]
    ProcessExit(i32),
    #[error("unexpected status returned by waitpid: {0:?}")]
    UnexpectedWaitStatus(WaitStatus),
    #[error("error returned by waitpid with errno: {0:?}")]
    WaitPidError(Errno),
    // FIXME this isn't really a parse error
    #[error("tracee terminated by OS with signal {signal:?}")]
    Terminated { signal: Signal, core_dumped: bool },
    #[error("syscall info struct did not contain the required entry, it contained {0:?}")]
    InvalidSyscallInfo(PtraceSyscallInfo),
}

impl Archive for SyscallParseError {
    type Archived = ArchivedString;

    type Resolver = StringResolver;

    fn resolve(&self, resolver: Self::Resolver, out: rkyv::Place<Self::Archived>) {
        self.to_string().resolve(resolver, out);
    }
}

impl<S> Serialize<S> for SyscallParseError
where
    S: Fallible + ser::Writer,
    <S as Fallible>::Error: rancor::Source,
{
    fn serialize(&self, serializer: &mut S) -> Result<Self::Resolver, S::Error> {
        self.to_string().serialize(serializer)
    }
}

