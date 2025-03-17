use libc::user_regs_struct;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyscallArgs(
    pub(super) usize,
    pub(super) usize,
    pub(super) usize,
    pub(super) usize,
    pub(super) usize,
    pub(super) usize,
);

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
