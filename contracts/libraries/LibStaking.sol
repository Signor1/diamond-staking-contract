pragma solidity ^0.8.0;
import "../interfaces/IERC20.sol";

library LibStaking {
    bytes32 constant STAKING_STORAGE_POSITION =
        keccak256("diamond.standard.staking.storage");
    uint256 public constant APY = 120; // 120% Annual Percentage Yield
    uint256 public constant SECONDS_IN_YEAR = 31536000; // 60 * 60 * 24 * 365

    // Struct to store user's staking data
    struct StakeData {
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public stakingStartTime;
    mapping(address => uint256) public unclaimedRewards;
    }
    struct Layout {
        IERC20 stakeToken;
        IERC20 rewardToken;
    }

    function appStorage() internal pure returns (Layout storage ds) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
