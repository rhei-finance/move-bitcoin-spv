module bitcoin_spv::block_header;

use bitcoin_spv::btc_math::{btc_hash, to_u32};
use bitcoin_spv::utils;

// === Constants ===
const BLOCK_HEADER_SIZE :u64 = 80;

// === Errors ===
const EBlockHashNotMatch: u64 = 0;
const EInvalidBlockHeaderSize: u64 = 1;

public struct BlockHeader has store, drop, copy{
   internal: vector<u8> 
}


// === Block header methods ===

/// New block header
public fun new_block_header(raw_block_header: vector<u8>): BlockHeader {
    assert!(raw_block_header.length() == BLOCK_HEADER_SIZE, EInvalidBlockHeaderSize);

    return BlockHeader {
        internal: raw_block_header
    }
}

public fun block_hash(header: &BlockHeader) : vector<u8> {
    return btc_hash(header.internal)
}
public fun version(header: &BlockHeader): u32 {
    return to_u32(header.slice(0, 4))
}

public fun prev_block(header: &BlockHeader): vector<u8> {
    return header.slice(4, 36)
}

public fun merkle_root(header: &BlockHeader): vector<u8> {
    return header.slice(36, 68)
}

public fun timestamp(header: &BlockHeader): u32 {
    return to_u32(header.slice(68, 72))
}

public fun bits(header: &BlockHeader): u32 {
    return to_u32(header.slice(72, 76))
}

public fun nonce(header: &BlockHeader): u32 {
    return to_u32(header.slice(76, 80))
}

public fun verify_next_block(current_header: &BlockHeader, next_header: &BlockHeader): bool {
    assert!(current_header.block_hash() == next_header.prev_block(), EBlockHashNotMatch);
    return true
}


fun slice(header: &BlockHeader, start: u64, end: u64): vector<u8> {
    utils::slice(header.internal, start, end)
}
