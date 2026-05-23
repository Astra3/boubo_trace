use std::{fs::File, io::Read, path::PathBuf};

use anyhow::bail;
use boubo_trace::syscall::{SyscallInfo, SyscallNewTypeError};
use clap::Parser;

#[derive(Parser)]
struct Args {
    input_file: PathBuf,
}


fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    if !args.input_file.is_file() {
        bail!("file {} does not exist", args.input_file.display())
    }
    let mut file = File::open(args.input_file)?;
    let mut buf = vec![];
    file.read_to_end(&mut buf)?;
    let syscalls = rkyv::from_bytes::<Vec<SyscallInfo>, SyscallNewTypeError>(&buf)?;
    println!("parsed data: {syscalls:?}");
    Ok(())
}
