// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/week04/MemeFactory/MemeToken.sol";
import "src/week04/MemeFactory/MemeFactory.sol";

contract MemeFactoryTest is Test {
    MemeToken public logic;
    MemeFactory public factory;

    address public deployer = vm.addr(1);
    address public user = vm.addr(12);
    address public platform = vm.addr(123);

    function setUp() public {
        vm.deal(deployer, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(platform, 0);

        // 部署 MemeToken 逻辑合约
        logic = new MemeToken();

        // 部署 MemeFactory
        vm.prank(deployer);
        factory = new MemeFactory(address(logic), payable(platform));
    }

    function testDeployAndMint() public {
        // 参数
        string memory symbol = "WOW";
        uint256 totalSupply = 1000 ether;
        uint256 perMint = 100 ether;
        uint256 price = 1 ether;

        // 部署一个 MemeToken 合约实例
        vm.prank(deployer);
        address meme = factory.deployInscription(symbol, totalSupply, perMint, price);

        // 校验工厂记录
        assertTrue(factory.isMemeToken(meme));
        assertEq(factory.memeTokenToOwner(meme), deployer);

        // 用户进行 mint
        uint256 beforeIssuer = deployer.balance;
        uint256 beforePlatform = platform.balance;

        vm.prank(user);
        vm.deal(user, 10 ether);
        factory.mintInscription{value: 1 ether}(meme);

        // 验证 token 数量
        uint256 balance = ERC20(meme).balanceOf(user);
        assertEq(balance, perMint);

        // 验证发行者和平台收到的金额
        uint256 fee = price / 100;
        uint256 issuerAmt = price - fee;
        assertEq(platform.balance, beforePlatform + fee);
        assertEq(deployer.balance, beforeIssuer + issuerAmt);
    }

    function testMintExceedsMaxSupply() public {
        string memory symbol = "LUL";
        uint256 totalSupply = 100 ether;
        uint256 perMint = 100 ether;
        uint256 price = 1 ether;

        vm.prank(deployer);
        address meme = factory.deployInscription(symbol, totalSupply, perMint, price);

        // // 第一次 mint 正常
        vm.prank(user);
        factory.mintInscription{value: 1 ether}(meme);

        // 第二次 mint 超过 totalSupply，应该 revert
        vm.prank(user);
        vm.expectRevert(MemeToken.ExceedsMaxSupply.selector);
        factory.mintInscription{value: 1 ether}(meme);
    }

    function testMintWrongPriceFails() public {
        string memory symbol = "LOL";
        uint256 totalSupply = 500 ether;
        uint256 perMint = 50 ether;
        uint256 price = 2 ether;

        vm.prank(deployer);
        address meme = factory.deployInscription(symbol, totalSupply, perMint, price);

        // 用户发送错误的价格
        vm.prank(user);
        vm.expectRevert("Incorrect ETH");
        factory.mintInscription{value: 1 ether}(meme);
    }
}
