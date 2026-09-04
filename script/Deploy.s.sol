// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IENS, Muntje} from "../src/Muntje.sol";
import {MockENS} from "../test/MockENS.sol";

/// The two cheatcodes a deploy needs. Declared here rather than pulling in
/// forge-std for them.
interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// Deploy to Anvil: a mock ENS that says the broadcaster owns commons3nse.eth,
/// the Munt, and one Stempel cut from that name with two gezichten, a day of
/// time and a hundred ink. Prints what vrijemunt needs in its config.
contract Deploy {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string private constant COMMONS3NSE = "commons3nse";

    event Deployed(address ens, address munt, uint256 stempel);

    function run() external {
        vm.startBroadcast();

        MockENS ens = new MockENS();
        ens.set(COMMONS3NSE, msg.sender);
        Muntje munt = new Muntje(IENS(address(ens)));

        string[] memory gezichten = new string[](2);
        gezichten[0] = "beer";
        gezichten[1] = "coat";
        uint256 stempel = munt.cut(COMMONS3NSE, gezichten, uint64(block.timestamp + 1 days), 100);

        vm.stopBroadcast();

        emit Deployed(address(ens), address(munt), stempel);
    }
}
