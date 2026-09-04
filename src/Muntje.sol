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
}
