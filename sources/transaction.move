module bitcoin_spv::transaction;
use bitcoin_spv::btc_math::{btc_hash, covert_to_compact_size, to_number, compact_size};
use bitcoin_spv::utils::slice;

// === BTC script opcodes ===
/// Duplicates the top stack item
const OP_DUP: u8 = 0x76;
/// Pop the top stack item and push its RIPEMD(SHA256(top item)) hash
const OP_HASH160: u8 = 0xa9;
/// Push the next 20 bytes as an array onto the stack
const OP_DATA_20: u8 = 0x14;
/// Returns success if the inputs are exactly equal, failure otherwise
const OP_EQUALVERIFY: u8  = 0x88;
/// https://en.bitcoin.it/wiki/OP_CHECKSIG pushing 1/0 for success/failure
const OP_CHECKSIG: u8 = 0xac;
/// nulldata script
const OP_RETURN: u8 = 0x6a;
/// Read the next 4 bytes as N. Push the next N bytes as an array onto the stack.
const OP_PUSHDATA4: u8 = 0x4e;
/// Read the next 2 bytes as N. Push the next N bytes as an array onto the stack.
const OP_PUSHDATA2: u8 = 0x4d;
/// Read the next byte as N. Push the next N bytes as an array onto the stack.
const OP_PUSHDATA1: u8 = 0x4c;
/// Push the next 75 bytes onto the stack.
const OP_DATA_75: u8 = 0x4b;


/// Represents a Bitcoin transaction output
public struct Output has copy, drop {
    amount: u256,
    script_pubkey: vector<u8>
}

/// Represents a Bitcoin transaction
public struct Transaction has copy, drop {
    version: vector<u8>,
    input_count: u256,
    inputs: vector<u8>,
    output_count: u256,
    outputs: vector<Output>,
    tx_id: vector<u8>,
    lock_time: vector<u8>
}


/// Bitcoin transaction constructor
public fun make_transaction(
    version: vector<u8>,
    input_count: u256,
    inputs: vector<u8>,
    output_count: u256,
    outputs: vector<u8>,
    lock_time: vector<u8>,
): Transaction {
    assert!(version.length() == 4);
    assert!(lock_time.length() == 4);
    let number_input_bytes = covert_to_compact_size(input_count);
    let number_output_bytes = covert_to_compact_size(output_count);

    // compute TxID
    let mut tx_data = version;
    tx_data.append(number_input_bytes);
    tx_data.append(inputs);
    tx_data.append(number_output_bytes);
    tx_data.append(outputs);
    tx_data.append(lock_time);

    let tx_id = btc_hash(tx_data);

    let outputs_decoded = make_outputs(output_count, outputs);

    Transaction {
        version,
        input_count,
        inputs,
        output_count,
        outputs: outputs_decoded,
        lock_time,
        tx_id
    }
}

public fun parse_output(amount: u256, script_pubkey: vector<u8>): Output {
    Output {
        amount,
        script_pubkey
    }
}

public fun tx_id(tx: &Transaction): vector<u8> {
    tx.tx_id
}

public fun outputs(tx: &Transaction): vector<Output> {
    tx.outputs
}

public fun amount(output: &Output): u256 {
    output.amount
}

public fun is_pk_hash_script(output: &Output): bool {
    let script = output.script_pubkey;

    script.length() == 25 &&
		script[0] == OP_DUP &&
		script[1] == OP_HASH160 &&
		script[2] == OP_DATA_20 &&
		script[23] == OP_EQUALVERIFY &&
		script[24] == OP_CHECKSIG
}

public fun is_op_return(output: &Output): bool {
    let script = output.script_pubkey;
    script.length() > 0 && script[0] == OP_RETURN
}

// TODO: add support script addresses.
// TODO: check and verify the address to make sure we support it. Return error otherwise
/// decodes address (p2pkh or p2pwkh) from the output
public fun p2pkh_address(output: &Output): vector<u8> {
    let script = output.script_pubkey;
    slice(script, 3, 23)
}

/// Extracts the data payload from an OP_RETURN output in a transaction.
/// script = OP_RETURN <data>.
/// If transaction mined to BTC, then this must pass basic conditions
/// include the conditions for OP_RETURN script.
/// This why we only return the message without check size message.
public fun op_return(output: &Output): vector<u8> {
    let script = output.script_pubkey;

    if (script.length() == 1) {
        return vector[]
    };

    if (script[1] <= OP_DATA_75) {
        // script = OP_RETURN OP_DATA_<len> DATA
        //          |      2 bytes         |  the rest |
        return slice(script, 2, script.length())
    };
    if (script[1] == OP_PUSHDATA1) {
        // script = OP_RETURN OP_PUSHDATA1 <1 bytes>    DATA
        //          |      4 bytes                  |  the rest |
        return slice(script, 3, script.length())
    };
    if (script[1] == OP_PUSHDATA2) {
        // script = OP_RETURN OP_PUSHDATA2 <2 bytes>   DATA
        //          |      4 bytes                  |  the rest |
        return slice(script, 4, script.length())
    };
    // script = OP_RETURN OP_PUSHDATA4 <4-bytes> DATA
    //          |      6 bytes                  |  the rest |
    slice(script, 6, script.length())
}

// TODO: create readbytes APIs
public(package) fun make_outputs(number_input: u256, inputs_bytes: vector<u8>): vector<Output> {
    let mut outputs = vector[];
    let mut start = 0u64;
    let mut script_pubkey_size;
    let mut i = 0;

    while (i < number_input) {
        let amount = slice(inputs_bytes, start, start + 8); // 8 bytes of amount
        start = start + 8;
        (script_pubkey_size, start) = compact_size(inputs_bytes, start);
        let script_pubkey = slice(inputs_bytes, start, (start + (script_pubkey_size as u64)));
        start = start + (script_pubkey_size as u64);
        let output = parse_output(to_number(amount, 0, 8), script_pubkey);
        outputs.push_back(output);
        i = i + 1;
    };

    outputs
}
