// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Muntje} from "../src/Muntje.sol";

/// No forge-std yet. A test passes when it does not revert.
contract MuntjeTest {
    Muntje private munt;

    function setUp() external {
        munt = new Muntje();
    }

    function test_cut_returns_a_number_and_the_caller_owns_it() external {
        string[] memory gezichten = new string[](2);
        gezichten[0] = "beer";
        gezichten[1] = "coat";

        uint256 number = munt.cut("Common S3nse 2026", gezichten);

        require(number == 0, "first Stempel is number 0");
        (address owner,,) = munt.read(number);
        require(owner == address(this), "the caller owns what it cut");
    }

    function test_read_gives_back_what_was_cut() external {
        string[] memory gezichten = new string[](2);
        gezichten[0] = "beer";
        gezichten[1] = "coat";
        uint256 number = munt.cut("Common S3nse 2026", gezichten);

        (, string memory name, string[] memory back) = munt.read(number);

        require(same(name, "Common S3nse 2026"), "name");
        require(back.length == 2, "two gezichten");
        require(same(back[0], "beer"), "beer");
        require(same(back[1], "coat"), "coat");
    }

    function test_the_owner_strikes_a_coin_and_it_reads_back_unspent() external {
        string[] memory gezichten = new string[](2);
        gezichten[0] = "beer";
        gezichten[1] = "coat";
        uint256 stempel = munt.cut("Common S3nse 2026", gezichten);

        // The ID stays with the coin (line 32); only its hash reaches here.
        bytes32 hash = keccak256("a random ID that only the paper knows");
        munt.strike(stempel, 0, hash);

        (uint256 s, uint256 g, bool spent) = munt.coin(hash);
        require(s == stempel, "points at its Stempel");
        require(g == 0, "beer");
        require(!spent, "fresh coin is unspent");
    }

    function test_only_the_owner_can_strike() external {
        string[] memory gezichten = new string[](1);
        gezichten[0] = "beer";
        uint256 stempel = munt.cut("Common S3nse 2026", gezichten);

        Stranger stranger = new Stranger();
        bool ok = stranger.tryStrike(munt, stempel, keccak256("another ID"));
        require(!ok, "a stranger must not strike from a Stempel it does not own");
    }

    function same(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

/// Someone who did not cut the Stempel. Without forge-std there is no prank,
/// so a second contract is the second caller.
contract Stranger {
    function tryStrike(Muntje munt, uint256 stempel, bytes32 hash) external returns (bool ok) {
        (ok,) = address(munt).call(abi.encodeCall(Muntje.strike, (stempel, 0, hash)));
    }
}
