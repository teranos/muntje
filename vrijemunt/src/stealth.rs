//! ERC-5564, scheme 1: secp256k1 with view tags. The bar publishes a
//! meta-address under its ENS name; a sender derives a one-time address from
//! it; only the bar's viewing key links the two (stone, line 64).

use k256::elliptic_curve::PrimeField;
use k256::elliptic_curve::sec1::ToEncodedPoint;
use k256::{AffinePoint, ProjectivePoint, Scalar, SecretKey};
use sha3::{Digest, Keccak256};

/// What the bar publishes: its spending and viewing public keys, compressed.
pub struct MetaAddress {
    pub spending: AffinePoint,
    pub viewing: AffinePoint,
}

/// What the bar keeps.
pub struct Keys {
    pub spending: Scalar,
    pub viewing: Scalar,
}

/// What a sender produces for one hand-in.
pub struct OneTime {
    pub address: [u8; 20],
    pub ephemeral_pub: [u8; 33],
    pub view_tag: u8,
}

impl Keys {
    pub fn random() -> Result<Self, String> {
        Ok(Self { spending: random_scalar()?, viewing: random_scalar()? })
    }

    pub fn meta(&self) -> MetaAddress {
        MetaAddress {
            spending: (ProjectivePoint::GENERATOR * self.spending).to_affine(),
            viewing: (ProjectivePoint::GENERATOR * self.viewing).to_affine(),
        }
    }

    /// The bar's side: from an announcement, is this bucket mine, and what
    /// key spends it. None if the view tag says it is someone else's.
    pub fn claim(&self, ephemeral_pub: &[u8; 33], view_tag: u8) -> Result<Option<(Scalar, [u8; 20])>, String> {
        let r_pub = point(ephemeral_pub)?;
        let shared = shared_secret(&(ProjectivePoint::from(r_pub) * self.viewing).to_affine());
        if shared[0] != view_tag {
            return Ok(None);
        }
        let h = scalar(&shared)?;
        let priv_key = self.spending + h;
        let pub_key = (ProjectivePoint::GENERATOR * priv_key).to_affine();
        Ok(Some((priv_key, address(&pub_key))))
    }
}

impl MetaAddress {
    /// `st:eth:0x` + spending + viewing, compressed, as the ENS text record.
    pub fn to_record(&self) -> String {
        format!("st:eth:0x{}{}", hex(&compressed(&self.spending)), hex(&compressed(&self.viewing)))
    }

    pub fn from_record(s: &str) -> Result<Self, String> {
        let body = s.strip_prefix("st:eth:0x").ok_or("meta-address must start with st:eth:0x")?;
        let bytes = unhex(body)?;
        if bytes.len() != 66 {
            return Err(format!("meta-address is {} bytes, expected 66", bytes.len()));
        }
        let mut spending = [0u8; 33];
        let mut viewing = [0u8; 33];
        spending.copy_from_slice(&bytes[..33]);
        viewing.copy_from_slice(&bytes[33..]);
        Ok(Self { spending: point(&spending)?, viewing: point(&viewing)? })
    }

    /// The sender's side: a fresh one-time address for this receiver.
    pub fn derive(&self) -> Result<OneTime, String> {
        let r = random_scalar()?;
        let r_pub = (ProjectivePoint::GENERATOR * r).to_affine();
        let shared = shared_secret(&(ProjectivePoint::from(self.viewing) * r).to_affine());
        let h = scalar(&shared)?;
        let stealth_pub = (ProjectivePoint::from(self.spending) + ProjectivePoint::GENERATOR * h).to_affine();
        Ok(OneTime { address: address(&stealth_pub), ephemeral_pub: compressed(&r_pub), view_tag: shared[0] })
    }
}

fn shared_secret(p: &AffinePoint) -> [u8; 32] {
    Keccak256::digest(compressed(p)).into()
}

fn scalar(bytes: &[u8; 32]) -> Result<Scalar, String> {
    Option::<Scalar>::from(Scalar::from_repr((*bytes).into())).ok_or_else(|| "hash is not a valid scalar".into())
}

fn random_scalar() -> Result<Scalar, String> {
    let mut bytes = [0u8; 32];
    std::io::Read::read_exact(&mut std::fs::File::open("/dev/urandom").map_err(|e| e.to_string())?, &mut bytes)
        .map_err(|e| e.to_string())?;
    Ok(*SecretKey::from_slice(&bytes).map_err(|e| e.to_string())?.to_nonzero_scalar())
}

fn point(compressed: &[u8; 33]) -> Result<AffinePoint, String> {
    let p = k256::PublicKey::from_sec1_bytes(compressed).map_err(|e| e.to_string())?;
    Ok(*p.as_affine())
}

fn compressed(p: &AffinePoint) -> [u8; 33] {
    let enc = p.to_encoded_point(true);
    let mut out = [0u8; 33];
    out.copy_from_slice(enc.as_bytes());
    out
}

/// keccak256 of the uncompressed point, last 20 bytes: an Ethereum address.
fn address(p: &AffinePoint) -> [u8; 20] {
    let enc = p.to_encoded_point(false);
    let h: [u8; 32] = Keccak256::digest(&enc.as_bytes()[1..]).into();
    let mut out = [0u8; 20];
    out.copy_from_slice(&h[12..]);
    out
}

pub fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

pub fn unhex(s: &str) -> Result<Vec<u8>, String> {
    let s = s.strip_prefix("0x").unwrap_or(s);
    if s.len() % 2 != 0 {
        return Err("odd-length hex".into());
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).map_err(|e| e.to_string()))
        .collect()
}

pub fn scalar_hex(s: &Scalar) -> String {
    hex(&s.to_bytes())
}

pub fn scalar_from_hex(s: &str) -> Result<Scalar, String> {
    let bytes = unhex(s)?;
    let arr: [u8; 32] = bytes.try_into().map_err(|_| "key must be 32 bytes")?;
    scalar(&arr)
}

#[cfg(test)]
mod tests {
    use super::*;

    // The address the sender derives is the address the bar's keys control.
    #[test]
    fn sender_and_receiver_agree() {
        let keys = Keys::random().unwrap();
        let meta = MetaAddress::from_record(&keys.meta().to_record()).unwrap();

        let one = meta.derive().unwrap();
        let (priv_key, addr) = keys.claim(&one.ephemeral_pub, one.view_tag).unwrap().expect("view tag matches");

        assert_eq!(addr, one.address);
        let pub_key = (ProjectivePoint::GENERATOR * priv_key).to_affine();
        assert_eq!(address(&pub_key), one.address);
    }

    // Two hand-ins to the same bar land on two unlinkable addresses.
    #[test]
    fn two_derivations_differ() {
        let meta = Keys::random().unwrap().meta();
        assert_ne!(meta.derive().unwrap().address, meta.derive().unwrap().address);
    }

    // Another bar's keys do not claim this bucket.
    #[test]
    fn a_stranger_cannot_claim() {
        let bar = Keys::random().unwrap();
        let stranger = Keys::random().unwrap();
        let one = bar.meta().derive().unwrap();
        let claimed = stranger.claim(&one.ephemeral_pub, one.view_tag).unwrap();
        // With one chance in 256 the view tag matches by accident; then the
        // address must still differ.
        if let Some((_, addr)) = claimed {
            assert_ne!(addr, one.address);
        }
    }
}
