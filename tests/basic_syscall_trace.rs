#[cfg(test)]
mod tests {
    use std::{process::Command, sync::Once};

    use boubo_trace::{
        syscall::{SyscallIter, SyscallIterOpts},
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
            let pid = Pid::from_raw(cmd.id().cast_signed());

            let it = SyscallIter::new(Tracee::new(pid), &SyscallIterOpts::default());
            let called_syscalls = it.unwrap().collect::<Result<Vec<_>, _>>().unwrap();
            insta::assert_debug_snapshot!(called_syscalls);
            cmd.wait().unwrap();
        });
    }
}
