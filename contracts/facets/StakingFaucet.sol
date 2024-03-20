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
    event RewardClaimed(
        address indexed account,
        uint256 indexed amount,
        uint256 at
    );

    function initStakeToken() external {
        LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();
        stakeToken.name = "Signor Token";
        stakeToken.symbol = "STK";
        stakeToken.totalSupply = 100000 * 10 ** 18;
        stakeToken.balanceOf[msg.sender] = stakeToken.totalSupply;
    }

    // INITIALIZED REWARD TOKEN
    function initRewardToken() external {
        LibStaking.RewardToken storage rewardToken = LibStaking.appStorage();
        rewardToken.name = "Emmy Token";
        rewardToken.symbol = "ETK";
        rewardToken.totalSupply = 100000 * 10 ** 18;
    }

    // constructor(address _stakingToken, address _rewardToken) {
    //     stakingToken = IERC20(_stakingToken);
    //     rewardToken = IERC20(_rewardToken);
    // }

    // INITIATE TOKEN TRANSFER
    function transfer(
        address recipient,
        uint256 amount,
        LibStaking.TokenType tokenType
    ) public {
        if (tokenType == LibStaking.TokenType.StakeToken) {
            LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();
            require(
                stakeToken.balanceOf[msg.sender] >= amount,
                "INSUFFICIENT_BALANCE"
            );
            stakeToken.balanceOf[msg.sender] -= amount;
            stakeToken.balanceOf[recipient] += amount;
        } else {
            LibStaking.RewardToken storage rewardToken = LibStaking
                .appStorage();
            require(
                rewardToken.balanceOf[msg.sender] >= amount,
                "INSUFFICIENT_BALANCE"
            );
            rewardToken.balanceOf[msg.sender] -= amount;
            rewardToken.balanceOf[recipient] += amount;
        }
    }

    // GET ALLOWANCE
    function getAllowance(
        address owner,
        address spender,
        LibStaking.TokenType tokenType
    ) public view returns (uint256) {
        if (tokenType == LibAppStorage.TokenType.StakeToken) {
            LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();
            return stakeToken.allowance[owner][spender];
        } else {
            LibStaking.RewardToken storage rewardToken = LibStaking
                .appStorage();
            return rewardToken.allowance[owner][spender];
        }
    }

    // INITIALIZED APPROVE TOKEN
    function approve(
        address spender,
        uint256 amount,
        LibStaking.TokenType tokenType
    ) public {
        if (tokenType == LibStaking.TokenType.StakeToken) {
            LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();
            stakeToken.allowance[msg.sender][spender] = amount;
        } else {
            LibStaking.RewardToken storage rewardToken = LibStaking
                .appStorage();
            rewardToken.allowance[msg.sender][spender] = amount;
        }
    }

    // INITIALIZED TRANSFER FROM
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount,
        LibStaking.TokenType tokenType
    ) public {
        if (tokenType == LibStaking.TokenType.StakeToken) {
            LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();

            require(
                stakeToken.balanceOf[sender] >= amount,
                "INSUFFICIENT_BALANCE"
            );
            require(
                stakeToken.allowance[sender][recipient] >= amount,
                "INSUFFICIENT_ALLOWANCE"
            );
            stakeToken.balanceOf[sender] -= amount;
            stakeToken.balanceOf[recipient] += amount;
            stakeToken.allowance[sender][recipient] -= amount;
        } else {
            LibStaking.RewardToken storage rewardToken = LibStaking
                .appStorage();
            require(
                rewardToken.balanceOf[sender] >= amount,
                "INSUFFICIENT_BALANCE"
            );
            require(
                rewardToken.allowance[sender][recipient] >= amount,
                "INSUFFICIENT_ALLOWANCE"
            );
            rewardToken.balanceOf[sender] -= amount;
            rewardToken.balanceOf[recipient] += amount;
            rewardToken.allowance[sender][recipient] -= amount;
        }
    }

    // GET ACCOUNT TOKEN BALANCE
    function balanceOf(
        address account,
        LibStaking.TokenType tokenType
    ) public view returns (uint256) {
        if (tokenType == LibStaking.TokenType.StakeToken) {
            LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();
            return stakeToken.balanceOf[account];
        } else {
            LibStaking.RewardToken storage rewardToken = LibStaking
                .appStorage();
            return rewardToken.balanceOf[account];
        }
    }

    function getTotalSupply(
        LibStaking.TokenType tokenType
    ) public view returns (uint256) {
        if (tokenType == LibStaking.TokenType.StakeToken) {
            LibStaking.StakeToken storage stakeToken = LibStaking.appStorage();
            return stakeToken.totalSupply;
        } else {
            LibStaking.RewardToken storage rewardToken = LibStaking
                .appStorage();
            return rewardToken.totalSupply;
        }
    }

    function stake(uint256 amount) external {
        LibStaking.StakeData storage stakeInfo = LibStaking.appStorage();

        if (amount < 1) {
            revert ZERO_AMOUNT_NOT_ALLOWED();
        }

        if (balanceOf(msg.sender, LibStaking.TokenType.StakeToken) < amount) {
            revert INSUFFICIENT_TOKEN_BALANCE();
        }

        // Transfer staking tokens from the user to the contract
        bool sent = transferFrom(
            msg.sender,
            address(this),
            amount,
            LibStaking.TokenType.StakeToken
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

        bool sent = transfer(
            msg.sender,
            amount,
            LibStaking.TokenType.StakeToken
        );

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

        bool sent = transfer(
            msg.sender,
            reward,
            LibStaking.TokenType.RewardToken
        );

        if (!sent) {
            revert FAILED_TO_TRANSFER_REWARD();
        }

        emit RewardClaimed(msg.sender, reward, block.timestamp);
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
