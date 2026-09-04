//! bar: the receiver's side. Keys and the meta-address for the ENS record,
//! a hand-in of the night's coins to a fresh one-time address, and the claim
//! that proves a bucket is the bar's (stone, lines 58, 61, 64).

mod chain;
mod config;
mod stealth;

use stealth::{Keys, MetaAddress, hex, unhex};

fn main() {
    if let Err(e) = run() {
        eprintln!("bar: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let words: Vec<&str> = args.iter().map(String::as_str).collect();
    match words.as_slice() {
        ["keys"] => keys(),
        ["handin", ids_file] => handin(ids_file),
        ["claim", ephemeral, view_tag] => claim(ephemeral, view_tag),
        ["bucket", address, stempel, gezicht] => bucket(address, stempel, gezicht),
        _ => Err(
            "usage: bar keys | bar handin <ids file> | bar claim <ephemeral pub> <view tag> | bar bucket <address> <stempel> <gezicht>"
                .into(),
        ),
    }
}

/// What a one-time address holds. Anyone can read this; only the bar can
/// say which addresses are its own.
fn bucket(address: &str, stempel: &str, gezicht: &str) -> Result<(), String> {
    let cfg = config::load("bar.conf")?;
    let chain = chain::Chain { rpc: cfg.get("rpc")?, contract: cfg.get("contract")?, key: cfg.get("key")? };
    let back = chain.call("bucket(address,uint256,uint256)(uint256)", &[address, stempel, gezicht])?;
    println!("{}", back.first().ok_or("bucket: no answer")?);
    Ok(())
}

/// New keys for a bar. The record line goes under the bar's ENS name; the
/// two private keys go in bar.conf and nowhere else.
fn keys() -> Result<(), String> {
    let k = Keys::random()?;
    println!("record   {}", k.meta().to_record());
    println!("spending {}", stealth::scalar_hex(&k.spending));
    println!("viewing  {}", stealth::scalar_hex(&k.viewing));
    Ok(())
}

/// The settlement process: read the night's IDs, derive a one-time address
/// from the bar's published meta-address, hand the batch in through cast.
fn handin(ids_file: &str) -> Result<(), String> {
    let cfg = config::load("bar.conf")?;
    let chain = chain::Chain { rpc: cfg.get("rpc")?, contract: cfg.get("contract")?, key: cfg.get("key")? };
    let meta = MetaAddress::from_record(&cfg.get("record")?)?;
    let ids: Vec<String> = std::fs::read_to_string(ids_file)
        .map_err(|e| format!("{ids_file}: {e}"))?
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .map(String::from)
        .collect();
    if ids.is_empty() {
        return Err(format!("{ids_file}: no IDs"));
    }

    let one = meta.derive()?;
    let to = format!("0x{}", hex(&one.address));
    let ephemeral = format!("0x{}", hex(&one.ephemeral_pub));
    let tag = format!("0x{:02x}", one.view_tag);
    let list = format!("[{}]", ids.join(","));

    println!("to        {to}");
    println!("ephemeral {ephemeral}");
    println!("viewtag   {tag}");
    println!("coins     {}", ids.len());

    let tx = chain.send("handIn(address,bytes,bytes,bytes32[])", &[&to, &ephemeral, &tag, &list])?;
    println!("tx        {tx}");
    Ok(())
}

/// The bar's proof: with its keys, an announcement either is its bucket or
/// is not. Prints the one-time address and the key that spends it.
fn claim(ephemeral: &str, view_tag: &str) -> Result<(), String> {
    let cfg = config::load("bar.conf")?;
    let keys = Keys {
        spending: stealth::scalar_from_hex(&cfg.get("spending")?)?,
        viewing: stealth::scalar_from_hex(&cfg.get("viewing")?)?,
    };
    let eph: [u8; 33] = unhex(ephemeral)?.try_into().map_err(|_| "ephemeral pub must be 33 bytes")?;
    let tag = unhex(view_tag)?;
    let tag = *tag.first().ok_or("view tag must be one byte")?;

    match keys.claim(&eph, tag)? {
        None => println!("not mine"),
        Some((priv_key, addr)) => {
            println!("mine     0x{}", hex(&addr));
            println!("spends   {}", stealth::scalar_hex(&priv_key));
        }
    }
    Ok(())
}
