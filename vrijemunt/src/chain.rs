//! The chain, through `cast`. Signing, nonces and gas are its problem, and
//! it is already pinned by the flake.

use std::process::Command;

use crate::config::Config;

/// Send the strike and wait for it. Returns the transaction hash.
pub fn strike(cfg: &Config, hash: &str) -> Result<String, String> {
    let out = cast(&[
        "send",
        &cfg.contract,
        "strike(uint256,uint256,bytes32)",
        &cfg.stempel,
        &cfg.gezicht,
        hash,
        "--rpc-url",
        &cfg.rpc,
        "--private-key",
        &cfg.key,
        "--json",
    ])?;
    field(&out, "transactionHash")
}

/// Read the coin back: Stempel number, gezicht index, spent.
pub fn coin(cfg: &Config, hash: &str) -> Result<(String, String, bool), String> {
    let out = cast(&[
        "call",
        &cfg.contract,
        "coin(bytes32)(uint256,uint256,bool)",
        hash,
        "--rpc-url",
        &cfg.rpc,
    ])?;
    let mut lines = out.lines().map(str::trim);
    let stempel = lines.next().ok_or("coin: no stempel")?.to_string();
    let gezicht = lines.next().ok_or("coin: no gezicht")?.to_string();
    let spent = lines.next().ok_or("coin: no spent")? == "true";
    Ok((stempel, gezicht, spent))
}

fn cast(args: &[&str]) -> Result<String, String> {
    let out = Command::new("cast")
        .args(args)
        .output()
        .map_err(|e| format!("cast: {e}"))?;
    if !out.status.success() {
        return Err(format!("cast {}: {}", args[0], String::from_utf8_lossy(&out.stderr).trim()));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// One string field out of cast's JSON, without a JSON library.
fn field(json: &str, key: &str) -> Result<String, String> {
    let needle = format!("\"{key}\":\"");
    let start = json.find(&needle).ok_or_else(|| format!("no `{key}` in cast output"))? + needle.len();
    let end = json[start..].find('"').ok_or_else(|| format!("unterminated `{key}`"))?;
    Ok(json[start..start + end].to_string())
}
