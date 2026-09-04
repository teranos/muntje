// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// De Vrije Munt. What a Muntje is, in Brandon's words, is in CORNERSTONE.md.
/// This contract is the stempelsnijder (line 34): anyone cuts a Stempel here,
/// and whoever cut it owns it.
contract Muntje {
    /// A Stempel is the design of the visible aspects of a coin (line 27).
    /// The gezichten are fixed when the Stempel is cut (line 29).
    struct Stempel {
        address owner;
        string name;
        string[] gezichten;
    }

    Stempel[] private stempels;

    /// Cut a Stempel. Returns its number. The caller owns it.
    function cut(string calldata name, string[] calldata gezichten) external returns (uint256) {
        stempels.push(Stempel({owner: msg.sender, name: name, gezichten: gezichten}));
        return stempels.length - 1;
    }

    /// Read a Stempel back by number.
    function read(uint256 number)
        external
        view
        returns (address owner, string memory name, string[] memory gezichten)
    {
        Stempel storage s = stempels[number];
        return (s.owner, s.name, s.gezichten);
    }

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

    /// Strike a coin from a Stempel. Only the Stempel's owner may.
    function strike(uint256 stempel, uint256 gezicht, bytes32 hash) external {
        Stempel storage s = stempels[stempel];
        require(msg.sender == s.owner, "not the owner of this Stempel");
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
