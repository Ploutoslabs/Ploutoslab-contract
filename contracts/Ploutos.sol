// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ploutos is ERC20Capped, ReentrancyGuard, Ownable {
    struct Allocation {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 nextClaimTime;
    }

    uint256 public constant maxSupply = 21000046153 * 10 ** 7;
    uint256 public constant AIRDROP_AMOUNT = 30 * 10 ** 9; // PLTL has 9 decimals
    uint256 public constant IMMEDIATE_AIRDROP = 3 * 10 ** 8; // 0.3 PLTL
    uint256 public constant FEE = 0.0002 ether;
    uint256 public constant DAY30 = 30 days;
    uint256 public presaleRate; // PLTL per ETH
    bool public presaleActive = true;

    address public feeReceiver;
    address public admin;

    mapping(address => Allocation[]) public allocations;

    event AirdropClaimed(address indexed user, uint256 amount);
    event PresalePurchased(address indexed user, uint256 amount);
    event AllocationClaimed(address indexed user, uint256 amount);
    event PresaleRateChanged(uint256 newRate);
    event PresaleStatusChanged(bool isActive);
    event AllocationIncreased(address indexed user, uint256 amount);

    constructor(
        address _admin,
        address _feeReceiver
    ) ERC20("PLOUTOS", "PLTL") ERC20Capped(maxSupply) Ownable(msg.sender) {
        require(_feeReceiver != address(0), "Invalid fee receiver address");
        admin = _admin;
        feeReceiver = _feeReceiver;
        _mint(_feeReceiver, 11000046153 * 10 ** 7); // Mint 110000461.53 tokens to admin
    }

    function airdrop() external payable nonReentrant {
        require(msg.value == FEE, "Incorrect fee");
        require(allocations[msg.sender].length == 0, "NOT ALLOWED");
        payable(feeReceiver).transfer(msg.value);

        Allocation memory newAllocation = Allocation({
            totalAmount: AIRDROP_AMOUNT,
            claimedAmount: IMMEDIATE_AIRDROP,
            nextClaimTime: block.timestamp + DAY30
        });

        allocations[msg.sender].push(newAllocation);
        _mint(msg.sender, IMMEDIATE_AIRDROP);

        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT);
        emit AllocationClaimed(msg.sender, IMMEDIATE_AIRDROP);
    }

    function buyPresale() external payable nonReentrant {
        require(presaleActive, "Presale is not active");
        require(presaleRate > 0, "Presale is not set");
        uint256 amount = (msg.value * presaleRate) / (1 ether);
        uint256 immediateAmount = amount / 100;
        payable(admin).transfer(msg.value);

        allocations[msg.sender].push(
            Allocation({
                totalAmount: amount,
                claimedAmount: immediateAmount,
                nextClaimTime: block.timestamp + DAY30
            })
        );

        _mint(msg.sender, immediateAmount);
        emit PresalePurchased(msg.sender, amount);
    }

    function claimAllocation(uint index) external nonReentrant {
        require(index < allocations[msg.sender].length, "Invalid index");
        Allocation storage allocation = allocations[msg.sender][index];
        require(
            block.timestamp >= allocation.nextClaimTime,
            "Claim not yet available"
        );

        uint256 periodsElapsed = 1 +
            ((block.timestamp - allocation.nextClaimTime) / DAY30);
        if (periodsElapsed > 0) {
            // Calculate the claimable amount based on the periods elapsed
            uint256 claimable = (allocation.totalAmount * periodsElapsed) / 100;
            if (
                claimable > (allocation.totalAmount - allocation.claimedAmount)
            ) {
                claimable = allocation.totalAmount - allocation.claimedAmount;
            }
            require(claimable > 0, "No claimable amount");

            allocation.claimedAmount += claimable;

            // Update the next claim time by adding the elapsed time (periods * DAY30)
            allocation.nextClaimTime += periodsElapsed * DAY30;

            _mint(msg.sender, claimable);
            emit AllocationClaimed(msg.sender, claimable);
        } else {
            revert("No elapsed periods");
        }
    }

    function setPresaleRate(uint256 _rate) external {
        require(msg.sender == admin || msg.sender == owner(), "ACCESS DENIED");
        presaleRate = _rate;
        emit PresaleRateChanged(_rate);
    }

    function startStopPresale(bool _status) external {
        require(msg.sender == admin || msg.sender == owner(), "ACCESS DENIED");
        presaleActive = _status;
        emit PresaleStatusChanged(_status);
    }

    function giveAllocation(address user, uint256 amount) external {
        require(msg.sender == admin || msg.sender == owner(), "ACCESS DENIED");

        Allocation memory newAllocation = Allocation({
            totalAmount: amount,
            claimedAmount: 0,
            nextClaimTime: block.timestamp
        });

        allocations[user].push(newAllocation);

        emit AllocationIncreased(user, amount);
    }

    function allocationLen(address user) external view returns (uint256) {
        return allocations[user].length;
    }

    function allocationInfo(
        address user,
        uint256 index
    )
        external
        view
        returns (
            uint256 totalAmount,
            uint256 claimedAmount,
            uint256 nextClaimTime
        )
    {
        totalAmount = allocations[user][index].totalAmount;
        claimedAmount = allocations[user][index].claimedAmount;
        nextClaimTime = allocations[user][index].nextClaimTime;
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function totalSupply() public pure override returns (uint256) {
        return maxSupply;
    }

    function circlatingSupply() public view returns (uint256) {
        return super.totalSupply();
    }
}
