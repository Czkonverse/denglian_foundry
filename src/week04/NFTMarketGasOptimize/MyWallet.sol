// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyWallet {
    string public name;
    mapping(address => bool) private approved;
    address public owner; // slot 2

    modifier auth() {
        address currentOwner;
        assembly {
            currentOwner := sload(2)
        }
        require(msg.sender == currentOwner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;

        assembly {
            sstore(2, caller()) // slot 2 存储 owner
        }
    }

    function transferOwnership(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");

        address currentOwner;
        assembly {
            currentOwner := sload(2)
        }

        require(_addr != currentOwner, "New owner is the same as the old owner");

        assembly {
            sstore(2, _addr)
        }
    }
}
