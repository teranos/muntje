// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IENS, Muntje} from "../src/Muntje.sol";

/// Answers owner(node) from a table. The real registry does the same thing
/// with a much longer history.
contract MockENS is IENS {
    mapping(bytes32 => address) private owners;

    function set(bytes32 node, address who) external {
        owners[node] = who;
    }

    function owner(bytes32 node) external view returns (address) {
        return owners[node];
    }
}

/// No forge-std yet. A test passes when it does not revert.
contract MuntjeTest {
    MockENS private ens;
    Muntje private munt;

    // namehash("commons3nse.eth") would be the real value; any node works here.
    bytes32 private constant COMMONS3NSE = keccak256("commons3nse.eth");

    // A Stempel that will not run out during a test.
    uint64 private TOMORROW;
    uint64 private constant PLENTY = 1000;

    function setUp() external {
        ens = new MockENS();
        ens.set(COMMONS3NSE, address(this));
        munt = new Muntje(ens);
        TOMORROW = uint64(block.timestamp + 1 days);
    }

    function test_the_name_owner_cuts_a_stempel_and_reads_it_back() external {
        string[] memory gezichten = new string[](2);
        gezichten[0] = "beer";
        gezichten[1] = "coat";

        uint256 number = munt.cut(COMMONS3NSE, gezichten, TOMORROW, PLENTY);

        (bytes32 node, string[] memory back, uint64 endDate, uint64 ink) = munt.read(number);
        require(node == COMMONS3NSE, "the Stempel is the name");
        require(back.length == 2, "two gezichten");
        require(same(back[0], "beer"), "beer");
        require(same(back[1], "coat"), "coat");
        require(endDate == TOMORROW, "end-date");
        require(ink == PLENTY, "ink");
    }

    function test_every_strike_uses_one_ink_and_an_empty_stempel_refuses() external {
        string[] memory gezichten = new string[](1);
        gezichten[0] = "beer";
        uint256 stempel = munt.cut(COMMONS3NSE, gezichten, TOMORROW, 2);

        munt.strike(stempel, 0, keccak256("first"));
        (,,, uint64 ink) = munt.read(stempel);
        require(ink == 1, "one ink left");

        munt.strike(stempel, 0, keccak256("second"));
        (,,, ink) = munt.read(stempel);
        require(ink == 0, "no ink left");

        (bool ok,) = address(munt).call(abi.encodeCall(Muntje.strike, (stempel, 0, keccak256("third"))));
        require(!ok, "out of ink");
    }

    function test_a_stempel_past_its_end_date_refuses() external {
        string[] memory gezichten = new string[](1);
        gezichten[0] = "beer";
        // Without forge-std there is no warp, so the end-date is already behind us.
        uint256 stempel = munt.cut(COMMONS3NSE, gezichten, uint64(block.timestamp), PLENTY);

        (bool ok,) = address(munt).call(abi.encodeCall(Muntje.strike, (stempel, 0, keccak256("too late"))));
        require(!ok, "past its end-date");
    }

    function test_the_name_owner_strikes_a_coin_and_it_reads_back_unspent() external {
        string[] memory gezichten = new string[](2);
        gezichten[0] = "beer";
        gezichten[1] = "coat";
        uint256 stempel = munt.cut(COMMONS3NSE, gezichten, TOMORROW, PLENTY);

        // The ID stays with the coin (line 32); only its hash reaches here.
        bytes32 hash = keccak256("a random ID that only the paper knows");
        munt.strike(stempel, 0, hash);

        (uint256 s, uint256 g, bool spent) = munt.coin(hash);
        require(s == stempel, "points at its Stempel");
        require(g == 0, "beer");
        require(!spent, "fresh coin is unspent");
    }

    function test_without_the_name_you_can_neither_cut_nor_strike() external {
        string[] memory gezichten = new string[](1);
        gezichten[0] = "beer";
        uint256 stempel = munt.cut(COMMONS3NSE, gezichten, TOMORROW, PLENTY);

        Stranger stranger = new Stranger();
        require(!stranger.tryCut(munt, COMMONS3NSE), "a stranger must not cut as a name it does not control");
        require(!stranger.tryStrike(munt, stempel, keccak256("another ID")), "nor strike from it");
    }

    function test_the_press_follows_the_name() external {
        string[] memory gezichten = new string[](1);
        gezichten[0] = "beer";
        uint256 stempel = munt.cut(COMMONS3NSE, gezichten, TOMORROW, PLENTY);

        // The name changes hands. The old owner is now the stranger.
        Stranger buyer = new Stranger();
        ens.set(COMMONS3NSE, address(buyer));

        require(buyer.tryStrike(munt, stempel, keccak256("struck by the new owner")), "the new owner strikes");
        (bool ok,) = address(munt).call(abi.encodeCall(Muntje.strike, (stempel, 0, keccak256("struck by the old owner"))));
        require(!ok, "the old owner no longer can");
    }

    function same(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

/// Someone who does not control the name. Without forge-std there is no
/// prank, so a second contract is the second caller.
contract Stranger {
    function tryCut(Muntje munt, bytes32 node) external returns (bool ok) {
        string[] memory gezichten = new string[](1);
        gezichten[0] = "beer";
        (ok,) = address(munt).call(abi.encodeCall(Muntje.cut, (node, gezichten, uint64(block.timestamp + 1 days), 1000)));
    }

    function tryStrike(Muntje munt, uint256 stempel, bytes32 hash) external returns (bool ok) {
        (ok,) = address(munt).call(abi.encodeCall(Muntje.strike, (stempel, 0, hash)));
    }
}
