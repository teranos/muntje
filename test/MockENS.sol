// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IENS} from "../src/Muntje.sol";

/// Answers owner(node) from a table. The real registry does the same thing
/// with a much longer history. Used by the tests and by the Anvil deploy,
/// because Anvil has no ENS.
contract MockENS is IENS {
    mapping(bytes32 => address) private owners;

    function set(bytes32 node, address who) external {
        owners[node] = who;
    }

    function owner(bytes32 node) external view returns (address) {
        return owners[node];
    }
}
