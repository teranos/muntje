// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IENS} from "../src/Muntje.sol";

/// Answers findOwner(label) from a table. The real ENSv2 registry does the
/// same thing with a much longer history. Used by the tests and by the
/// Anvil deploy, because Anvil has no ENS.
contract MockENS is IENS {
    mapping(string => address) private owners;

    function set(string calldata label, address who) external {
        owners[label] = who;
    }

    function findOwner(string calldata label) external view returns (address) {
        return owners[label];
    }
}
