// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ploutos is ERC20Capped, ReentrancyGuard {
    uint256 public constant maxSupply = 21000046153 * 10 ** 7;

    Distributor public distibutor;

    constructor(
        address _admin
    ) ERC20("PLOUTOS", "PLTL") ERC20Capped(maxSupply) {
        require(_admin != address(0), "Invalid admin address");
        distibutor = new Distributor(address(this), msg.sender, _admin);
        _mint(_admin, 70000000 * 10 ** 9);
        _mint(address(distibutor), 14000046153 * 10 ** 7);
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }
}

contract Distributor is ReentrancyGuard, Ownable {
    struct Allocation {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 nextClaimTime;
    }

    uint256 public constant DAY30 = 30 days;
    uint256 public presaleRate; // PLTL per ETH
    uint256 public unclaimedAllocation;

    bool public presaleActive = true;
    
    address public admin;
    Ploutos public token;

    mapping(address => Allocation[]) public allocations;

    event AirdropClaimed(address indexed user, uint256 amount);
    event PresalePurchased(address indexed user, uint256 amount);
    event AllocationClaimed(address indexed user, uint256 amount);
    event PresaleRateChanged(uint256 newRate);
    event PresaleStatusChanged(bool isActive);
    event AllocationIncreased(address indexed user, uint256 amount);

    modifier isAdministrator() {
        require(msg.sender == admin || msg.sender == owner(), "ACCESS DENIED");
        _;
    }

    constructor(address _token, address _deployer, address _admin) Ownable(_deployer) {
        token = Ploutos(_token);
        admin = _admin;
    }

    function buyPrivateSale() external payable nonReentrant {
        require(presaleActive, "Private sale is not active");
        require(presaleRate > 0, "Private sale is not set");
        uint256 amount = (msg.value * presaleRate) / (1 ether);
        uint256 immediateAmount = amount / 100;

        require(
            token.balanceOf(address(this)) >=
                unclaimedAllocation + amount,
            "NOT ENOUGH TOKEN IN DISTRIBUTOR"
        );

        payable(admin).transfer(msg.value);

        allocations[msg.sender].push(
            Allocation({
                totalAmount: amount,
                claimedAmount: immediateAmount,
                nextClaimTime: block.timestamp + DAY30
            })
        );

        unclaimedAllocation += (amount - immediateAmount);

        token.transfer(msg.sender, immediateAmount);
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

            token.transfer(msg.sender, claimable);
            unclaimedAllocation -= claimable;
            emit AllocationClaimed(msg.sender, claimable);
        } else {
            revert("No elapsed periods");
        }
    }

    function setPresaleRate(uint256 _rate) isAdministrator external {
        presaleRate = _rate;
        emit PresaleRateChanged(_rate);
    }

    function startStopPrivateSale(bool _status) isAdministrator external {
        presaleActive = _status;
        emit PresaleStatusChanged(_status);
    }

    function giveAllocation(address user, uint256 amount) isAdministrator external {
        require(
            token.balanceOf(address(this)) >= unclaimedAllocation + amount,
            "NOT ENOUGH TOKEN IN DISTRIBUTOR"
        );

        Allocation memory newAllocation = Allocation({
            totalAmount: amount,
            claimedAmount: 0,
            nextClaimTime: block.timestamp
        });

        unclaimedAllocation += amount;
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
}
