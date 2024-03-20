pragma solidity ^0.8.0;
import "../interfaces/IERC20.sol";

library LibStaking {
    bytes32 constant STAKING_STORAGE_POSITION =
        keccak256("diamond.standard.staking.storage");
    uint256 public constant APY = 120; // 120% Annual Percentage Yield
    uint256 public constant SECONDS_IN_YEAR = 31536000; // 60 * 60 * 24 * 365

    enum TokenType {
        StakeToken
        RewardToken,
    }

    struct StakeToken {
        string name;
        string symbol;
        uint totalSupply;
        mapping(address => uint) balanceOf;
        mapping(address => mapping(address => uint)) allowance;
    }

    struct RewardToken {
        string name;
        string symbol;
        uint totalSupply;
        mapping(address => uint) balanceOf;
        mapping(address => mapping(address => uint)) allowance;
    }

    // Struct to store user's staking data
    struct StakeData {
        IERC20 stakeToken;
        IERC20 rewardToken;
        mapping(address => uint256) public stakedAmounts;
        mapping(address => uint256) public stakingStartTime;
        mapping(address => uint256) public unclaimedRewards;
    }

    function appStorage() internal pure returns (Layout storage ds) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
