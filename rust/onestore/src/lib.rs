//! Spec-based, read-only modern .one header preflight. No page extraction yet.
//! Sources: docs/ONENOTE-IMPORT.md; MS-ONESTORE sections 2.3.1 and 3.1.
const HEADER_SIZE: usize = 1024;
const ONE: [u8; 16] = [
    0xe4, 0x52, 0x5c, 0x7b, 0x8c, 0xd8, 0xa7, 0x4d, 0xae, 0xb1, 0x53, 0x78, 0xd0, 0x29, 0x96, 0xd3,
];
const FORMAT: [u8; 16] = [
    0x3f, 0xdd, 0x9a, 0x10, 0x1b, 0x91, 0xf5, 0x49, 0xa5, 0xd0, 0x17, 0x91, 0xed, 0xc8, 0xae, 0xd8,
];

#[derive(Debug, PartialEq, Eq)]
#[repr(i32)]
pub enum ProbeError {
    Truncated = 1,
    WrongType = 2,
    Unsupported = 3,
    Bounds = 4,
}
#[derive(Debug, PartialEq, Eq)]
pub struct SectionHeader {
    pub root_offset: u64,
    pub root_length: u32,
    pub file_length: u64,
}
fn u32_at(b: &[u8], o: usize) -> u32 {
    u32::from_le_bytes(b[o..o + 4].try_into().unwrap())
}
fn u64_at(b: &[u8], o: usize) -> u64 {
    u64::from_le_bytes(b[o..o + 8].try_into().unwrap())
}
fn bounded_chunk(b: &[u8], offset: usize, file_length: u64) -> Result<(u64, u32), ProbeError> {
    let start = u64_at(b, offset);
    let length = u32_at(b, offset + 8);
    if start < HEADER_SIZE as u64
        || length == 0
        || start
            .checked_add(u64::from(length))
            .filter(|end| *end <= file_length)
            .is_none()
    {
        return Err(ProbeError::Bounds);
    }
    Ok((start, length))
}

pub fn probe_header(header: &[u8], actual_length: u64) -> Result<SectionHeader, ProbeError> {
    if header.len() < HEADER_SIZE || actual_length < HEADER_SIZE as u64 {
        return Err(ProbeError::Truncated);
    }
    if header[..16] != ONE {
        return Err(ProbeError::WrongType);
    }
    if header[48..64] != FORMAT || [64, 68, 72, 76].iter().any(|&o| u32_at(header, o) != 42) {
        return Err(ProbeError::Unsupported);
    }
    let file_length = u64_at(header, 0xc4);
    if file_length != actual_length || u32_at(header, 0x60) == 0 {
        return Err(ProbeError::Bounds);
    }
    // Required references must not be nil/zero and must fall inside the file.
    bounded_chunk(header, 0xa0, file_length)?;
    let (root_offset, root_length) = bounded_chunk(header, 0xac, file_length)?;
    Ok(SectionHeader {
        root_offset,
        root_length,
        file_length,
    })
}

/// C ABI with no allocation, callbacks, or filesystem access.
/// # Safety
/// bytes must be non-null and point to at least length readable bytes when
/// length >= 1024. Only the first 1024 bytes are inspected.
#[no_mangle]
pub unsafe extern "C" fn onestore_probe(
    bytes: *const u8,
    length: usize,
    actual_length: u64,
) -> i32 {
    if bytes.is_null() {
        return 5;
    }
    if length < HEADER_SIZE {
        return ProbeError::Truncated as i32;
    }
    let header = unsafe { std::slice::from_raw_parts(bytes, HEADER_SIZE) };
    match probe_header(header, actual_length) {
        Ok(_) => 0,
        Err(e) => e as i32,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture() -> Vec<u8> {
        let mut b = vec![0u8; 1024];
        b[..16].copy_from_slice(&ONE);
        b[48..64].copy_from_slice(&FORMAT);
        for o in [64, 68, 72, 76] {
            b[o..o + 4].copy_from_slice(&42u32.to_le_bytes());
        }
        b[0x60..0x64].copy_from_slice(&1u32.to_le_bytes());
        for (o, start) in [(0xa0, 2048u64), (0xac, 1024u64)] {
            b[o..o + 8].copy_from_slice(&start.to_le_bytes());
            b[o + 8..o + 12].copy_from_slice(&1024u32.to_le_bytes());
        }
        b[0xc4..0xcc].copy_from_slice(&3072u64.to_le_bytes());
        b
    }
    #[test]
    fn recognizes_spec_derived_header() {
        assert_eq!(probe_header(&fixture(), 3072).unwrap().root_offset, 1024);
    }
    #[test]
    fn rejects_every_short_header() {
        let b = fixture();
        for n in 0..1024 {
            assert_eq!(probe_header(&b[..n], 3072), Err(ProbeError::Truncated));
        }
    }
    #[test]
    fn rejects_wrong_magic() {
        let mut b = fixture();
        b[0] = 0;
        assert_eq!(probe_header(&b, 3072), Err(ProbeError::WrongType));
    }
    #[test]
    fn rejects_unknown_versions() {
        let mut b = fixture();
        b[64] = 43;
        assert_eq!(probe_header(&b, 3072), Err(ProbeError::Unsupported));
    }
    #[test]
    fn rejects_size_mismatch() {
        assert_eq!(probe_header(&fixture(), 3073), Err(ProbeError::Bounds));
    }
    #[test]
    fn rejects_overflowing_reference() {
        let mut b = fixture();
        b[0xac..0xb4].copy_from_slice(&u64::MAX.to_le_bytes());
        assert_eq!(probe_header(&b, 3072), Err(ProbeError::Bounds));
    }
    #[test]
    fn rejects_header_overlap() {
        let mut b = fixture();
        b[0xac..0xb4].copy_from_slice(&10u64.to_le_bytes());
        assert_eq!(probe_header(&b, 3072), Err(ProbeError::Bounds));
    }
    #[test]
    fn ffi_null_pointer() {
        assert_eq!(unsafe { onestore_probe(std::ptr::null(), 1024, 3072) }, 5);
    }
    #[test]
    fn ffi_returns_success_for_fixture() {
        let b = fixture();
        assert_eq!(unsafe { onestore_probe(b.as_ptr(), b.len(), 3072) }, 0);
    }
}
