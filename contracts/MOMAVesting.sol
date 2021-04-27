// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MOMAVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public token;
    uint256 public totalRounds;
    uint256 public daysPerRound;

    struct VestingInfo {
        bool isActive;
        uint256 amount;
        uint256 startTime;
        uint256 claimedAmount;
        uint256 fullLockedDays;
        uint256 releaseTotalRounds;
        uint256 daysPerRound;
    }

    // user address => vestingInfo[]
    mapping(address => VestingInfo) private _vestingList;

    constructor(address _token) public {
        token = IERC20(_token);
    }

    function addVesting(
        address _beneficiary,
        uint256 _amount,
        uint256 _fullLockedDays,
        uint256 _releaseTotalRounds,
        uint256 _daysPerRound
    ) external onlyOwner {
        require(_beneficiary != address(0), "MOMAVesting: Zero address");
        require(!_vestingList[_beneficiary].isActive, "MOMAVesting: Invalid vesting");
        token.safeTransferFrom(_msgSender(), address(this), _amount);
        VestingInfo memory info =
            VestingInfo(
                true,
                _amount,
                block.timestamp,
                0,
                _fullLockedDays,
                _releaseTotalRounds,
                _daysPerRound
            );
        _vestingList[_beneficiary] = info;
    }

    function revokeVesting(address user) external onlyOwner {
        require(_vestingList[user].isActive, "MOMAVesting: Invalid beneficiary");
        VestingInfo memory info = _vestingList[user];
        require(info.isActive, "MOMAVesting: Invalid beneficiary");
        uint256 claimableAmount = _getVestingClaimableAmount(user);
        _vestingList[user].isActive = false;
        token.transfer(user, claimableAmount);
        token.transfer(owner(), info.amount.sub(info.claimedAmount));
    }

    function claimVesting() public nonReentrant {
        require(_vestingList[_msgSender()].isActive, "MOMAVesting: Invalid beneficiary");
        uint256 claimableAmount = _getVestingClaimableAmount(_msgSender());
        require(claimableAmount > 0, "MOMAVesting: Nothing to claim");
        _vestingList[_msgSender()].claimedAmount = _vestingList[_msgSender()].claimedAmount.add(
            claimableAmount
        );
        require(token.transfer(msg.sender, claimableAmount), "MOMAVesting: transfer failed");
    }

    function _getVestingClaimableAmount(address user)
        internal
        view
        returns (uint256 claimableAmount)
    {
        if (!_vestingList[user].isActive) return 0;
        VestingInfo memory info = _vestingList[user];
        uint256 releaseTime = info.startTime.add(info.fullLockedDays.mul(1 days));
        if (block.timestamp < releaseTime) return 0;
        uint256 roundsPassed =
            (block.timestamp.sub(releaseTime)).div(1 days).div(info.daysPerRound);

        uint256 releasedAmount;
        if (roundsPassed >= info.releaseTotalRounds) {
            releasedAmount = info.amount;
        } else {
            releasedAmount = info.amount.mul(roundsPassed).div(info.releaseTotalRounds);
        }
        claimableAmount = 0;
        if (releasedAmount > info.claimedAmount) {
            claimableAmount = releasedAmount.sub(info.claimedAmount);
        }
    }

    function getVestingClaimableAmount(address user) external view returns (uint256) {
        return _getVestingClaimableAmount(user);
    }

    function getVestingInfoByUser(address user) external view returns (VestingInfo memory) {
        VestingInfo memory info = _vestingList[user];
        return info;
    }
}
