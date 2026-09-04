//! `key: value` lines, one per setting. Nothing in a binary knows an address
//! or a key; each asks the file for what it needs by name.

use std::collections::HashMap;

pub struct Config {
    path: String,
    map: HashMap<String, String>,
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
    Ok(Config { path: path.to_string(), map })
}

impl Config {
    pub fn get(&self, key: &str) -> Result<String, String> {
        self.map.get(key).cloned().ok_or_else(|| format!("{}: missing `{key}`", self.path))
    }
}
