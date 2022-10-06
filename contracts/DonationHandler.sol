// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./DonationHandlerRoles.sol";

contract DonationHandler is DonationHandlerRoles {
    // 1e18 represents 100%, 1e16 represents 1%
    uint256 public constant HUNDRED = 1e18;

    // user => token => amount
    mapping(address => mapping(address => uint256)) public balances;

    function initialize(
        address[] calldata _acceptedToken,
        address[] calldata _donationReceiver,
        address[] calldata _feeReceiver,
        address[] calldata _admins
    ) public initializer {
        __DonationHandlerRoles_init(
            _acceptedToken,
            _donationReceiver,
            _feeReceiver,
            _admins
        );
    }

    function donateWithFee(
        address _token,
        address _recipient,
        uint256 _amount,
        uint256 _fee
    ) external {
        if (_fee > HUNDRED) revert FeeTooHigh();

        _validateDonation(_token, _recipient);
        _transfer(_token, _amount);

        if (_fee == 0) {
            _registerDonation(_token, _recipient, _amount);
        } else if (_fee == HUNDRED) {
            _registerFee(_token, _amount);
        } else {
            uint256 feeAmount = (_amount * _fee) / HUNDRED;
            uint256 donationAmount = _amount - feeAmount;

            _registerDonation(_token, _recipient, donationAmount);
            _registerFee(_token, feeAmount);
        }
    }

    function donate(
        address _token,
        address _recipient,
        uint256 _amount
    ) external {
        _validateDonation(_token, _recipient);
        _transfer(_token, _amount);
        _registerDonation(_token, _recipient, _amount);
    }

    function _registerFee(address _token, uint256 _amount) internal {
        balances[address(this)][_token] += _amount;
        emit FeeRegistered(_token, _amount);
    }

    function _registerDonation(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        balances[_recipient][_token] += _amount;
        emit DonationRegistered(_token, _recipient, _amount);
    }

    function _validateDonation(address _token, address _recipient)
        internal
        view
    {
        _checkToken(_token);
        _checkDonationRecipient(_recipient);
    }

    function _transfer(address _token, uint256 _amount) internal {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(address[] calldata _token) external {
        _withdraw(_token, msg.sender, msg.sender);
    }

    function distribute(address[] calldata _token, address _to) external {
        // TODO: maybe restrict to admins
        _withdraw(_token, _to, _to);
    }

    function withdrawFee(address[] calldata _token) external {
        _checkFeeReceiver(msg.sender);
        _withdraw(_token, address(this), msg.sender);
    }

    function _withdraw(
        address[] calldata _token,
        address _from,
        address _to
    ) internal {
        uint256 length = _token.length;

        for (uint256 i = 0; i < length; ) {
            uint256 amount = balances[_from][_token[i]];
            balances[_from][_token[i]] = 0;

            if (amount > 0) {
                IERC20(_token[i]).transfer(_to, amount);
                emit Withdraw(_token[i], amount, _from, _to);
            }

            unchecked {
                i++;
            }
        }
    }

    error FeeTooHigh();

    event FeeRegistered(address indexed token, uint256 amount);
    event DonationRegistered(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event Withdraw(
        address indexed token,
        uint256 amount,
        address indexed from,
        address indexed to
    );
}
