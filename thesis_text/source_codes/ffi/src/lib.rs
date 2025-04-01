use libc::{c_int, size_t};

#[link(name = "snappy")]
unsafe extern {
    fn snappy_validate_compressed_buffer(compressed: *const u8, compressed_length: size_t) -> c_int;
}

// &[u8] je reference na pole v Rustu, které obsahuje ukazatel na data a délku
pub fn validate_compressed_buffer(src: &[u8]) -> bool {
    unsafe {
        snappy_validate_compressed_buffer(src.as_ptr(), src.len() as size_t) == 0
    }
}
