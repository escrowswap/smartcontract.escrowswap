// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/escrowswap_v1.0.sol";

contract EscrowswapV1Test is Test {
    EscrowswapV1 public escrowswap;

    function setUp() public {
        escrowswap = new EscrowswapV1();
    }

    /*
     function testIncrement() public {
        escrowswap.increment();
        assertEq(counter.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    } */
}
