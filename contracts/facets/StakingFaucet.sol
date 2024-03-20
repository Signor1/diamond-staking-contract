// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;
import "../interfaces/IERC20.sol";
import "../libraries/LibStaking.sol";

error ZERO_AMOUNT_NOT_ALLOWED();
error INSUFFICIENT_TOKEN_BALANCE();
error STAKING_TOKEN_TRANSFER_FAILED();
error INVALID_UNSTAKE_AMOUNT();
error FAILED_TO_RETURN_STAKED_TOKEN();
error NO_REWARD_TO_CLAIM();
error FAILED_TO_TRANSFER_REWARD();

contract StakingFaucet {
    event Staked(address indexed account, uint256 indexed amount, uint256 at);
    event Unstaked(address indexed account, uint256 indexed amount, uint256 at);

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    function stake(uint256 amount) external {
        LibStaking.StakeData storage stakeInfo = LibStaking.appStorage();

        if (amount < 1) {
            revert ZERO_AMOUNT_NOT_ALLOWED();
        }

        if (stakeInfo.stakeToken.balanceOf(msg.sender) < amount) {
            revert INSUFFICIENT_TOKEN_BALANCE();
        }

        // Transfer staking tokens from the user to the contract
        bool sent = stakeInfo.stakeToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );

        if (!sent) {
            revert STAKING_TOKEN_TRANSFER_FAILED();
        }

        // If already staked, first update their unclaimed rewards before adding new stake
        if (stakeInfo.stakedAmounts[msg.sender] > 0) {
            stakeInfo.unclaimedRewards[msg.sender] += calculateReward(
                msg.sender
            );
        } else {
            stakeInfo.stakingStartTime[msg.sender] = block.timestamp;
        }

        stakeInfo.stakedAmounts[msg.sender] += amount;

        emit Staked(msg.sender, amount, block.timestamp);
    }

    function unstake(uint256 amount) external {
        LibStaking.StakeData storage stakeInfo = LibStaking.appStorage();

        if (amount < 0 && amount > stakeInfo.stakedAmounts[msg.sender]) {
            revert INVALID_UNSTAKE_AMOUNT();
        }

        // Update unclaimed rewards before unstaking
        stakeInfo.unclaimedRewards[msg.sender] += calculateReward(msg.sender);
        stakeInfo.stakingStartTime[msg.sender] = block.timestamp;

        stakeInfo.stakedAmounts[msg.sender] -= amount;
        bool sent = stakeInfo.stakingToken.transfer(msg.sender, amount);

        if (!sent) {
            revert FAILED_TO_RETURN_STAKED_TOKEN();
        }

        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    function claimRewards() external {
        LibStaking.StakeData storage stakeInfo = LibStaking.appStorage();

        uint256 reward = calculateReward(msg.sender) +
            stakeInfo.unclaimedRewards[msg.sender];

        if (reward < 1) {
            revert NO_REWARD_TO_CLAIM();
        }

        stakeInfo.unclaimedRewards[msg.sender] = 0;
        stakeInfo.stakingStartTime[msg.sender] = block.timestamp;

        bool sent = stakeInfo.rewardToken.transfer(msg.sender, reward);

        if (!sent) {
            revert FAILED_TO_TRANSFER_REWARD();
        }
    }

    function calculateReward(address user) public view returns (uint256) {
        LibStaking.StakeData storage stakeInfo = LibStaking.appStorage();

        uint256 stakedTimeInSeconds = block.timestamp -
            stakeInfo.stakingStartTime[user];
        uint256 stakedAmount = stakeInfo.stakedAmounts[user];
        uint256 reward = (stakedAmount * LibStaking.APY * stakedTimeInSeconds) /
            LibStaking.SECONDS_IN_YEAR /
            100;
        return reward;
    }
}
