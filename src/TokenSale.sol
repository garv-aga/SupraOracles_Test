// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenSale
 * @author Garv
 *
 * Presale:
 *     ● Users can contribute Ether to the presale and receive project tokens in return.
 *     ● The presale has a maximum cap on the total Ether that can be raised.
 *     ● The presale has a minimum and maximum contribution limit per participant.
 *     ● Tokens are distributed immediately upon contribution.
 * Public Sale:
 *     ● After the presale ends, the public sale begins.
 *     ● Users can contribute Ether to the public sale and receive project tokens in return.
 *     ● The public sale has a maximum cap on the total Ether that can be raised.
 *     ● The public sale has a minimum and maximum contribution limit per participant.
 *     ● Tokens are distributed immediately upon contribution.
 * Token Distribution:
 *     ● The smart contract should have a function to distribute project tokens to a specified address. This function can only be called by the owner of the contract.
 * Refund:
 *     ● If the minimum cap for either the presale or public sale is not reached, contributors should be able to claim a refund.
 */
contract TokenSale is ReentrancyGuard {
    using Math for uint256;

    address public owner;
    address public token;
    uint256 rate;
    uint256 preWeiRaised = 0;
    uint256 pubWeiRaised = 0;
    uint256 public PRE_MAX_CAP;
    uint256 public PRE_MAX_CONTRIBUTION;
    uint256 public PRE_MIN_CAP;
    uint256 public PRE_MIN_CONTRIBUTION;
    uint256 public PRE_OPEN_TIME;
    uint256 public PRE_CLOSE_TIME;
    uint256 public PUB_MAX_CAP;
    uint256 public PUB_MAX_CONTRIBUTION;
    uint256 public PUB_MIN_CAP;
    uint256 public PUB_MIN_CONTRIBUTION;
    uint256 public PUB_OPEN_TIME;
    uint256 public PUB_CLOSE_TIME;

    mapping(address buyer => uint256 weiAmount) presaleBalances;
    mapping(address buyer => uint256 weiAmount) publicSaleBalances;

    event PresaleRefund(address indexed buyer, uint256 indexed amount);
    event PublicSaleRefund(address indexed buyer, uint256 indexed amount);

    constructor(
        address _token,
        uint256 _rate,
        uint256 _preMaxCap,
        uint256 _preMaxContri,
        uint256 _preMinCap,
        uint256 _preMinContri,
        uint256 _pubMaxCap,
        uint256 _pubMaxContri,
        uint256 _pubMinCap,
        uint256 _pubMinContri,
        uint256 _preOpenTime,
        uint256 _preCloseTime,
        uint256 _pubOpenTime,
        uint256 _pubCloseTime
    ) {
        require(PRE_OPEN_TIME >= block.timestamp, "Presale opens after contract deployment");
        require(PRE_CLOSE_TIME > PRE_OPEN_TIME, "Presale should close after opening");
        require(PUB_OPEN_TIME > PRE_CLOSE_TIME, "Public sale should open after presale closes");
        require(PUB_CLOSE_TIME > PUB_OPEN_TIME, "Public sale should close after opening");
        token = _token;
        PRE_OPEN_TIME = _preOpenTime;
        PRE_CLOSE_TIME = _preCloseTime;
        PUB_OPEN_TIME = _pubOpenTime;
        PUB_CLOSE_TIME = _pubCloseTime;
        owner = msg.sender;
        rate = _rate;
        PRE_MAX_CAP = _preMaxCap;
        PRE_MAX_CONTRIBUTION = _preMaxContri;
        PRE_MIN_CAP = _preMinCap;
        PRE_MIN_CONTRIBUTION = _preMinContri;
        PUB_MAX_CAP = _pubMaxCap;
        PUB_MAX_CONTRIBUTION = _pubMaxContri;
        PUB_MIN_CAP = _pubMinCap;
        PUB_MIN_CONTRIBUTION = _pubMinContri;
    }

    modifier validatePrePurchase(uint256 _weiAmount) {
        require(block.timestamp >= PRE_OPEN_TIME, "Presale should be open");
        require(block.timestamp <= PRE_CLOSE_TIME, "Presale should not have closed");
        require(_weiAmount >= PRE_MIN_CONTRIBUTION, "Contribution amount should be greater than minimum");
        require(_weiAmount <= PRE_MAX_CONTRIBUTION, "Contribution amount should be less than maximum");
        (bool s, uint256 result) = preWeiRaised.tryAdd(_weiAmount);
        require(s, "Presale purchase Overflow");
        require(result <= PRE_MAX_CAP, "Presale maximum cap reached");
        _;
    }

    modifier validatePublicPurchase(uint256 _weiAmount) {
        require(block.timestamp >= PUB_OPEN_TIME, "Public sale should be open");
        require(block.timestamp <= PUB_CLOSE_TIME, "Public sale should not have closed");
        require(_weiAmount >= PUB_MIN_CONTRIBUTION, "Contribution amount should be greater than minimum");
        require(_weiAmount <= PUB_MAX_CONTRIBUTION, "Contribution amount should be less than maximum");
        (bool s, uint256 result) = pubWeiRaised.tryAdd(_weiAmount);
        require(s, "Public sale purchase Overflow");
        require(result <= PUB_MAX_CAP, "Public sale maximum cap reached");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    /**
     * @dev Presale of token in exchange of ETH deposited at a given rate
     */
    function preSale() public payable validatePrePurchase(msg.value) nonReentrant {
        uint256 weiAmount = msg.value;
        uint256 tokenAmount = _getTokenAmount(weiAmount);
        (bool s, uint256 result) = preWeiRaised.tryAdd(weiAmount);
        require(s);
        presaleBalances[msg.sender] = result;

        IERC20(token).transferFrom(owner, msg.sender, tokenAmount);
    }

    /**
     * @dev Pubic sale of token in exchange of ETH deposited at a given rate after presale has ended
     */
    function publicSale() public payable validatePublicPurchase(msg.value) nonReentrant {
        uint256 weiAmount = msg.value;
        uint256 tokenAmount = _getTokenAmount(weiAmount);
        (bool s, uint256 result) = pubWeiRaised.tryAdd(weiAmount);
        require(s);
        publicSaleBalances[msg.sender] = result;

        IERC20(token).transferFrom(owner, msg.sender, tokenAmount);
    }

    /**
     * @dev Presale refund of tokens if minimum cap was not reached
     */
    function presaleRefund() public payable nonReentrant {
        require(block.timestamp > PRE_CLOSE_TIME, "Presale not yet closed");
        require(preWeiRaised < PRE_MIN_CAP, "Raised amount greater than minimum cap");
        uint256 weiAmount = presaleBalances[msg.sender];

        payable(msg.sender).transfer(weiAmount);
        emit PresaleRefund(msg.sender, weiAmount);
    }

    /**
     * @dev Public sale refund of tokens if minimum cap was not reached
     */
    function publicSaleRefund() public payable nonReentrant {
        require(block.timestamp > PUB_CLOSE_TIME, "Public sale not yet closed");
        require(pubWeiRaised < PUB_MIN_CAP, "Raised amount greater than minimum cap");
        uint256 weiAmount = publicSaleBalances[msg.sender];

        payable(msg.sender).transfer(weiAmount);
        emit PublicSaleRefund(msg.sender, weiAmount);
    }

    /**
     * @dev Distributes tokens to a specific address
     * @param _beneficiary The address to whom the token is sent
     * @param _amount The amount of tokens to be sent
     */
    function distribute(address _beneficiary, uint256 _amount) external payable onlyOwner {
        require(_beneficiary != address(0));

        IERC20(token).transferFrom(owner, _beneficiary, _amount);
    }

    /**
     * @dev Update the exchange rate between ETH and Token
     * @param _rate The rate which has to be set
     */
    function updateRate(uint256 _rate) external onlyOwner {
        rate = _rate;
    }

    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        (bool s, uint256 result) = _weiAmount.tryMul(rate);
        require(s);
        return result;
    }
}
