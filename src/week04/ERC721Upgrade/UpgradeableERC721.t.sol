// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./UpgradeableERC721.sol";
import "./UpgradeableERC721V2.sol";

contract UpgradeableERC721Test is Test {
    UpgradeableERC721 public proxyContract;
    UpgradeableERC721 public implementationV1;
    UpgradeableERC721V2 public implementationV2;
    ERC1967Proxy public proxy;

    address public owner = address(0x1);
    address public user = address(0x2);

    string constant NAME = "TestNFT";
    string constant SYMBOL = "TNFT";

    function setUp() public {
        // 部署V1实现合约
        implementationV1 = new UpgradeableERC721();

        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(UpgradeableERC721.initialize.selector, NAME, SYMBOL, owner);

        // 部署代理合约
        proxy = new ERC1967Proxy(address(implementationV1), initData);

        // 将代理合约转换为UpgradeableERC721接口
        proxyContract = UpgradeableERC721(address(proxy));
    }

    function testInitialState() public view {
        assertEq(proxyContract.name(), NAME);
        assertEq(proxyContract.symbol(), SYMBOL);
        assertEq(proxyContract.owner(), owner);
        assertEq(proxyContract.getNextTokenId(), 1);
    }

    function testMinting() public {
        vm.prank(owner);
        proxyContract.mint(user);

        assertEq(proxyContract.balanceOf(user), 1);
        assertEq(proxyContract.ownerOf(1), user);
        assertEq(proxyContract.getNextTokenId(), 2);
    }

    function testUpgradeToV2() public {
        // 先在V1版本铸造一个NFT
        vm.prank(owner);
        proxyContract.mint(user);

        uint256 tokenIdBeforeUpgrade = proxyContract.getNextTokenId();

        // 部署V2实现合约
        implementationV2 = new UpgradeableERC721V2();

        // 执行升级
        vm.prank(owner);
        proxyContract.upgradeToAndCall(
            address(implementationV2), abi.encodeWithSelector(UpgradeableERC721V2.initializeV2.selector)
        );

        // 将代理合约转换为V2接口
        UpgradeableERC721V2 proxyV2 = UpgradeableERC721V2(address(proxy));

        // 验证升级后状态保持
        assertEq(proxyV2.name(), NAME);
        assertEq(proxyV2.symbol(), SYMBOL);
        assertEq(proxyV2.owner(), owner);
        assertEq(proxyV2.balanceOf(user), 1);
        assertEq(proxyV2.ownerOf(1), user);
        assertEq(proxyV2.getNextTokenId(), tokenIdBeforeUpgrade);

        // 验证新功能
        assertEq(proxyV2.version(), "2.0.0");
    }

    function testV2NewFunctionality() public {
        // 升级到V2
        implementationV2 = new UpgradeableERC721V2();

        vm.prank(owner);
        proxyContract.upgradeToAndCall(
            address(implementationV2), abi.encodeWithSelector(UpgradeableERC721V2.initializeV2.selector)
        );

        UpgradeableERC721V2 proxyV2 = UpgradeableERC721V2(address(proxy));

        // 测试V2的铸造功能仍然正常
        vm.prank(owner);
        proxyV2.mint(user);

        assertEq(proxyV2.balanceOf(user), 1);
        assertEq(proxyV2.ownerOf(1), user);

        // 测试版本功能
        assertEq(proxyV2.version(), "2.0.0");
    }

    function testOnlyOwnerCanUpgrade() public {
        implementationV2 = new UpgradeableERC721V2();

        // 非owner尝试升级应该失败
        vm.prank(user);
        vm.expectRevert();
        proxyContract.upgradeToAndCall(
            address(implementationV2), abi.encodeWithSelector(UpgradeableERC721V2.initializeV2.selector)
        );
    }

    function testOnlyOwnerCanMint() public {
        // 非owner铸造应该失败
        vm.prank(user);
        vm.expectRevert();
        proxyContract.mint(user);
    }
}
