use libc::sockaddr;
use nix::{
    fcntl::OFlag,
    sys::{
        socket::{self, AddressFamily},
        stat::Mode,
    },
};
use serde::{Serialize, ser::SerializeStruct};

#[derive(Debug, Clone)]
#[allow(non_camel_case_types)]
pub struct sockaddr_ser(sockaddr);

impl Serialize for sockaddr_ser {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let mut sock_addr = serializer.serialize_struct("sockaddr", 2)?;
        sock_addr.serialize_field("sa_family", &self.0.sa_family)?;
        sock_addr.serialize_field("sa_data", &self.0.sa_data)?;
        sock_addr.end()
    }
}

impl From<sockaddr> for sockaddr_ser {
    fn from(val: sockaddr) -> Self {
        sockaddr_ser(val)
    }
}

#[derive(Debug, Clone)]
pub struct SocketType {
    r#type: socket::SockType,
    flags: socket::SockFlag,
}

impl Serialize for SocketType {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let mut sock_type = serializer.serialize_struct("socket_type", 2)?;
        sock_type.serialize_field("type", &(self.r#type as i32))?;
        sock_type.serialize_field("flags", &self.flags.bits())?;
        sock_type.end()
    }
}

impl From<i32> for SocketType {
    fn from(val: i32) -> Self {
        let flags = socket::SockFlag::from_bits_truncate(val);
        let sock_type = socket::SockType::try_from(val & !socket::SockFlag::all().bits()).unwrap();

        SocketType {
            r#type: sock_type,
            flags,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AddressFamilySer(AddressFamily);

impl Serialize for AddressFamilySer {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_i32(self.0 as i32)
    }
}

impl From<AddressFamily> for AddressFamilySer {
    fn from(val: AddressFamily) -> Self {
        AddressFamilySer(val)
    }
}

#[derive(Debug, Clone)]
pub struct OFlagSer(OFlag);

impl Serialize for OFlagSer {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_i32(self.0.bits())
    }
}

impl From<OFlag> for OFlagSer {
    fn from(val: OFlag) -> Self {
        OFlagSer(val)
    }
}

#[derive(Debug, Clone)]
pub struct ModeSer(Mode);

impl Serialize for ModeSer {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_u32(self.0.bits())
    }
}

impl From<Mode> for ModeSer {
    fn from(val: Mode) -> Self {
        ModeSer(val)
    }
}
