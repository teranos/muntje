// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IENS, Muntje} from "../src/Muntje.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// Deploy against the ENSv2 ETHRegistry on Sepolia, the registry that
/// answers for .eth names there today. No Stempel is cut here: that is the
/// Munt's own act, from the console, as its name (stone, lines 37, 70).
contract DeploySepolia {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IENS private constant ENS = IENS(0xBDC85dD5b15D7ecb354cd7cb6f2c50b4f2c4F0E2);

    event Deployed(address munt);

    function run() external {
        vm.startBroadcast();
        Muntje munt = new Muntje(ENS);
        vm.stopBroadcast();
        emit Deployed(address(munt));
    }
}
