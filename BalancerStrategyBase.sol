//SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

import "../../extensions/TokensRescuer.sol";

import "../../interfaces/IParallaxStrategy.sol";
import "../../interfaces/IParallaxOrbital.sol";
import "../../interfaces/IBalancerVault.sol";
import "../../interfaces/IWETH.sol";
import "../../interfaces/IUniswapWrapper.sol";
import "../../interfaces/IRewardsGauge.sol";

error OnlyParallax();
error OnlyWhitelistedToken();
error OnlyValidSlippage();
error OnlyValidAmount();
error OnlyCorrectArrayLength();

contract BalancerStrategyBaseUpgradeable is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    TokensRescuer,
    IParallaxStrategy
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct BaseInitParams {
        address _PARALLAX_ORBITAL;
        address _BALANCER_VAULT;
        address _STAKING;
        address _UNI_WRAPPER;
        address _WANT;
        address _WETH;
        address _WETH_USD_ORACLE;
        Asset[] _ASSETS;
        Reward[] _REWARDS;
        bytes32 _WANT_POOL_ID;
        uint256 _EXPIRE_TIME;
        uint256 _maxSlippage;
        uint256 _initialCompoundMinAmount;
    }

    struct Asset {
        address token;
        bytes queryIn;
        bytes queryOut;
    }

    struct Reward {
        address token;
        bytes queryIn;
        bytes queryOut;
        AggregatorV2V3Interface usdOracle;
    }

    address public constant STRATEGY_AUTHOR = address(0);

    address public PARALLAX_ORBITAL;
    address public BALANCER_VAULT;
    address public UNI_WRAPPER;
    address public STAKING;

    address public WETH;
    AggregatorV2V3Interface WETH_USD_ORACLE;
    address public WANT;
    bytes32 public WANT_POOL_ID;

    Asset[] public assets;
    Reward[] public rewards;

    uint256 public EXPIRE_TIME;
    uint256 public constant MAX_WITHDRAW_FEE = 10000;
    uint256 public constant STALE_PRICE_DELAY = 24 hours;

    uint256 public accumulatedFees;
    uint256 public maxSlippage;
    uint256 public initialCompoundMinAmount;
    uint256 public currentReward;

    modifier onlyWhitelistedToken(address token) {
        _onlyWhitelistedToken(token);
        _;
    }

    modifier onlyParallax() {
        _onlyParallax();
        _;
    }

    function setMaxSlippage(uint256 newMaxSlippage) external onlyParallax {
        if (newMaxSlippage > 1000) {
            revert OnlyValidSlippage();
        }

        maxSlippage = newMaxSlippage;
    }

    receive() external payable {}

    fallback() external payable {}

    function __BalancerStrategyBase_init_unchained(
        BaseInitParams memory baseInitParams
    ) internal initializer {
        PARALLAX_ORBITAL = baseInitParams._PARALLAX_ORBITAL;
        BALANCER_VAULT = baseInitParams._BALANCER_VAULT;
        STAKING = baseInitParams._STAKING;
        UNI_WRAPPER = baseInitParams._UNI_WRAPPER;
        WETH = baseInitParams._WETH;
        WETH_USD_ORACLE = AggregatorV2V3Interface(baseInitParams._WETH_USD_ORACLE);
        EXPIRE_TIME = baseInitParams._EXPIRE_TIME;
        WANT = baseInitParams._WANT;
        WANT_POOL_ID = baseInitParams._WANT_POOL_ID;
        maxSlippage = baseInitParams._maxSlippage;
        initialCompoundMinAmount = baseInitParams._initialCompoundMinAmount;

        for (uint256 i = 0; i < baseInitParams._ASSETS.length; i++) {
            assets.push(baseInitParams._ASSETS[i]);
        }

        uint256 rewardsLength = baseInitParams._REWARDS.length;
        for (uint256 i = 0; i < rewardsLength; i++) {
            rewards.push(baseInitParams._REWARDS[i]);
        }
    }

    function setCompoundMinAmount(
        uint256 newCompoundMinAmount
    ) external onlyParallax {
        initialCompoundMinAmount = newCompoundMinAmount;
    }

    /// @inheritdoc ITokensRescuer
    function rescueNativeToken(
        uint256 amount,
        address receiver
    ) external onlyParallax {
        _rescueNativeToken(amount, receiver);
    }

    /// @inheritdoc ITokensRescuer
    function rescueERC20Token(
        address token,
        uint256 amount,
        address receiver
    ) external onlyParallax {
        _rescueERC20Token(token, amount, receiver);
    }

    function transferPositionFrom(
        address from,
        address to,
        uint256 tokenId
    ) external onlyParallax {}

    function claim(
        uint256 strategyId,
        address user,
        uint256 positionId
    ) external onlyParallax {
        currentReward += _harvest();
    }

    /**
     * @notice Deposit amount of WSTETH-WETH LP tokens into the Balancer pool.
     * @dev This function is only callable by the Parallax contract.
     * @param params An object containing the user's address and the amount of tokens to deposit.
     */
    function depositLPs(
        DepositParams memory params
    ) external nonReentrant onlyParallax returns (uint256) {
        _onlyCorrectArrayLength(params.amounts.length, 1);
        if (params.amounts[0] > 0) {
            IERC20Upgradeable(WANT).safeTransferFrom(
                params.user,
                address(this),
                params.amounts[0]
            );
            _stake(params.amounts[0]);
            return params.amounts[0];
        }

        return 0;
    }

    /**
     * @notice Deposit an equal amount of WSTETH and WETH tokens into the Balancer pool.
     * @dev This function is only callable by the Parallax contract.
     * @param params An object containing the user's address and the amount of tokens to deposit.
     */
    function depositTokens(
        DepositParams memory params
    ) external nonReentrant onlyParallax returns (uint256) {
        _onlyCorrectArrayLength(params.amounts.length, assets.length);
        for (uint i = 0; i < assets.length; i++) {
            if (params.amounts[i] == 0) {
                return 0;
            }
        }

        for (uint i = 0; i < assets.length; i++) {
            IERC20Upgradeable(assets[i].token).safeTransferFrom(
                params.user,
                address(this),
                params.amounts[i]
            );
        }

        uint256 amount = _balancerAddLiquidity(params.amounts);
        _stake(amount);
        return amount;
    }

    /**
     * @notice Swap native Ether for WSTETH and WETH tokens, then deposit them into the Balancer pool.
     * @dev This function is only callable by the Parallax contract and requires ETH to be sent along with the transaction.
     */
    function depositAndSwapNativeToken(
        DepositParams memory params
    ) external payable nonReentrant onlyParallax returns (uint256) {
        if (msg.value > 0) {
            uint[] memory amounts = _breakEth(msg.value);
            uint256 amount = _balancerAddLiquidity(amounts);
            _stake(amount);
            return amount;
        }

        return 0;
    }

    /**
     * @notice Swap the specified ERC20 token for WSTETH and WETH tokens, then deposit them into the Balancer pool.
     * @dev This function is only callable by the Parallax contract.
     */
    function depositAndSwapERC20Token(
        DepositParams memory params
    ) external nonReentrant onlyParallax returns (uint256) {
        address token = address(uint160(bytes20(params.data[0])));
        _onlyWhitelistedToken(token);

        if (params.amounts[0] > 0) {
            IERC20Upgradeable(token).safeTransferFrom(
                params.user,
                address(this),
                params.amounts[0]
            );

            IERC20Upgradeable(token).safeIncreaseAllowance(
                UNI_WRAPPER,
                params.amounts[0]
            );

            uint256 amountWeth = IUniswapWrapper(UNI_WRAPPER).swapV3(
                token,
                params.data[1],
                params.amounts[0],
                params.amountsOutMin[0]
            );

            uint[] memory amounts;

            IWETH(WETH).withdraw(amountWeth);
            amounts = _breakEth(address(this).balance);

            uint amount = _balancerAddLiquidity(amounts);

            _stake(amount);

            return amount;
        }

        return 0;
    }

    /**
     * @notice Compound the harvested rewards back into the Balancer pool.
     * @dev This function is only callable by the Parallax contract.
     */
    function compound(
        uint256[] memory amountsOutMin
    ) external onlyParallax returns (uint256) {
        currentReward += _harvest();

        if (currentReward > 0) {
            IWETH(WETH).withdraw(currentReward);
            uint256[] memory amounts = _breakEth(address(this).balance);
            uint256 amount = _balancerAddLiquidity(amounts);
            _stake(amount);
            currentReward = 0;
            return amount;
        }

        return 0;
    }

    /**
     * @notice Withdraw the specified amount of WSTETH-WETH LP tokens from the Balancer pool.
     * @dev This function is only callable by the Parallax contract.
     * @param params An object containing the recipient's address, the amount to withdraw, and the earned amount.
     */
    function withdrawTokens(
        WithdrawParams memory params
    ) external nonReentrant onlyParallax {
        _onlyCorrectArrayLength(params.amountsOutMin.length, 3);
        if (params.amount > 0) {
            (
                uint256 actualWithdraw,
                uint256 withdrawalFee
            ) = _calculateActualWithdrawAndWithdrawalFee(
                    params.amount,
                    params.earned
                );
            
            _withdraw(params.receiver, actualWithdraw, params.amountsOutMin);

            _unstake(withdrawalFee);
            _takeFee(withdrawalFee);
        }
    }

    /**
     * @notice Withdraw the specified amount of WSTETH and WETH tokens from the Balancer pool.
     * @dev This function is only callable by the Parallax contract.
     * @param params An object containing the recipient's address, the amount to withdraw, and the earned amount.
     */
    function withdrawLPs(
        WithdrawParams memory params
    ) external nonReentrant onlyParallax {
        if (params.amount > 0) {
            (
                uint256 actualWithdraw,
                uint256 withdrawalFee
            ) = _calculateActualWithdrawAndWithdrawalFee(
                    params.amount,
                    params.earned
                );

            _unstake(actualWithdraw);

            IERC20Upgradeable(WANT).safeTransfer(
                params.receiver,
                actualWithdraw
            );

            _takeFee(withdrawalFee);
        }
    }

    /**
     * @notice Withdraw the specified amount of WSTETH and WETH tokens from the Balancer pool and swap them for the specified ERC20 token.
     * @dev This function is only callable by the Parallax contract.
     * @param params An object containing the recipient's address, the amount to withdraw, the earned amount, and the address of the ERC20 token to swap for.
     */
    function withdrawAndSwapForERC20Token(
        WithdrawParams memory params
    ) external nonReentrant onlyParallax {
        _onlyCorrectArrayLength(params.amountsOutMin.length % 2, 1);
        _onlyCorrectArrayLength(params.amountsOutMin.length / 2, assets.length);
        if (params.amount > 0) {
            (
                uint256 actualWithdraw,
                uint256 withdrawalFee
            ) = _calculateActualWithdrawAndWithdrawalFee(
                    params.amount,
                    params.earned
                );

            uint256[] memory minAmountsOut = _removeElementsFromEnd(
                params.amountsOutMin,
                assets.length + 1
            );

            address token = address(uint160(bytes20(params.data[0])));

            uint256[] memory amounts = _withdraw(
                address(this),
                actualWithdraw,
                minAmountsOut
            );

            uint receivedWeth;

            for (uint i = 0; i < assets.length; i++) {
                uint prevBalance = receivedWeth;
                receivedWeth += _preProcessOut(
                    assets[i].token,
                    amounts[i],
                    params.amountsOutMin[minAmountsOut.length + i]
                );

                if (receivedWeth > prevBalance) {
                    continue;
                }

                IERC20Upgradeable(assets[i].token).safeIncreaseAllowance(
                    UNI_WRAPPER,
                    amounts[i]
                );
                receivedWeth += IUniswapWrapper(UNI_WRAPPER).swapV3(
                    assets[i].token,
                    assets[i].queryIn,
                    amounts[i],
                    params.amountsOutMin[minAmountsOut.length + i]
                );
            }

            IERC20Upgradeable(WETH).safeIncreaseAllowance(
                UNI_WRAPPER,
                receivedWeth
            );

            uint totalOut = IUniswapWrapper(UNI_WRAPPER).swapV3(
                WETH,
                params.data[1],
                receivedWeth,
                params.amountsOutMin[params.amountsOutMin.length - 1]
            );

            IERC20Upgradeable(token).safeTransfer(params.receiver, totalOut);

            _unstake(withdrawalFee);

            _takeFee(withdrawalFee);
        }
    }

    /**
     * @notice Withdraw the specified amount of WSTETH and WETH tokens from the Balancer pool and swap them for the native token.
     * @dev This function is only callable by the Parallax contract.
     * @param params An object containing the recipient's address, the amount to withdraw, and the earned amount.
     */
    function withdrawAndSwapForNativeToken(
        WithdrawParams memory params
    ) external nonReentrant onlyParallax {
        _onlyCorrectArrayLength(params.amountsOutMin.length / 2, assets.length);

        if (params.amount > 0) {
            (
                uint256 actualWithdraw,
                uint256 withdrawalFee
            ) = _calculateActualWithdrawAndWithdrawalFee(
                    params.amount,
                    params.earned
                );

            uint256[] memory minAmountsOut = _removeElementsFromEnd(
                params.amountsOutMin,
                assets.length
            );

            uint256[] memory amounts = _withdraw(
                address(this),
                actualWithdraw,
                minAmountsOut
            );

            uint receivedWeth;
            for (uint i = 0; i < assets.length; i++) {
                uint prevBalance = receivedWeth;
                receivedWeth += _preProcessOut(
                    assets[i].token,
                    amounts[i],
                    params.amountsOutMin[minAmountsOut.length + i]
                );

                if (receivedWeth > prevBalance) {
                    continue;
                }

                IERC20Upgradeable(assets[i].token).safeIncreaseAllowance(
                    UNI_WRAPPER,
                    amounts[i]
                );
                receivedWeth += IUniswapWrapper(UNI_WRAPPER).swapV3(
                    assets[i].token,
                    assets[i].queryIn,
                    amounts[i],
                    params.amountsOutMin[minAmountsOut.length + i]
                );
            }

            IWETH(WETH).withdraw(
                IERC20Upgradeable(WETH).balanceOf(address(this))
            );

            payable(params.receiver).transfer(receivedWeth);

            _unstake(withdrawalFee);

            _takeFee(withdrawalFee);
        }
    }

    function getMaxFee() external view returns (uint256) {
        return MAX_WITHDRAW_FEE;
    }

    function _unstake(uint256 amount) internal virtual {
        if (amount == 0) {
            return;
        }

        IRewardsGauge(STAKING).withdraw(amount);
    }

    /**
     * @dev Adds liquidity to the Balancer pool using the provided amounts of WETH and WSTETH.
     * @param amounts The amounts of assets to add as liquidity.
     */
    function _balancerAddLiquidity(
        uint256[] memory amounts
    ) internal virtual returns (uint256) {
        (address[] memory tokens, , ) = IBalancerVault(BALANCER_VAULT)
            .getPoolTokens(WANT_POOL_ID);

        uint256[] memory fullAmounts = new uint256[](
            assets.length + tokens.length - assets.length
        );
        IAsset[] memory fullAddresses = new IAsset[](
            assets.length + tokens.length - assets.length
        );

        uint delt = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            fullAddresses[i] = IAsset(tokens[i]);

            if (tokens[i] == WANT) {
                delt++;
                fullAmounts[i] = 0;
                continue;
            }

            fullAmounts[i] = amounts[i - delt];

            IERC20Upgradeable(tokens[i]).safeIncreaseAllowance(
                BALANCER_VAULT,
                amounts[i - delt]
            );
        }

        IBalancerVault.JoinKind joinKind = IBalancerVault
            .JoinKind
            .EXACT_TOKENS_IN_FOR_BPT_OUT;

        IBalancerVault.JoinPoolRequest memory joinPoolRequest = IBalancerVault
            .JoinPoolRequest({
                assets: fullAddresses,
                maxAmountsIn: fullAmounts,
                userData: abi.encode(joinKind, amounts),
                fromInternalBalance: false
            });

        uint256 prevBalance = IERC20Upgradeable(WANT).balanceOf(address(this));

        IBalancerVault(BALANCER_VAULT).joinPool(
            WANT_POOL_ID,
            address(this),
            address(this),
            joinPoolRequest
        );

        uint256 currBalance = IERC20Upgradeable(WANT).balanceOf(address(this));
        return currBalance - prevBalance;
    }

    /**
     * @dev Harvests the rewards and converts them to WETH.
     * @return totalWethRewards The total amount of harvested WETH rewards.
     */
    function _harvest() internal returns (uint256 totalWethRewards) {
        uint256 wethUsdRate = _getPrice(WETH_USD_ORACLE);

        uint256[] memory amounts = _claim();

        uint256[] memory rates = new uint256[](rewards.length);

        for (uint i = 0; i < rewards.length; i++) {
            if (rewards[i].token == WETH) {
                totalWethRewards += amounts[i];
                continue;
            }

            rates[i] = _getPrice(rewards[i].usdOracle);

            if (amounts[i] > 0) {
                uint rewardWeth = _preProcessAmounts(rewards[i], amounts[i]);

                if (rewardWeth == 0) {
                    rewardWeth = _getAmountOut(rewards[i], amounts[i]);
                }

                if (rates[i] > 0) {
                    uint256 amountOutOracle = (rates[i] * rewardWeth) /
                        wethUsdRate;
                    uint256 slippage = (amountOutOracle *
                        (10000 - maxSlippage)) / 10000;

                    if (rewardWeth < slippage) {
                        continue;
                    } else {
                        uint256 amountOut = _preProcessIn(
                            rewards[i].token,
                            amounts[i]
                        );

                        if (amountOut > 0) {
                            totalWethRewards += amountOut;
                            continue;
                        }

                        IERC20Upgradeable(rewards[i].token)
                            .safeIncreaseAllowance(UNI_WRAPPER, amounts[i]);

                        totalWethRewards += IUniswapWrapper(UNI_WRAPPER).swapV3(
                                rewards[i].token,
                                rewards[i].queryIn,
                                amounts[i],
                                slippage
                            );
                    }
                }
            }
        }
    }

    function _stake(uint amount) internal virtual {
        IERC20Upgradeable(WANT).safeIncreaseAllowance(STAKING, amount);
        IRewardsGauge(STAKING).deposit(amount);
    }

    function _claim() internal virtual returns (uint256[] memory amounts) {
        IRewardsGauge(STAKING).claim_rewards(address(this));
        amounts = new uint256[](rewards.length);

        for (uint i = 0; i < rewards.length; i++) {
            amounts[i] = IERC20Upgradeable(rewards[i].token).balanceOf(
                address(this)
            );
        }
    }

    function _preProcessIn(
        address token,
        uint256 amount
    ) internal virtual returns (uint256) {
        return 0;
    }

    function _preProcessOut(
        address token,
        uint256 amount,
        uint256 minAmountOut
    ) internal virtual returns (uint256) {
        return 0;
    }

    function _preProcessAmounts(
        Reward memory reward,
        uint256 amount
    ) internal virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Withdraws the specified amount of LP tokens from the rewards gauge and
     *      exits the Balancer pool, returning the WSTETH and WETH tokens to the recipient.
     * @param amount: The amount of LP tokens to withdraw.
     * @param recipient: The address that will receive the withdrawn tokens.
     */
    function _withdraw(
        address recipient,
        uint256 amount,
        uint256[] memory minAmountsOut
    ) internal virtual returns (uint256[] memory delta) {
        if (amount == 0) {
            return delta;
        }

        _unstake(amount);

        (address[] memory tokens, , ) = IBalancerVault(BALANCER_VAULT)
            .getPoolTokens(WANT_POOL_ID);

        uint256[] memory fullAmounts = new uint256[](
            assets.length + tokens.length - assets.length
        );
        IAsset[] memory fullAddresses = new IAsset[](
            assets.length + tokens.length - assets.length
        );

        uint delt = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            fullAddresses[i] = IAsset(tokens[i]);

            if (tokens[i] == WANT) {
                delt++;
                fullAmounts[i] = 0;
                continue;
            }

            fullAmounts[i] = minAmountsOut[i - delt];
        }

        IBalancerVault.ExitKind exitKind = IBalancerVault
            .ExitKind
            .EXACT_BPT_IN_FOR_ALL_TOKENS_OUT;

        IBalancerVault.ExitPoolRequest memory exitPoolRequest = IBalancerVault
            .ExitPoolRequest({
                assets: fullAddresses,
                minAmountsOut: fullAmounts,
                userData: abi.encode(exitKind, amount),
                toInternalBalance: false
            });

        uint256[] memory prevBalances = new uint256[](assets.length);

        IBalancerVault(BALANCER_VAULT).exitPool(
            WANT_POOL_ID,
            address(this),
            recipient,
            exitPoolRequest
        );

        uint256[] memory aftBalances = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            aftBalances[i] = IERC20Upgradeable(assets[i].token).balanceOf(
                address(this)
            );
        }

        delta = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            delta[i] = aftBalances[i] - prevBalances[i];
        }
        return delta;
    }

    function _balancerSwapSingle(
        address tokenOut,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32 poolId
    ) internal returns (uint256) {
        IERC20Upgradeable(tokenIn).safeIncreaseAllowance(
            BALANCER_VAULT,
            amountIn
        );

        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault
            .SingleSwap({
                poolId: poolId,
                kind: IBalancerVault.SwapKind.GIVEN_IN,
                assetIn: IAsset(tokenIn),
                assetOut: IAsset(tokenOut),
                amount: amountIn,
                userData: "0x"
            });

        IBalancerVault.FundManagement memory fundManagement = IBalancerVault
            .FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            });

        uint256 receivedTokenOut = IBalancerVault(BALANCER_VAULT).swap(
            singleSwap,
            fundManagement,
            minAmountOut,
            _getDeadline()
        );

        return receivedTokenOut;
    }

    /**
     * @dev Breaks a given amount of Ether into WETH and WSTETH tokens.
     * @param amount The amount of Ether to break.
     */
    function _breakEth(
        uint256 amount
    ) internal returns (uint256[] memory amounts) {
        if (amount < assets.length) {
            revert OnlyValidAmount();
        }
        IWETH(WETH).deposit{ value: amount }();
        uint balanceWeth = IERC20Upgradeable(WETH).balanceOf(address(this));
        uint part = balanceWeth / assets.length;
        amounts = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i].token == WETH) {
                amounts[i] = part;
            } else {
                IERC20Upgradeable(WETH).safeIncreaseAllowance(
                    UNI_WRAPPER,
                    part
                );

                uint amountIn = _preProcessIn(assets[i].token, part);

                if (amountIn > 0) {
                    amounts[i] = amountIn;
                    continue;
                }

                amounts[i] = IUniswapWrapper(UNI_WRAPPER).swapV3(
                    WETH,
                    assets[i].queryOut,
                    part,
                    0
                );
            }
        }
    }

    function _takeFee(uint256 fee) internal {
        if (fee > 0) {
            accumulatedFees += fee;
            IERC20Upgradeable(WANT).safeTransfer(
                IParallaxOrbital(PARALLAX_ORBITAL).feesReceiver(),
                fee
            );
        }
    }

    function _calculateActualWithdrawAndWithdrawalFee(
        uint256 withdrawalAmount,
        uint256 earnedAmount
    ) internal view returns (uint256 actualWithdraw, uint256 withdrawalFee) {
        uint256 actualEarned = (earnedAmount *
            (MAX_WITHDRAW_FEE -
                IParallaxOrbital(PARALLAX_ORBITAL).getFee(address(this)))) /
            MAX_WITHDRAW_FEE;

        withdrawalFee = earnedAmount - actualEarned;
        actualWithdraw = withdrawalAmount - withdrawalFee;
    }

    function _getDeadline() private view returns (uint256) {
        return block.timestamp + EXPIRE_TIME;
    }

    /**
     * @notice Returns a price of a token in a specified oracle.
     * @param oracle An address of an oracle which will return a price of asset.
     * @return A tuple with a price of token, token decimals and a flag that
     *         indicates if data is actual (fresh) or not.
     */
    function _getPrice(
        AggregatorV2V3Interface oracle
    ) internal view returns (uint256) {
        if (address(oracle) == address(0)) {
            return 0;
        }
        (
            uint80 roundID,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();
        bool dataIsActual = answeredInRound >= roundID &&
            answer > 0 &&
            block.timestamp <= updatedAt + STALE_PRICE_DELAY;

        uint8 decimals = oracle.decimals();

        if (!dataIsActual) {
            return 0;
        }

        return uint256(answer);
    }

    function _getAmountOut(
        Reward memory reward,
        uint amountIn
    ) internal returns (uint256) {
        uint amountOut = IUniswapWrapper(UNI_WRAPPER).getAmountOut(
            reward.queryOut,
            amountIn
        );

        return amountOut;
    }

    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bytes32 poolId
    ) internal returns (uint256) {
        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(tokenIn);
        assets[1] = IAsset(tokenOut);

        (address[] memory tokens, , ) = IBalancerVault(BALANCER_VAULT)
            .getPoolTokens(poolId);

        (uint assetIn, uint assetOut) = tokens[0] == tokenIn ? (0, 1) : (1, 0);

        IBalancerVault.BatchSwapStep[]
            memory batchSwapSteps = new IBalancerVault.BatchSwapStep[](1);

        batchSwapSteps[0] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: assetIn,
            assetOutIndex: assetOut,
            amount: amountIn,
            userData: ""
        });

        IBalancerVault.FundManagement memory fundManagement = IBalancerVault
            .FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            });

        int256[] memory amountsOut = IBalancerVault(BALANCER_VAULT)
            .queryBatchSwap(
                IBalancerVault.SwapKind.GIVEN_IN,
                batchSwapSteps,
                assets,
                fundManagement
            );

        if (amountsOut[1] <= 0) {
            amountsOut[1] = -amountsOut[1];
        }

        return uint256(amountsOut[1]);
    }

    function _getStakingBalance() internal view virtual returns (uint256) {
        return IRewardsGauge(STAKING).balanceOf(address(this));
    }

    function _removeElementsFromEnd(
        uint[] memory arr,
        uint n
    ) internal pure returns (uint[] memory) {
        assert(n <= arr.length);

        uint[] memory newArr = new uint[](arr.length - n);
        for (uint i = 0; i < newArr.length; i++) {
            newArr[i] = arr[i];
        }
        return newArr;
    }

    function _onlyParallax() private view {
        if (_msgSender() != PARALLAX_ORBITAL) {
            revert OnlyParallax();
        }
    }

    function _onlyWhitelistedToken(address token) private view {
        if (
            !IParallaxOrbital(PARALLAX_ORBITAL).tokensWhitelist(
                address(this),
                token
            )
        ) {
            revert OnlyWhitelistedToken();
        }
    }

    function _onlyCorrectArrayLength(
        uint256 actualLength,
        uint256 expectedlength
    ) private pure {
        if (actualLength != expectedlength) {
            revert OnlyCorrectArrayLength();
        }
    }
}
