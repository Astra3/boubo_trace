use nix::sys::socket;

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub struct SocketType {
    r#type: socket::SockType,
    flags: socket::SockFlag,
}

impl From<i32> for SocketType {
    fn from(value: i32) -> Self {
        let flags = socket::SockFlag::from_bits_truncate(value);
        let sock_type = socket::SockType::try_from(value & !socket::SockFlag::all().bits()).unwrap();

        SocketType { r#type: sock_type, flags }


    }
}
