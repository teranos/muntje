//! vrijemunt: strike one Muntje onto paper. The coin is struck the moment it
//! is printed (stone, line 43). The ID is drawn here and lives only on the
//! paper (lines 31, 32, 52); the chain gets its hash, through `cast`.

mod chain;
mod config;
mod paper;

use std::io::Read;

use sha3::{Digest, Keccak256};

fn main() {
    if let Err(e) = run() {
        eprintln!("vrijemunt: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let cfg = config::load("munt.conf")?;
    let chain = chain::Chain { rpc: cfg.get("rpc")?, contract: cfg.get("contract")?, key: cfg.get("key")? };
    let stempel = cfg.get("stempel")?;
    let gezicht = cfg.get("gezicht")?;

    let id = draw_id()?;
    let hash = keccak(&id);
    let id_hex = hex(&id);
    let hash_hex = hex(&hash);

    println!("id    {id_hex}");
    println!("hash  {hash_hex}");

    let tx = chain.send("strike(uint256,uint256,bytes32)", &[&stempel, &gezicht, &hash_hex])?;
    println!("tx    {tx}");

    let back = chain.call("coin(bytes32)(uint256,uint256,bool)", &[&hash_hex])?;
    let spent = back.get(2).ok_or("coin: no spent")? == "true";
    println!("coin  stempel {} gezicht {} spent {spent}", back[0], back[1]);
    if spent {
        return Err("a fresh coin reads back spent".into());
    }

    paper::print(&cfg.get("name")?, &cfg.get("face")?, &id_hex)?;
    println!("printed");
    Ok(())
}

/// 32 bytes from the operating system. Nothing on-chain can do this, because
/// everything on-chain is public.
fn draw_id() -> Result<[u8; 32], String> {
    let mut id = [0u8; 32];
    std::fs::File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut id))
        .map_err(|e| format!("/dev/urandom: {e}"))?;
    Ok(id)
}

/// The same hash the contract will compute from the ID when it is shown.
fn keccak(id: &[u8; 32]) -> [u8; 32] {
    let mut h = Keccak256::new();
    h.update(id);
    h.finalize().into()
}

fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(2 + bytes.len() * 2);
    s.push_str("0x");
    for b in bytes {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    // keccak256 of 32 zero bytes, a value every Ethereum tool agrees on.
    #[test]
    fn keccak_matches_the_chain() {
        let zero = [0u8; 32];
        assert_eq!(
            hex(&keccak(&zero)),
            "0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563"
        );
    }

    #[test]
    fn ids_differ() {
        assert_ne!(draw_id().unwrap(), draw_id().unwrap());
    }
}
