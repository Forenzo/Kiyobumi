use crate::Reader;
use crate::errors::{ErrorKind, Result};

use crate::onestore::desktop::common::{FileChunkReference, FileChunkReference64x32};
use crate::onestore::desktop::file_node::{FileNode, FileNodeData};
use crate::onestore::desktop::file_structure::{FileNodeListFragment, ParseContext};

#[derive(Debug, Clone, Default)]
pub(crate) struct FileNodeList {
    pub(crate) file_node_sequence: Vec<FileNode>,
}

impl FileNodeList {
    pub(crate) fn parse(reader: Reader, context: &mut ParseContext, size: usize) -> Result<Self> {
        let mut builder = FileNodeListBuilder {
            next_fragment_id: 0,
            file_node_sequence: Vec::new(),
        };

        let mut next_fragment_ref =
            builder.add_fragment(FileNodeListFragment::parse(reader, context, size)?)?;

        while !next_fragment_ref.is_fcr_nil() && !next_fragment_ref.is_fcr_zero() {
            let mut reader = next_fragment_ref.resolve_to_reader(reader)?;
            let fragment =
                FileNodeListFragment::parse(&mut reader, context, next_fragment_ref.cb as usize)?;
            next_fragment_ref = builder.add_fragment(fragment)?;
        }
        // MS-ONESTORE 2.1.6: older revision-list references MUST be
        // ignored. They can point at reclaimed storage (including zero).
        let last_reference = builder.file_node_sequence.iter().rev().find_map(|node| {
            if let FileNodeData::DeferredRevisionManifestListReference(reference) = &node.fnd {
                Some(reference.clone())
            } else { None }
        });
        if let Some(reference) = last_reference {
            let mut revision_reader = reference.resolve_to_reader(reader)?;
            let list = Self::parse(&mut revision_reader, context, reference.data_size())?;
            let last_index = builder.file_node_sequence.iter().rposition(|node|
                matches!(node.fnd, FileNodeData::DeferredRevisionManifestListReference(_))).unwrap();
            builder.file_node_sequence[last_index].fnd = FileNodeData::RevisionManifestListReferenceFND(
                crate::onestore::desktop::file_node::shared::PointerToListFND { list });
            builder.file_node_sequence.retain(|node|
                !matches!(node.fnd, FileNodeData::DeferredRevisionManifestListReference(_)));
        }
        Ok(Self {
            file_node_sequence: builder.file_node_sequence,
        })
    }

    /// Iterate over the .fnd fields for all toplevel nodes
    pub(crate) fn iter_data(&self) -> FileNodeDataIterator<'_> {
        FileNodeDataIterator::new(self)
    }
}

struct FileNodeListBuilder {
    pub(crate) file_node_sequence: Vec<FileNode>,

    // Used for validation during construction
    next_fragment_id: u32,
}

impl FileNodeListBuilder {
    fn add_fragment(&mut self, fragment: FileNodeListFragment) -> Result<FileChunkReference64x32> {
        let fragment_sequence = fragment.header.n_fragment_sequence;
        if fragment_sequence != self.next_fragment_id {
            return Err(ErrorKind::MalformedOneStoreData(
                format!(
                    "Invalid n_fragment_sequence. Was {}, expected {}",
                    fragment_sequence, self.next_fragment_id
                )
                .into(),
            )
            .into());
        }
        self.next_fragment_id = fragment_sequence + 1;

        for item in fragment
            .file_nodes
            .iter()
            .filter(|f| !matches!(f.fnd, FileNodeData::ChunkTerminatorFND))
        {
            self.file_node_sequence.push(item.clone());
        }
        let next_fragment_ref = fragment.next_fragment.clone();
        Ok(next_fragment_ref)
    }
}

pub(crate) struct FileNodeDataIterator<'a> {
    data: &'a FileNodeList,
    index: usize,
}

impl<'a> FileNodeDataIterator<'a> {
    fn new(node_list: &'a FileNodeList) -> Self {
        FileNodeDataIterator {
            data: node_list,
            index: 0,
        }
    }

    pub(crate) fn peek(&self) -> Option<&'a FileNodeData> {
        let index = self.index;
        if index >= self.data.file_node_sequence.len() {
            None
        } else {
            Some(&self.data.file_node_sequence[index].fnd)
        }
    }

    pub(crate) fn get_index(&self) -> usize {
        self.index
    }
}

impl<'a> Iterator for FileNodeDataIterator<'a> {
    type Item = &'a FileNodeData;

    fn next(&mut self) -> Option<Self::Item> {
        let target_index = self.index;
        self.index += 1;
        if target_index >= self.data.file_node_sequence.len() {
            return None;
        }

        let result = &self.data.file_node_sequence[target_index];
        Some(&result.fnd)
    }
}

#[cfg(test)]
mod regression_tests {
    use super::*;
    fn fragment(nodes: &[u8], id: u32) -> Vec<u8> {
        let mut out = 0xA4567AB1F5F7F4C4u64.to_le_bytes().to_vec();
        out.extend_from_slice(&id.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes());
        out.extend_from_slice(nodes);
        out.extend_from_slice(&0u64.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes());
        out.extend_from_slice(&0x8BC215C38233BA4Bu64.to_le_bytes());
        out
    }
    fn reference(offset: u64, size: u32) -> Vec<u8> {
        let header = 0x010u32 | (16 << 10) | (2 << 27);
        let mut out = header.to_le_bytes().to_vec();
        out.extend_from_slice(&offset.to_le_bytes());
        out.extend_from_slice(&size.to_le_bytes());
        out
    }
    #[test]
    fn reclaimed_older_revision_is_ignored() {
        let mut nodes = reference(0, 0);
        nodes.extend(reference(68, 36));
        let mut bytes = fragment(&nodes, 2);
        bytes.extend(fragment(&[], 3));
        let list = FileNodeList::parse(&mut crate::reader::Reader::new(&bytes), &mut ParseContext::new(), 68).unwrap();
        assert_eq!(list.file_node_sequence.len(), 1);
        assert!(matches!(&list.file_node_sequence[0].fnd, FileNodeData::RevisionManifestListReferenceFND(_)));
    }
    #[test]
    fn invalid_current_revision_is_not_silently_skipped() {
        let bytes = fragment(&reference(0, 0), 2);
        assert!(FileNodeList::parse(&mut crate::reader::Reader::new(&bytes), &mut ParseContext::new(), bytes.len()).is_err());
    }
}
