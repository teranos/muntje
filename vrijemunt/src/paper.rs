//! The receipt. The ID goes on it as a QR (stone, line 49); the name and the
//! face go on it in words, so the paper says what it is without a phone.

use tm20::command::Align;
use tm20::encode::encode;
use tm20::symbol::Qr;
use tm20::{Command, Document, Transport, Usb};

use crate::config::Config;

pub fn print(cfg: &Config, id: &str) -> Result<(), String> {
    let doc = Document::new(vec![
        Command::Init,
        Command::Align(Align::Center),
        Command::Size { width: 2, height: 2 },
        Command::Text(format!("{}\n", cfg.name)),
        Command::Size { width: 1, height: 1 },
        Command::Text(format!("{}\n", cfg.face)),
        Command::Feed { lines: 1 },
        Command::Qr(Qr { data: id.to_string(), size: 6, ..Qr::default() }),
        Command::Feed { lines: 1 },
        Command::Text("muntje\n".to_string()),
        Command::Feed { lines: 4 },
        Command::Cut,
    ]);
    let bytes = encode(&doc).map_err(|e| e.to_string())?;
    let mut usb = Usb::open(None).map_err(|e| e.to_string())?;
    usb.write(&bytes).map_err(|e| e.to_string())
}
