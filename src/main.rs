use std::{fs::File, io::{BufRead, BufReader}, process::Command};

use elf::{endian::AnyEndian, file::FileHeader, section::SectionHeader, ElfBytes};
use libc::c_void;
use log::{debug, info, trace};
use nix::{
    sys::{ptrace::{self, Options}, wait::{waitpid, WaitStatus}},
    unistd::Pid,
};
use spawn_ptrace::CommandPtraceSpawn;
use tracer::syscall::{SyscallIter, SyscallParseError};

const EXECUTABLE: &str = "/home/roman/Documents/Škola/bakalářka/tracer/test_programs/build/open.exec";

fn main() -> Result<(), anyhow::Error> {
    env_logger::init();
    let entry_point = test_elf();
    trace!("entry: {entry_point:#x}");
    call_cmd(entry_point)?;

    Ok(())
}

fn test_elf() -> u64 {
    let file = std::fs::read(EXECUTABLE).unwrap();
    let elf = ElfBytes::<AnyEndian>::minimal_parse(file.as_slice()).unwrap();
    elf.ehdr.e_entry
}

// TODO optimize this
fn read_memory_map(pid: Pid, requested_addr: usize) -> Result<Option<usize>, anyhow::Error> {
    let pid_text = pid.to_string();
    let file = File::open("/proc/".to_string() + &pid_text + "/task/" + &pid_text + "/maps")?;
    let reader = BufReader::new(file);
    for line in reader.lines() {
        let line = line?;
        let mut it = line.split_whitespace();
        let section = it.next().unwrap();
        let mut numbers = section.split("-");

        let start = usize::from_str_radix(numbers.next().unwrap(), 16)?;
        let stop = usize::from_str_radix(numbers.next().unwrap(), 16)?;

        // permissions
        it.next();
        let offset = usize::from_str_radix(it.next().unwrap(), 16)?;
        if requested_addr < offset { continue; }
        
        let difference = stop - start;
        if requested_addr <= offset + difference {
            return Ok(Some(start + requested_addr - offset));
        }
        continue;
    }

    Ok(None)
}

fn call_cmd(entry_point: u64) -> Result<(), anyhow::Error> {
    let cmd = Command::new(EXECUTABLE)
        .current_dir("test_programs/build")
        .spawn_ptrace()?;

    let mut called_syscalls = vec![];
    let pid = Pid::from_raw(cmd.id() as i32);
    trace!("traced pid: {pid}");

    debug!("creating breakpoint on main");
    let entry = read_memory_map(pid, entry_point as usize)?.unwrap();
    ptrace::setoptions(pid, Options::PTRACE_O_EXITKILL)?;
    let original_byte = ptrace::read(pid, entry as *mut c_void)?;
    trace!("original byte: {original_byte:#X}");
    ptrace::write(pid, entry as *mut c_void, 0xCC)?;

    ptrace::cont(pid, None)?;
    match waitpid(pid, None) {
        Ok(WaitStatus::Stopped(_, _)) => {
            trace!("stopped on main");
            ptrace::write(pid, entry as *mut c_void, original_byte)?;
        }
        _ => panic!(),
    }

    for call in SyscallIter(pid) {
        info!("Parsed syscall: {call:?}");
        // if let Err(SyscallParseError::ProcessExit(_)) = call {
        //     break;
        // }
        called_syscalls.push(call);
    }
    // let v: Vec<Syscall> = called_syscalls.into_iter().flatten().collect();
    // info!("serialized: {}", serde_json::to_string_pretty(&v).unwrap());
    Ok(())
}
