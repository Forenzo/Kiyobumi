use super::super::common::FileChunkReference64x32;
use crate::Reader;
use crate::errors::{ErrorKind, Result};
use crate::onestore::desktop::parse::Parse;
use onenote_parser_macros::Parse;

/// See [\[MS-ONESTORE\] 2.3.3.1](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/158030a2-dbf0-4b92-bf6e-1a91a403aebd)
#[derive(Debug)]
#[allow(dead_code)]
pub(crate) struct TransactionLogFragment {
    pub(crate) size_table: Vec<TransactionEntry>,
    pub(crate) next_fragment: Option<FileChunkReference64x32>,
}

// Kiyobumi 0.7.2 modification (MPL-2.0): honour the header's committed
// transaction count. Final-fragment trailing bytes are explicitly undefined.
impl TransactionLogFragment {
    pub(crate) fn parse_committed(reader: Reader, size: usize, remaining: &mut u32) -> Result<Self> {
        if size < 8 || *remaining == 0 {
            return Err(ErrorKind::MalformedOneStoreData("Invalid transaction log fragment size or count".into()).into());
        }
        let mut size_table = Vec::new();
        // Non-final fragments reserve twelve bytes for the continuation. A
        // final fragment may end immediately after its last committed entry.
        let entry_capacity = if size < 20 { size / 8 } else { (size - 12) / 8 };
        for _ in 0..entry_capacity {
            let entry = TransactionEntry::parse(reader)?;
            if entry.is_sentinel() {
                *remaining -= 1;
                if *remaining == 0 {
                    return Ok(Self { size_table, next_fragment: None });
                }
            } else {
                size_table.push(entry);
            }
        }
        Ok(Self {
            size_table,
            next_fragment: Some(FileChunkReference64x32::parse(reader)?),
        })
    }
}

/// See [\[MS-ONESTORE\] 2.3.3.2](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/c00897d9-d90a-4707-b9fb-58c93e490322)
#[derive(Debug, Parse)]
#[allow(dead_code)]
pub(crate) struct TransactionEntry {
    pub(crate) src_id: u32,
    pub(crate) transaction_entry_switch: u32,
}

impl TransactionEntry {
    pub(crate) fn is_sentinel(&self) -> bool {
        self.src_id == 0x00000001
    }
}

#[cfg(test)]
mod regression_tests {
    use super::*;
    fn entries(pairs: &[(u32, u32)]) -> Vec<u8> {
        pairs.iter().flat_map(|(a,b)| a.to_le_bytes().into_iter().chain(b.to_le_bytes())).collect()
    }
    #[test]
    fn final_commit_ignores_stale_entries_and_pointer() {
        let mut bytes = entries(&[(42, 3), (1, 0)]);
        bytes.resize(1024, 0xff);
        let mut remaining = 1;
        let fragment = TransactionLogFragment::parse_committed(&mut crate::reader::Reader::new(&bytes), bytes.len(), &mut remaining).unwrap();
        assert_eq!(remaining, 0);
        assert_eq!(fragment.size_table.len(), 1);
        assert_eq!(fragment.size_table[0].src_id, 42);
        assert!(fragment.next_fragment.is_none());
    }
    #[test]
    fn unfinished_log_preserves_continuation() {
        let mut bytes = entries(&[(42, 3), (1, 0)]);
        bytes.extend_from_slice(&128u64.to_le_bytes());
        bytes.extend_from_slice(&16u32.to_le_bytes());
        let mut remaining = 2;
        let fragment = TransactionLogFragment::parse_committed(&mut crate::reader::Reader::new(&bytes), bytes.len(), &mut remaining).unwrap();
        assert_eq!(remaining, 1);
        assert_eq!(fragment.next_fragment.unwrap().cb, 16);
        let final_bytes = entries(&[(43, 2), (1, 0)]);
        let final_fragment = TransactionLogFragment::parse_committed(&mut crate::reader::Reader::new(&final_bytes), 16, &mut remaining).unwrap();
        assert_eq!(remaining, 0);
        assert!(final_fragment.next_fragment.is_none());
    }
    #[test]
    fn truncated_committed_entry_is_rejected() {
        let bytes = entries(&[(42, 3)]);
        assert!(TransactionLogFragment::parse_committed(&mut crate::reader::Reader::new(&bytes), 28, &mut 1).is_err());
    }
}
