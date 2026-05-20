#![warn(clippy::unwrap_used)]
use std::fmt::Debug;

use libc::sockaddr;
use nix::{
    fcntl::OFlag,
    sys::{
        socket::{self, AddressFamily},
        stat::Mode,
    },
};
use rkyv::{
    Archive, Archived, Deserialize, Resolver, Serialize,
    rancor::{self, Fallible},
    rend,
    with::{ArchiveWith, DeserializeWith, SerializeWith},
};

#[derive(thiserror::Error, Debug)]
pub enum NewTypeError {
    #[error("could not parse number {0} to requested enum")]
    CouldNotParseEnum(i32),
    #[error("invalid flags value: {0:#X}")]
    InvalidFlagI32(i32),
    #[error("invalid flags value: {0:#X}")]
    InvalidFlagU32(u32),
    #[error("invalid conversion: {0:?}")]
    InvalidConversion(#[from] nix::Error),
    #[error(transparent)]
    AnythingElse(#[from] anyhow::Error)
}

impl rancor::Trace for NewTypeError {
    fn trace<R>(self, trace: R) -> Self
    where
        R: core::fmt::Debug + core::fmt::Display + Send + Sync + 'static {
        unimplemented!("help me here: {trace:?}")
    }
}
impl rancor::Source for NewTypeError {
    fn new<T: core::error::Error + Send + Sync + 'static>(source: T) -> Self {
        Self::AnythingElse(source.into())
    }
}

#[derive(Debug, Clone, rkyv::Archive, rkyv::Serialize, rkyv::Deserialize)]
#[rkyv(remote = libc::sockaddr)]
#[rkyv(archived = Archivedsockaddr, derive(Debug))]
#[expect(non_camel_case_types)]
pub struct sockaddr_ser {
    pub sa_family: u16,
    pub sa_data: [i8; 14],
}

impl From<sockaddr> for sockaddr_ser {
    fn from(value: sockaddr) -> Self {
        sockaddr_ser {
            sa_family: value.sa_family,
            sa_data: value.sa_data,
        }
    }
}

impl From<sockaddr_ser> for sockaddr {
    fn from(value: sockaddr_ser) -> Self {
        sockaddr {
            sa_family: value.sa_family,
            sa_data: value.sa_data,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SocketType {
    pub r#type: socket::SockType,
    pub flags: socket::SockFlag,
}

impl Archive for SocketType {
    type Archived = Archived<i32>;

    type Resolver = Resolver<i32>;

    fn resolve(&self, (): (), out: rkyv::Place<Self::Archived>) {
        // log::info!("help: {:?}", resolver.type_id());
        let num: i32 = self.into();
        num.resolve((), out);
    }
}

impl<S: Fallible> Serialize<S> for SocketType {
    fn serialize(&self, serializer: &mut S) -> Result<Self::Resolver, S::Error> {
        let num: i32 = self.into();
        num.serialize(serializer)
    }
}

impl<D: Fallible<Error = NewTypeError>> Deserialize<SocketType, D> for rend::i32_le {
    fn deserialize(&self, deserializer: &mut D) -> Result<SocketType, <D as Fallible>::Error> {
        let num: i32 = self.deserialize(deserializer)?;
        Ok(SocketType::try_from(num)?)
    }
}

impl TryFrom<i32> for SocketType {
    type Error = nix::Error;

    fn try_from(val: i32) -> Result<Self, Self::Error> {
        let flags = socket::SockFlag::from_bits_truncate(val);
        let sock_type = socket::SockType::try_from(val & !socket::SockFlag::all().bits())?;

        Ok(SocketType {
                    r#type: sock_type,
                    flags,
                })
    }
}

impl From<&SocketType> for i32 {
    fn from(value: &SocketType) -> Self {
        let flags = value.flags.bits();
        let r#type: i32 = value.r#type as i32;
        flags | r#type
    }
}

#[derive(Debug, Clone)]
pub struct AddressFamilySer;

impl ArchiveWith<AddressFamily> for AddressFamilySer {
    type Archived = Archived<i32>;

    type Resolver = Resolver<i32>;

    fn resolve_with(
        field: &AddressFamily,
        resolver: Self::Resolver,
        out: rkyv::Place<Self::Archived>,
    ) {
        (*field as i32).resolve(resolver, out);
    }
}

impl<S: Fallible> SerializeWith<AddressFamily, S> for AddressFamilySer {
    fn serialize_with(
        field: &AddressFamily,
        serializer: &mut S,
    ) -> Result<Self::Resolver, <S as Fallible>::Error> {
        (*field as i32).serialize(serializer)
    }
}

impl<D: Fallible<Error = NewTypeError>> DeserializeWith<Archived<i32>, AddressFamily, D>
    for AddressFamilySer
{
    fn deserialize_with(field: &Archived<i32>, _: &mut D) -> Result<AddressFamily, D::Error> {
        let num = field.to_native();
        AddressFamily::from_i32(num).ok_or(NewTypeError::CouldNotParseEnum(num))
    }
}

#[derive(Debug, Clone)]
pub struct OFlagSer;

impl ArchiveWith<OFlag> for OFlagSer {
    type Archived = Archived<i32>;

    type Resolver = Resolver<i32>;

    fn resolve_with(field: &OFlag, (): (), out: rkyv::Place<Self::Archived>) {
        field.bits().resolve((), out);
    }
}

impl<S: Fallible + Sized> SerializeWith<OFlag, S> for OFlagSer {
    fn serialize_with(field: &OFlag, serializer: &mut S) -> Result<Self::Resolver, S::Error> {
        field.bits().serialize(serializer)
    }
}

impl<D: Fallible<Error = NewTypeError>> DeserializeWith<Archived<i32>, OFlag, D> for OFlagSer {
    fn deserialize_with(field: &Archived<i32>, _: &mut D) -> Result<OFlag, <D as Fallible>::Error> {
        let num = field.to_native();
        OFlag::from_bits(field.to_native()).ok_or(NewTypeError::InvalidFlagI32(num))
    }
}

#[derive(Debug, Clone)]
pub struct ModeSer;

impl ArchiveWith<Mode> for ModeSer {
    type Archived = Archived<u32>;

    type Resolver = Resolver<u32>;

    fn resolve_with(field: &Mode, resolver: Self::Resolver, out: rkyv::Place<Self::Archived>) {
        field.bits().resolve(resolver, out);
    }
}

impl<S: Fallible> SerializeWith<Mode, S> for ModeSer {
    fn serialize_with(
        field: &Mode,
        serializer: &mut S,
    ) -> Result<Self::Resolver, <S as Fallible>::Error> {
        field.bits().serialize(serializer)
    }
}

impl<D: Fallible<Error = NewTypeError>> DeserializeWith<Archived<u32>, Mode, D> for ModeSer {
    fn deserialize_with(field: &Archived<u32>, _: &mut D)
        -> Result<Mode, <D as Fallible>::Error> {
        let num = field.to_native();
        Mode::from_bits(num).ok_or(NewTypeError::InvalidFlagU32(num))
    }
}
