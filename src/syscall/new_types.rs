#![warn(clippy::unwrap_used)]
use std::fmt::Debug;

use libc::sockaddr;
use nix::{
    errno::Errno,
    fcntl::OFlag,
    sys::{
        signal::Signal, socket::{self, AddressFamily}, stat::Mode
    },
};
use rkyv::{
    Archive, Archived, Deserialize, Resolver, Serialize,
    rancor::{self, Fallible},
    rend,
    with::{ArchiveWith, DeserializeWith, SerializeWith},
};

#[derive(thiserror::Error, Debug)]
pub enum SyscallNewTypeError {
    #[error("could not parse number {0} to requested enum")]
    CouldNotParseEnum(i32),
    #[error("invalid flags value: {0:#X}")]
    InvalidFlagI32(i32),
    #[error("invalid flags value: {0:#X}")]
    InvalidFlagU32(u32),
    #[error("invalid conversion: {0:?}")]
    InvalidConversion(#[from] nix::Error),
    #[error(transparent)]
    AnythingElse(#[from] anyhow::Error),
}

impl rancor::Trace for SyscallNewTypeError {
    fn trace<R>(self, trace: R) -> Self
    where
        R: core::fmt::Debug + core::fmt::Display + Send + Sync + 'static,
    {
        unimplemented!("help me here: {trace:?}")
    }
}
impl rancor::Source for SyscallNewTypeError {
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

impl<D: Fallible<Error = SyscallNewTypeError>> Deserialize<SocketType, D> for rend::i32_le {
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
pub(super) struct NewTypeSer;

// Mode
impl ArchiveWith<Mode> for NewTypeSer {
    type Archived = Archived<u32>;

    type Resolver = Resolver<u32>;

    fn resolve_with(field: &Mode, resolver: Self::Resolver, out: rkyv::Place<Self::Archived>) {
        field.bits().resolve(resolver, out);
    }
}

impl<S: Fallible> SerializeWith<Mode, S> for NewTypeSer {
    fn serialize_with(
        field: &Mode,
        serializer: &mut S,
    ) -> Result<Self::Resolver, <S as Fallible>::Error> {
        field.bits().serialize(serializer)
    }
}

impl<D: Fallible<Error = SyscallNewTypeError>> DeserializeWith<Archived<u32>, Mode, D> for NewTypeSer {
    fn deserialize_with(field: &Archived<u32>, _: &mut D) -> Result<Mode, <D as Fallible>::Error> {
        let num = field.to_native();
        Mode::from_bits(num).ok_or(SyscallNewTypeError::InvalidFlagU32(num))
    }
}

// AddressFamily
impl ArchiveWith<AddressFamily> for NewTypeSer {
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

impl<S: Fallible> SerializeWith<AddressFamily, S> for NewTypeSer {
    fn serialize_with(
        field: &AddressFamily,
        serializer: &mut S,
    ) -> Result<Self::Resolver, <S as Fallible>::Error> {
        (*field as i32).serialize(serializer)
    }
}

impl<D: Fallible<Error = SyscallNewTypeError>> DeserializeWith<Archived<i32>, AddressFamily, D>
    for NewTypeSer
{
    fn deserialize_with(field: &Archived<i32>, _: &mut D) -> Result<AddressFamily, D::Error> {
        let num = field.to_native();
        AddressFamily::from_i32(num).ok_or(SyscallNewTypeError::CouldNotParseEnum(num))
    }
}

// OFlag
impl ArchiveWith<OFlag> for NewTypeSer {
    type Archived = Archived<i32>;

    type Resolver = Resolver<i32>;

    fn resolve_with(field: &OFlag, (): (), out: rkyv::Place<Self::Archived>) {
        field.bits().resolve((), out);
    }
}

impl<S: Fallible + Sized> SerializeWith<OFlag, S> for NewTypeSer {
    fn serialize_with(field: &OFlag, serializer: &mut S) -> Result<Self::Resolver, S::Error> {
        field.bits().serialize(serializer)
    }
}

impl<D: Fallible<Error = SyscallNewTypeError>> DeserializeWith<Archived<i32>, OFlag, D> for NewTypeSer {
    fn deserialize_with(field: &Archived<i32>, _: &mut D) -> Result<OFlag, <D as Fallible>::Error> {
        let num = field.to_native();
        OFlag::from_bits(field.to_native()).ok_or(SyscallNewTypeError::InvalidFlagI32(num))
    }
}

// Errno
impl ArchiveWith<Errno> for NewTypeSer {
    type Archived = Archived<i32>;

    type Resolver = Resolver<i32>;

    fn resolve_with(field: &Errno, (): (), out: rkyv::Place<Self::Archived>) {
        (*field as i32).resolve((), out);
    }
}

impl<S: Fallible<Error = SyscallNewTypeError>> SerializeWith<Errno, S> for NewTypeSer {
    fn serialize_with(
        field: &Errno,
        serializer: &mut S,
    ) -> Result<Self::Resolver, <S as Fallible>::Error> {
        (*field as i32).serialize(serializer)
    }
}

impl<D: Fallible<Error = SyscallNewTypeError>> DeserializeWith<Archived<i32>, Errno, D> for NewTypeSer {
    fn deserialize_with(field: &Archived<i32>, _: &mut D) -> Result<Errno, <D as Fallible>::Error> {
        Ok(Errno::from_raw(field.to_native()))
    }
}

// Signal
impl ArchiveWith<Signal> for NewTypeSer {
    type Archived = Archived<i32>;

    type Resolver = Resolver<i32>;

    fn resolve_with(field: &Signal, (): (), out: rkyv::Place<Self::Archived>) {
        (*field as i32).resolve((), out);
    }
}

impl<S: Fallible<Error = SyscallNewTypeError>> SerializeWith<Signal, S> for NewTypeSer {
    fn serialize_with(
        field: &Signal,
        serializer: &mut S,
    ) -> Result<Self::Resolver, <S as Fallible>::Error> {
        (*field as i32).serialize(serializer)
    }
}

impl<D: Fallible<Error = SyscallNewTypeError>> DeserializeWith<Archived<i32>, Signal, D> for NewTypeSer {
    fn deserialize_with(field: &Archived<i32>, _: &mut D) -> Result<Signal, <D as Fallible>::Error> {
        let num = field.to_native();
        Signal::try_from(num).or(Err(SyscallNewTypeError::InvalidFlagI32(num)))
    }
}

// pub struct ErrnoSer;
//
// impl ArchieWith<Errno> for ErrnoSer {}
