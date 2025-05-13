#[cfg(test)]
mod tests {
    use std::{process::Command, sync::Once};

    use boubo_trace::{
        syscall::{Syscall, SyscallIter, SyscallIterOpts, SyscallParseError},
        tracee::Tracee,
    };
    use insta::glob;
    use nix::unistd::Pid;
    use spawn_ptrace::CommandPtraceSpawn;
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
            let mut cmd = Command::new(exec)
                .current_dir(exec.parent().unwrap())
                .spawn_ptrace()
                .unwrap();
            let pid = Pid::from_raw(cmd.id() as i32);

            let it = SyscallIter::new(Tracee::new(pid), SyscallIterOpts::default());
            let called_syscalls: Vec<_> = it
                .unwrap()
                .filter(|call| !matches!(call, Ok(Syscall::Unknown { .. })))
                .take_while(|call| !matches!(call, Err(SyscallParseError::ProcessExit(_))))
                .collect();
            insta::assert_debug_snapshot!(called_syscalls);
            cmd.wait().unwrap();
        });
    }
}
