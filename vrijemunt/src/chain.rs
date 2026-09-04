//! The chain, through `cast`. Signing, nonces and gas are its problem, and
//! it is already pinned by the flake.

use std::process::Command;

/// Where and as whom to talk.
pub struct Chain {
    pub rpc: String,
    pub contract: String,
    pub key: String,
}

impl Chain {
    /// Send a call and wait for it. Returns the transaction hash.
    pub fn send(&self, sig: &str, args: &[&str]) -> Result<String, String> {
        let mut argv = vec!["send", &self.contract, sig];
        argv.extend_from_slice(args);
        argv.extend_from_slice(&["--rpc-url", &self.rpc, "--private-key", &self.key, "--json"]);
        let out = cast(&argv)?;
        field(&out, "transactionHash")
    }

    /// A read. Returns cast's output lines, one per return value.
    pub fn call(&self, sig: &str, args: &[&str]) -> Result<Vec<String>, String> {
        let mut argv = vec!["call", &self.contract, sig];
        argv.extend_from_slice(args);
        argv.extend_from_slice(&["--rpc-url", &self.rpc]);
        Ok(cast(&argv)?.lines().map(|l| l.trim().to_string()).collect())
    }
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
