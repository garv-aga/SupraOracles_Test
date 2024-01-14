// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Token Swap
 * @author Garv
 * Create a smart contract that facilitates the swapping of one ERC-20 token for another at a predefined exchange rate. The smart contract should include the following features:
 *     ● Users can swap Token A for Token B and vice versa.
 *     ● The exchange rate between Token A and Token B is fixed.
 *     ● Implement proper checks to ensure that the swap adheres to the exchange rate.
 *     ● Include events to log swap details.
 */
contract TokenSwap is ReentrancyGuard {
    address public owner;
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public exchangeRate;

    event Swap(address indexed sender, uint256 amountA, uint256 amountB);

    constructor(address _tokenA, address _tokenB, uint256 _exchangeRate) {
        owner = msg.sender;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        exchangeRate = _exchangeRate;
    }

    /**
     * @dev Performs swap of A tokens for B Tokens
     * @param amountA Amount of token A to swap
     */
    function swapAToB(uint256 amountA) external nonReentrant {
        uint256 amountB = amountA * exchangeRate;
        require(tokenA.balanceOf(msg.sender) >= amountA, "Insufficient balance of Token A");
        require(tokenB.balanceOf(address(this)) >= amountB, "Not enough Token B in the contract");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transfer(msg.sender, amountB);

        emit Swap(msg.sender, amountA, amountB);
    }

    /**
     * @dev Performs swap of B tokens for A Tokens
     * @param amountB Amount of token B to swap
     */
    function swapBToA(uint256 amountB) external nonReentrant {
        uint256 amountA = amountB / exchangeRate;
        require(tokenB.balanceOf(msg.sender) >= amountB, "Insufficient balance of Token B");
        require(tokenA.balanceOf(address(this)) >= amountA, "Not enough Token A in the contract");

        tokenB.transferFrom(msg.sender, address(this), amountB);
        tokenA.transfer(msg.sender, amountA);

        emit Swap(msg.sender, amountA, amountB);
    }
}
