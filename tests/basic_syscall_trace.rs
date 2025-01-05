#[cfg(test)]
mod tests {
    use std::{path::PathBuf, process::Command, sync::Once};

    use insta::glob;
    use nix::{
        sys::ptrace::{self, Options},
        unistd::Pid,
    };
    use spawn_ptrace::CommandPtraceSpawn;
    use tracer::syscall::{Syscall, SyscallIter, SyscallIterOpts, SyscallParseError};
    static INIT: Once = Once::new();

    fn initialize() {
        INIT.call_once(|| {
            println!("running init");
            let mut cmd = Command::new("make")
                .current_dir("test_programs/")
                .spawn()
                .unwrap();
            cmd.wait().unwrap();
        });
    }

    #[test]
    fn simple_test() {
        initialize();
        glob!("../test_programs/build/", "*.exec", |exec| {
            println!("path: {}", exec.display());
            let cmd = Command::new(exec)
                .current_dir(exec.parent().unwrap())
                .spawn_ptrace()
                .unwrap();
            let pid = Pid::from_raw(cmd.id() as i32);

            let it = SyscallIter::new(pid, SyscallIterOpts::default());
            // FIXME improve error serialize, if necessary
            let called_syscalls: Vec<_> = it
                .unwrap()
                .filter(|call| !matches!(call, Ok(Syscall::Unknown { .. })))
                .take_while(|call| !matches!(call, Err(SyscallParseError::ProcessExit(_))))
                .collect();
            insta::assert_debug_snapshot!(called_syscalls);
        });
    }
}
