use std::{fmt::Display, fs::File, io::Read, os::unix::fs::MetadataExt, path::PathBuf};

use ahash::AHashMap;
use anyhow::bail;
use boubo_trace::syscall::{SyscallInfo, SyscallNewTypeError, TraceData, parse_error::TraceEvent};
use clap::Parser;

#[derive(Parser)]
struct Args {
    input_file: PathBuf,
}

#[derive(Debug)]
struct FileData {
    pathname: String,
    total_read_bytes: usize,
    total_requested_read_bytes: usize,
    total_written_bytes: usize,
    total_requested_written_bytes: usize,
}

struct CpuTimeFormat(f64);

impl Display for CpuTimeFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:>10.2}:", self.0)
    }
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    if !args.input_file.is_file() {
        bail!("file {} does not exist", args.input_file.display())
    }
    let metadata = std::fs::metadata(&args.input_file)?;
    if metadata.size() > 1024 * 1024 * 1024 {
        eprintln!("File is larger than 1 GiB! This could take a lot of RAM to parse.");
    }
    let mut file = File::open(&args.input_file)?;
    let mut buf = vec![];
    file.read_to_end(&mut buf)?;
    let syscalls = rkyv::from_bytes::<Vec<TraceData>, SyscallNewTypeError>(&buf)?;

    let mut file_map = AHashMap::new();
    let mut files = Vec::new();

    for call in syscalls {
        match call {
            TraceData::Event(trace_event) => {
                if let TraceEvent::SyscallError {
                    syscall,
                    error,
                    rip: _,
                    cpu_time,
                } = trace_event
                {
                    let cpu_time = CpuTimeFormat(cpu_time);
                    println!("{cpu_time} Syscall {syscall} failed with {error}");
                }
            }
            TraceData::Syscall(syscall) => {
                let cpu_time = CpuTimeFormat(syscall.cpu_time);
                match syscall.syscall {
                    SyscallInfo::Openat {
                        dirfd: _,
                        mut pathname,
                        flags,
                        mode,
                        opened_fd,
                    } => {
                        pathname.pop();
                        let pathname = get_utf8(pathname);
                        println!("{cpu_time} Opened file '{pathname}' with {flags:?} and {mode:?}");
                        file_map.insert(
                            opened_fd,
                            FileData {
                                pathname,
                                total_read_bytes: 0,
                                total_requested_read_bytes: 0,
                                total_written_bytes: 0,
                                total_requested_written_bytes: 0,
                            },
                        );
                    }
                    SyscallInfo::Write {
                        fd,
                        to_write,
                        written_count,
                    } => {
                        if let Some(file_data) = file_map.get_mut(&fd) {
                            file_data.total_written_bytes += written_count;
                            file_data.total_requested_written_bytes += to_write.len();
                            println!(
                                "{cpu_time} Wrote {} bytes into file {} ({written_count} bytes requested)",
                                to_write.len(),
                                file_data.pathname
                            );
                        }
                    }
                    SyscallInfo::Read {
                        fd,
                        read_bytes,
                        requested_count,
                    } => {
                        if let Some(file_data) = file_map.get_mut(&fd) {
                            file_data.total_read_bytes += read_bytes.len();
                            file_data.total_requested_read_bytes += requested_count;
                            println!(
                                "{cpu_time} Read {} bytes from file {} ({requested_count} bytes requested)",
                                read_bytes.len(),
                                file_data.pathname
                            );
                        }
                    }
                    SyscallInfo::Close { fd } => {
                        if let Some(file_data) = file_map.remove(&fd) {
                            files.push(file_data);
                        }
                    }
                    _ => (),
                }
            }
        }
    }

    files.extend(file_map.into_iter().map(|(_, value)| value));

    println!("The process has opened:");
    for value in files {
        println!("{}", value.pathname);
        if value.total_requested_read_bytes > 0 || value.total_read_bytes > 0 {
            println!(
                "  Read {} bytes (requested to read {} bytes)",
                value.total_read_bytes, value.total_requested_read_bytes
            );
        }
        if value.total_requested_written_bytes > 0 || value.total_written_bytes > 0 {
            println!(
                "  Written {} bytes (requested to write {} bytes)",
                value.total_written_bytes, value.total_requested_written_bytes
            );
        }
    }
    // println!("parsed data: {syscalls:?}");
    Ok(())
}

fn get_utf8(bytes: Vec<u8>) -> String {
    String::from_utf8(bytes).unwrap_or("INVALID STRING".to_owned())
}
