// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Import our contracts
import "./NFTMarketUpgradeable.sol";
import "./NFTMarketUpgradeableV2.sol";

// Mock contracts for testing
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1M tokens
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock ERC721 token for testing
contract MockERC721 is ERC721 {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }

    function safeMint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}

contract NFTMarketUpgradeableTest is Test {
    // Contract instances
    NFTMarketUpgradeable public marketV1;
    NFTMarketUpgradeableV2 public marketV2;
    MockERC20 public paymentToken;
    MockERC721 public nftContract;

    // Test addresses
    address public owner;
    address public seller;
    address public buyer;
    address public randomUser;

    // Proxy address
    address public proxyAddress;

    // Events
    event Upgraded(address indexed implementation);

    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        randomUser = makeAddr("randomUser");

        // Deploy mock contracts
        vm.startPrank(owner);
        paymentToken = new MockERC20("Test Token", "TEST");
        nftContract = new MockERC721("Test NFT", "TNFT");
        vm.stopPrank();

        // Give tokens to buyer and seller
        paymentToken.mint(buyer, 1000 * 10 ** 18);
        paymentToken.mint(seller, 1000 * 10 ** 18);

        // Mint NFTs to seller
        vm.prank(seller);
        nftContract.safeMint(seller);

        console.log("=== Setup Complete ===");
        console.log("Owner:", owner);
        console.log("Seller:", seller);
        console.log("Buyer:", buyer);
        console.log("Payment Token:", address(paymentToken));
        console.log("NFT Contract:", address(nftContract));
    }

    function test_DeployV1Contract() public {
        console.log("\n=== Testing V1 Deployment ===");

        // Deploy V1 implementation
        NFTMarketUpgradeable implementation = new NFTMarketUpgradeable();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(NFTMarketUpgradeable.initialize.selector, owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        proxyAddress = address(proxy);

        // Get proxy as V1 contract
        marketV1 = NFTMarketUpgradeable(proxyAddress);

        // Verify initialization
        assertEq(marketV1.owner(), owner);
        assertEq(marketV1.version(), "1.0.0");

        console.log("Proxy Address:", proxyAddress);
        console.log("Implementation:", marketV1.getImplementation());
        console.log("Version:", marketV1.version());
        console.log("Owner:", marketV1.owner());
    }

    function test_V1BasicFunctionality() public {
        // First deploy V1
        test_DeployV1Contract();

        console.log("\n=== Testing V1 Basic Functionality ===");

        uint256 tokenId = 0;
        uint256 price = 100 * 10 ** 18; // 100 tokens

        // Seller approves market contract
        vm.prank(seller);
        nftContract.approve(proxyAddress, tokenId);

        // List item
        vm.prank(seller);
        marketV1.listItem(address(nftContract), tokenId, address(paymentToken), price);

        // Verify listing
        (address listingSeller, address listingNft, address listingToken, uint256 listingPrice) =
            marketV1.listings(address(nftContract), tokenId);

        assertEq(listingSeller, seller);
        assertEq(listingNft, address(nftContract));
        assertEq(listingToken, address(paymentToken));
        assertEq(listingPrice, price);

        console.log("V1 listing functionality works");
        console.log("Listed NFT:", listingNft);
        console.log("Token ID:", tokenId);
        console.log("Price:", listingPrice);
    }

    function test_UpgradeToV2() public {
        // First deploy and test V1
        test_V1BasicFunctionality();

        console.log("\n=== Testing Upgrade to V2 ===");

        // Record V1 state before upgrade
        string memory versionBeforeUpgrade = marketV1.version();
        address implementationBeforeUpgrade = marketV1.getImplementation();
        address ownerBeforeUpgrade = marketV1.owner();

        // Check existing listing
        (address listingSeller,,, uint256 listingPrice) = marketV1.listings(address(nftContract), 0);

        console.log("Before Upgrade:");
        console.log("- Version:", versionBeforeUpgrade);
        console.log("- Implementation:", implementationBeforeUpgrade);
        console.log("- Owner:", ownerBeforeUpgrade);
        console.log("- Existing listing seller:", listingSeller);
        console.log("- Existing listing price:", listingPrice);

        // Deploy V2 implementation
        NFTMarketUpgradeableV2 newImplementation = new NFTMarketUpgradeableV2();

        // Perform upgrade (only owner can upgrade)
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImplementation));
        marketV1.upgradeToAndCall(address(newImplementation), "");

        // Get proxy as V2 contract
        marketV2 = NFTMarketUpgradeableV2(proxyAddress);

        // Verify upgrade
        string memory versionAfterUpgrade = marketV2.version();
        address implementationAfterUpgrade = marketV2.getImplementation();
        address ownerAfterUpgrade = marketV2.owner();

        console.log("\nAfter Upgrade:");
        console.log("- Version:", versionAfterUpgrade);
        console.log("- Implementation:", implementationAfterUpgrade);
        console.log("- Owner:", ownerAfterUpgrade);

        // Verify state preservation
        assertEq(ownerAfterUpgrade, ownerBeforeUpgrade, "Owner should be preserved");
        assertEq(versionAfterUpgrade, "2.0.0", "Version should be updated to 2.0.0");
        assertTrue(implementationAfterUpgrade != implementationBeforeUpgrade, "Implementation should change");

        // Verify existing listing is preserved
        (address preservedSeller,,, uint256 preservedPrice) = marketV2.listings(address(nftContract), 0);
        assertEq(preservedSeller, listingSeller, "Existing listing seller should be preserved");
        assertEq(preservedPrice, listingPrice, "Existing listing price should be preserved");

        console.log("Upgrade successful!");
        console.log("State preserved!");
        console.log("- Preserved listing seller:", preservedSeller);
        console.log("- Preserved listing price:", preservedPrice);
    }

    function test_V2NewFunctionality() public {
        // First upgrade to V2
        test_UpgradeToV2();

        console.log("\n=== Testing V2 New Functionality ===");

        uint256 newTokenId = 1;

        // Mint a new NFT for testing V2 features
        vm.prank(seller);
        nftContract.safeMint(seller);

        // Test new V2 functions
        uint256 sellerNonce = marketV2.getSellerNonce(seller, address(nftContract));
        console.log("Initial seller nonce:", sellerNonce);
        assertEq(sellerNonce, 0, "Initial nonce should be 0");

        // Test signature hash generation
        uint256 price = 200 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 signatureHash = marketV2.getListingSignatureHash(
            seller, address(nftContract), newTokenId, address(paymentToken), price, deadline
        );

        console.log("Generated signature hash:");
        console.logBytes32(signatureHash);

        assertFalse(marketV2.isSignatureUsed(signatureHash), "Signature should not be used initially");

        console.log("V2 new functions work correctly");
    }

    function test_V1FunctionalityStillWorksAfterUpgrade() public {
        // Upgrade to V2
        test_UpgradeToV2();

        console.log("\n=== Testing V1 Functionality Still Works After Upgrade ===");

        // Mint new NFT for testing
        vm.prank(seller);
        uint256 newTokenId = nftContract.safeMint(seller);

        uint256 price = 150 * 10 ** 18;

        // Approve the new NFT
        vm.prank(seller);
        nftContract.approve(proxyAddress, newTokenId);

        // Test V1 listing function still works
        vm.prank(seller);
        marketV2.listItem(address(nftContract), newTokenId, address(paymentToken), price);

        // Verify listing
        (address listingSeller, address listingNft, address listingToken, uint256 listingPrice) =
            marketV2.listings(address(nftContract), newTokenId);

        assertEq(listingSeller, seller);
        assertEq(listingNft, address(nftContract));
        assertEq(listingToken, address(paymentToken));
        assertEq(listingPrice, price);

        console.log("V1 functionality preserved after upgrade");
    }

    function test_OnlyOwnerCanUpgrade() public {
        // Deploy V1 first
        test_DeployV1Contract();

        console.log("\n=== Testing Upgrade Authorization ===");

        // Deploy V2 implementation
        NFTMarketUpgradeableV2 newImplementation = new NFTMarketUpgradeableV2();

        // Try to upgrade from non-owner (should fail)
        vm.prank(randomUser);
        vm.expectRevert(); // Should revert with Ownable error
        marketV1.upgradeToAndCall(address(newImplementation), "");

        console.log("Non-owner cannot upgrade");

        // Owner can upgrade (should succeed)
        vm.prank(owner);
        marketV1.upgradeToAndCall(address(newImplementation), "");

        console.log("Owner can upgrade");
    }

    function test_UpgradePreservesProxyAddress() public {
        // Deploy V1
        test_DeployV1Contract();

        address proxyAddressBefore = proxyAddress;

        // Upgrade to V2
        NFTMarketUpgradeableV2 newImplementation = new NFTMarketUpgradeableV2();
        vm.prank(owner);
        marketV1.upgradeToAndCall(address(newImplementation), "");

        // Verify proxy address hasn't changed
        address proxyAddressAfter = address(marketV1); // Same proxy, different implementation

        assertEq(proxyAddressBefore, proxyAddressAfter, "Proxy address should remain the same");

        console.log("Proxy address preserved during upgrade");
        console.log("Proxy address:", proxyAddressAfter);
    }

    function test_CompleteUpgradeFlow() public {
        console.log("\n=== Complete Upgrade Flow Test ===");

        // 1. Deploy V1
        test_DeployV1Contract();
        console.log("1. V1 deployed");

        // 2. Use V1 functionality
        test_V1BasicFunctionality();
        console.log("2. V1 functionality tested");

        // 3. Upgrade to V2
        test_UpgradeToV2();
        console.log("3. Upgraded to V2");

        // 4. Test V2 new functionality
        test_V2NewFunctionality();
        console.log("4. V2 new functionality tested");

        // 5. Verify V1 functionality still works
        test_V1FunctionalityStillWorksAfterUpgrade();
        console.log("5. V1 functionality preserved");
    }
}
