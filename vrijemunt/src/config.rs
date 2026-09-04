//! `munt.conf`: `key: value` lines, one per setting. Nothing in the binary
//! knows an address or a key.

use std::collections::HashMap;

pub struct Config {
    pub rpc: String,
    pub contract: String,
    pub stempel: String,
    pub gezicht: String,
    pub key: String,
    pub name: String,
    pub face: String,
}

pub fn load(path: &str) -> Result<Config, String> {
    let text = std::fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))?;
    let mut map = HashMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (k, v) = line
            .split_once(':')
            .ok_or_else(|| format!("{path}: `{line}` is not `key: value`"))?;
        map.insert(k.trim().to_string(), v.trim().to_string());
    }
    let get = |k: &str| map.get(k).cloned().ok_or_else(|| format!("{path}: missing `{k}`"));
    Ok(Config {
        rpc: get("rpc")?,
        contract: get("contract")?,
        stempel: get("stempel")?,
        gezicht: get("gezicht")?,
        key: get("key")?,
        name: get("name")?,
        face: get("face")?,
    })
}
