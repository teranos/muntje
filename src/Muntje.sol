// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// The one call De Vrije Munt makes to ENS: who owns a name, right now.
interface IENS {
    function owner(bytes32 node) external view returns (address);
}

/// De Vrije Munt. What a Muntje is, in Brandon's words, is in CORNERSTONE.md.
/// This contract is the stempelsnijder (line 34): an ENS name cuts a Stempel
/// here (line 37), and whoever controls that name controls the press.
contract Muntje {
    IENS public immutable ens;

    /// A Stempel is the design of the visible aspects of a coin (line 27).
    /// The gezichten are fixed when the Stempel is cut (line 29). The owner is
    /// the ENS name, so the press follows the name when the name changes hands.
    struct Stempel {
        bytes32 node;
        string[] gezichten;
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

    /// Cut a Stempel as an ENS name. Returns its number. No name, no Stempel.
    function cut(bytes32 node, string[] calldata gezichten) external returns (uint256) {
        require(ens.owner(node) == msg.sender, "you do not control this name");
        stempels.push(Stempel({node: node, gezichten: gezichten}));
        return stempels.length - 1;
    }

    /// Read a Stempel back by number.
    function read(uint256 number) external view returns (bytes32 node, string[] memory gezichten) {
        Stempel storage s = stempels[number];
        return (s.node, s.gezichten);
    }

    /// Strike a coin from a Stempel. Only whoever controls the name may, now.
    function strike(uint256 stempel, uint256 gezicht, bytes32 hash) external {
        Stempel storage s = stempels[stempel];
        require(ens.owner(s.node) == msg.sender, "you do not control this name");
        require(gezicht < s.gezichten.length, "no such gezicht on this Stempel");
        require(!coins[hash].struck, "a coin with this hash is already struck");
        coins[hash] = Coin({struck: true, spent: false, stempel: stempel, gezicht: gezicht});
    }

    /// Read a coin back by its hash.
    function coin(bytes32 hash) external view returns (uint256 stempel, uint256 gezicht, bool spent) {
        Coin storage c = coins[hash];
        require(c.struck, "no coin with this hash");
        return (c.stempel, c.gezicht, c.spent);
    }
}
