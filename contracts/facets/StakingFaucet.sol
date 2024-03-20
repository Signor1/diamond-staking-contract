// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;
import "../interfaces/IERC20.sol";

contract StakingContract {
    event Staked(address indexed account, uint256 indexed amount, uint256 at);
    event Unstaked(address indexed account, uint256 indexed amount, uint256 at);

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");

        // Transfer staking tokens from the user to the contract
        bool sent = stakingToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(sent, "Staking token transfer failed");

        // If already staked, first update their unclaimed rewards before adding new stake
        if (stakedAmounts[msg.sender] > 0) {
            unclaimedRewards[msg.sender] += calculateReward(msg.sender);
        } else {
            stakingStartTime[msg.sender] = block.timestamp;
        }

        stakedAmounts[msg.sender] += amount;

        emit Staked(msg.sender, amount, block.timestamp);
    }

    function unstake(uint256 amount) external {
        require(
            amount > 0 && amount <= stakedAmounts[msg.sender],
            "Invalid unstake amount"
        );

        // Update unclaimed rewards before unstaking
        unclaimedRewards[msg.sender] += calculateReward(msg.sender);
        stakingStartTime[msg.sender] = block.timestamp;

        stakedAmounts[msg.sender] -= amount;
        bool sent = stakingToken.transfer(msg.sender, amount);
        require(sent, "Failed to return staking tokens");

        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    function claimRewards() external {
        uint256 reward = calculateReward(msg.sender) +
            unclaimedRewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        unclaimedRewards[msg.sender] = 0;
        stakingStartTime[msg.sender] = block.timestamp;

        bool sent = rewardToken.transfer(msg.sender, reward);
        require(sent, "Failed to transfer rewards");
    }

    function calculateReward(address user) public view returns (uint256) {
        uint256 stakedTimeInSeconds = block.timestamp - stakingStartTime[user];
        uint256 stakedAmount = stakedAmounts[user];
        uint256 reward = (stakedAmount * APY * stakedTimeInSeconds) /
            SECONDS_IN_A_YEAR /
            100;
        return reward;
    }
}
