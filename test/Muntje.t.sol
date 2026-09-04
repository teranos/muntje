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

    function same(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
