// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;
import "../interfaces/IERC20.sol";

import "../libraries/LibERC20.sol";

contract ERC20Faucet is IERC20 {
    LibERC20.ERC20State internal s;

    function init() external {
        s.name = "Signor Token";
        s.symbol = "STK";
        s.decimal = uint8(18);
        s.totalSupply = 1000 * 10 ** uint(s.decimal);
    }

    function totalSupply() external view returns (uint256) {
        return s.totalSupply;
    }

    function decimals() external view returns (uint8) {
        return s.decimal;
    }

    function name() external view returns (string memory) {
        return s.name;
    }

    function symbol() external view returns (string memory) {
        return s.symbol;
    }

    function balanceOf(address _address) external view returns (uint256) {
        return s.balanceOf[_address];
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return s.allowance[owner][spender];
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        require(_amount <= s.balanceOf[msg.sender], "insufficient funds");
        updateBalance(_amount, msg.sender, _to);

        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function approve(address spender, uint256 _value) external returns (bool) {
        s.allowance[msg.sender][spender] = _value;
        emit Approval(msg.sender, spender, _value);
        return true;
    }

    function transferFrom(
        address _owner,
        address _recipent,
        uint _numToken
    ) external returns (bool) {
        require(_numToken <= s.balanceOf[_owner], "Insufficient balance");
        require(
            _numToken <= s.allowance[_owner][msg.sender],
            "Insufficient allowance"
        );
        s.allowance[_owner][msg.sender] -= _numToken;
        updateBalance(_numToken, _owner, _recipent);
        emit Transfer(_owner, _recipent, _numToken);
        return true;
    }

    function updateBalance(
        uint256 amount,
        address debitAccount,
        address creditAccount
    ) private {
        // Calculate 10% burn amount
        uint256 burnAmount = (amount * 10) / 100;

        // Update balances and total supply
        s.balanceOf[debitAccount] -= amount + burnAmount;
        s.balanceOf[creditAccount] += amount;
        s.totalSupply -= burnAmount;
    }
}
