// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBaseERC20 {
    function transfer(
        address _to,
        uint256 _value
    ) external returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 remaining);

    function balanceOf(address _owner) external view returns (uint256 balance);
}

contract TokenBankMultiToken {
    error TokenBankMultiToken__AmountMustBeGreaterThanZero();
    error TokenBankMultiToken__NotEnoughBalance();
    error TokenBankMultiToken__AllowanceTooLow();
    error TokenBankMultiToken__TransferFailed();

    // user => token => amount
    mapping(address => mapping(address => uint256)) public s_deposits;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    function deposit(address _token, uint256 _amount) public {
        // deposit threshold, amount must be greater than 0
        if (_amount == 0) {
            revert TokenBankMultiToken__AmountMustBeGreaterThanZero();
        }
        // check user's token balance
        IBaseERC20 erc20 = IBaseERC20(_token);
        uint256 userBalance = erc20.balanceOf(msg.sender);
        if (userBalance < _amount) {
            revert TokenBankMultiToken__NotEnoughBalance();
        }
        // check the allowance of the token
        uint256 allowance = erc20.allowance(msg.sender, address(this));
        if (allowance < _amount) {
            revert TokenBankMultiToken__AllowanceTooLow();
        }

        // transfer the token from user to this contract
        bool success = erc20.transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert TokenBankMultiToken__TransferFailed();
        }

        // record the amount of deposition
        s_deposits[msg.sender][_token] += _amount;

        emit Deposit(msg.sender, _token, _amount);
    }

    function withdraw(address _token, uint256 _amount) public {
        // withraw threshold, amount must be greater than 0
        if (_amount == 0) {
            revert TokenBankMultiToken__AmountMustBeGreaterThanZero();
        }
        // check the amount of withdraw and deposit
        uint256 depositAmount = s_deposits[msg.sender][_token];
        if (_amount > depositAmount) {
            revert TokenBankMultiToken__NotEnoughBalance();
        }
        // withdraw
        IBaseERC20 erc20 = IBaseERC20(_token);
        bool success = erc20.transfer(msg.sender, _amount);
        if (!success) {
            revert TokenBankMultiToken__TransferFailed();
        }

        // update the records of bank
        s_deposits[msg.sender][_token] -= _amount;

        emit Withdraw(msg.sender, _token, _amount);
    }

    // look up the balance of a user for a specific token
    function getDeposit(
        address _user,
        address _token
    ) public view returns (uint256) {
        return s_deposits[_user][_token];
    }
}
