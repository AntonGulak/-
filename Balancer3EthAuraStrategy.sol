pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./BalancerStrategyBase.sol";
import "../../interfaces/IStEth.sol";
import "../../interfaces/IWstEth.sol";
import "../../interfaces/IAura.sol";
import "../../interfaces/IFrxEthMinter.sol";

contract Balancer3EthAuraStrategy is BalancerStrategyBaseUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public STAKING_TOKEN; 

    address private BAL; 
    address private AURA; 

    address private WSTETH;
    address private STETH;
    address private SFRXETH;
    address private FRXETH; 
    address private FRXETH_MINTER;

    bytes32 private WETH_WSTETH_ID; 
    bytes32 private BAL_WETH_ID;
    bytes32 private AURA_WETH_ID;


    struct InitParams {
        address _BAL;
        address _AURA;
        address _WSTETH;
        address _STETH;
        address _SFRXETH;
        address _FRXETH;
        address _FRXETH_MINTER;
        address _STAKING_TOKEN;
        bytes32 _WETH_WSTETH_ID;
        bytes32 _BAL_WETH_ID;
        bytes32 _AURA_WETH_ID;
    }
    
    function __Balancer3EthAuraStrategy_init_unchained(
        InitParams memory initParams
    ) internal initializer {
        BAL = initParams._BAL;
        AURA = initParams._AURA;
        WSTETH = initParams._WSTETH;
        STETH = initParams._STETH;
        SFRXETH = initParams._SFRXETH;
        FRXETH = initParams._FRXETH;
        FRXETH_MINTER = initParams._FRXETH_MINTER;
        STAKING_TOKEN = initParams._STAKING_TOKEN;
        WETH_WSTETH_ID = initParams._WETH_WSTETH_ID;
        BAL_WETH_ID = initParams._BAL_WETH_ID;
        AURA_WETH_ID = initParams._AURA_WETH_ID;
    }


     function __Balancer3EthAuraStrategy_init(
        BaseInitParams memory baseInitParams,
        InitParams memory initParams
    ) public initializer {
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __BalancerStrategyBase_init_unchained(baseInitParams);
        __Balancer3EthAuraStrategy_init_unchained(initParams);
    }

    function _unstake(uint256 amount) internal override {
        IAura(STAKING).withdrawAndUnwrap(amount, true);
    }

    function _stake(uint256 amount) internal override {
        IERC20Upgradeable(WANT).safeIncreaseAllowance(STAKING, amount);
        IAura(STAKING).deposit(amount, address(this));
    }

    function _getStakingBalance() internal view override returns (uint256) {
        return IAura(STAKING).earned(address(this));
    }

    function _claim()
        internal
        virtual
        override
        returns (uint256[] memory amounts)
    {
        IAura(STAKING).getReward(address(this), true);

        amounts = new uint256[](rewards.length);
        for (uint256 i = 0; i < rewards.length; i++) {
            amounts[i] = IERC20Upgradeable(rewards[i].token).balanceOf(
                address(this)
            );
        }
    }

    function _preProcessIn(
        address token,
        uint256 amount
    ) internal override returns (uint256) {
        if (token == WSTETH) {
            IWETH(WETH).withdraw(amount);
            uint256 amountOut = IStEth(STETH).submit{
                value: address(this).balance
            }(address(0));
            IERC20Upgradeable(STETH).safeIncreaseAllowance(WSTETH, amountOut);
            return IWstEth(WSTETH).wrap(amountOut);
        }
        if (token == SFRXETH) {
            IWETH(WETH).withdraw(amount);
            IERC20Upgradeable(SFRXETH).safeIncreaseAllowance(
                FRXETH_MINTER,
                amount
            );
            return
                IFrxEthMinter(FRXETH_MINTER).submitAndDeposit{
                    value: address(this).balance
                }(address(this));
        }

        return 0;
    }

    function _preProcessOut(
        address token,
        uint256 amount,
        uint256 minAmountOut
    ) internal override returns (uint256) {
        if (token == WSTETH) {
            uint256 amountOut = _balancerSwapSingle(
                WETH,
                WSTETH,
                amount,
                minAmountOut,
                WETH_WSTETH_ID
            );
            return amountOut;
        }
        if (token == SFRXETH) {
            uint256 amountOutWsteth = _balancerSwapSingle(
                WSTETH,
                SFRXETH,
                amount,
                minAmountOut,
                WANT_POOL_ID
            );

            uint256 amountOut = _balancerSwapSingle(
                WETH,
                WSTETH,
                amountOutWsteth,
                0,
                WETH_WSTETH_ID
            );
            return amountOut;
        }
        return 0;
    }

    function _preProcessAmounts(
        Reward memory reward,
        uint256 amount
    ) internal override returns (uint256) {
        if (reward.token == BAL) {
            return _getAmountOut(amount, reward.token, WETH, BAL_WETH_ID);
        }
        if (reward.token == AURA) {
            return _getAmountOut(amount, reward.token, WETH, AURA_WETH_ID);
        }
        return 0;
    }
}
