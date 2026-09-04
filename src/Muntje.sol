// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// The one call De Vrije Munt makes to ENS: who owns label.eth, right now.
/// This is ENSv2's registry interface, live on Sepolia; v1 answers the same
/// question as owner(node) and gets a three-line adapter when mainnet needs it.
interface IENS {
    function findOwner(string calldata label) external view returns (address);
}

/// De Vrije Munt. What a Muntje is, in Brandon's words, is in CORNERSTONE.md.
/// This contract is the stempelsnijder (line 34): an ENS name cuts a Stempel
/// here (line 37), and whoever controls that name controls the press.
contract Muntje {
    IENS public immutable ens;

    /// A Stempel is the design of the visible aspects of a coin (line 27).
    /// The gezichten are fixed when the Stempel is cut (line 29). The owner is
    /// the ENS name, so the press follows the name when the name changes hands.
    /// It has an end-date and ink (lines 54, 55): every strike uses one ink,
    /// and when either runs out a new Stempel has to be cut (line 56).
    struct Stempel {
        string label;
        string[] gezichten;
        uint64 endDate;
        uint64 ink;
    }

    Stempel[] private stempels;

    /// A coin is a hash on-chain and nothing more (lines 31, 32). It points at
    /// the Stempel it was struck from, which is what makes it part of that
    /// editie (line 28), and at one of that Stempel's gezichten.
    struct Coin {
        bool struck;
        bool spent;
        uint256 stempel;
        uint256 gezicht;
    }

    mapping(bytes32 hash => Coin) private coins;

    constructor(IENS registry) {
        ens = registry;
    }

    /// Cut a Stempel as label.eth. Returns its number. No name, no Stempel.
    function cut(string calldata label, string[] calldata gezichten, uint64 endDate, uint64 ink)
        external
        returns (uint256)
    {
        require(ens.findOwner(label) == msg.sender, "you do not control this name");
        stempels.push(Stempel({label: label, gezichten: gezichten, endDate: endDate, ink: ink}));
        return stempels.length - 1;
    }

    /// Read a Stempel back by number. Ink is what is left, not what it started with.
    function read(uint256 number)
        external
        view
        returns (string memory label, string[] memory gezichten, uint64 endDate, uint64 ink)
    {
        Stempel storage s = stempels[number];
        return (s.label, s.gezichten, s.endDate, s.ink);
    }

    /// Strike a coin from a Stempel. Only whoever controls the name may, now,
    /// and only while the Stempel has ink and time.
    function strike(uint256 stempel, uint256 gezicht, bytes32 hash) external {
        Stempel storage s = stempels[stempel];
        require(ens.findOwner(s.label) == msg.sender, "you do not control this name");
        require(block.timestamp < s.endDate, "this Stempel has passed its end-date");
        require(s.ink > 0, "this Stempel is out of ink");
        require(gezicht < s.gezichten.length, "no such gezicht on this Stempel");
        require(!coins[hash].struck, "a coin with this hash is already struck");
        s.ink -= 1;
        coins[hash] = Coin({struck: true, spent: false, stempel: stempel, gezicht: gezicht});
    }

    /// Read a coin back by its hash.
    function coin(bytes32 hash) external view returns (uint256 stempel, uint256 gezicht, bool spent) {
        Coin storage c = coins[hash];
        require(c.struck, "no coin with this hash");
        return (c.stempel, c.gezicht, c.spent);
    }

    /// The bucket: what a one-time address holds, per Stempel, per gezicht.
    /// The receiver is an ENS name (line 58), but the name never appears
    /// here: the address is derived from the stealth meta-address the name
    /// publishes, and only the name's viewing key links the two (line 64).
    mapping(address receiver => mapping(uint256 stempel => mapping(uint256 gezicht => uint256))) private buckets;

    /// ERC-5564. The receiver scans these with its viewing key to find the
    /// buckets that are its own. Scheme 1 is secp256k1 with view tags.
    event Announcement(
        uint256 indexed schemeId, address indexed stealthAddress, address indexed caller, bytes ephemeralPubKey, bytes metadata
    );

    /// A night of coins handed in at once (line 61). Showing the IDs is the
    /// authorisation (line 32), so anyone may submit on the receiver's behalf.
    /// One bad coin refuses the whole batch.
    function handIn(address receiver, bytes calldata ephemeralPubKey, bytes calldata metadata, bytes32[] calldata ids)
        external
    {
        for (uint256 i = 0; i < ids.length; i++) {
            Coin storage c = coins[keccak256(abi.encodePacked(ids[i]))];
            require(c.struck, "no coin with this ID");
            require(!c.spent, "this coin is already spent");
            c.spent = true;
            buckets[receiver][c.stempel][c.gezicht] += 1;
        }
        emit Announcement(1, receiver, msg.sender, ephemeralPubKey, metadata);
    }

    /// How many of a gezicht a one-time address holds from a Stempel.
    function bucket(address receiver, uint256 stempel, uint256 gezicht) external view returns (uint256) {
        return buckets[receiver][stempel][gezicht];
    }
}
