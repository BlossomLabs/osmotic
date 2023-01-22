// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableUpgradeable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@oz-upgradeable/security/PausableUpgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {IStakingFactory} from "./interfaces/IStakingFactory.sol";
import {ILockManager} from "./interfaces/ILockManager.sol";
import {IStaking} from "./interfaces/IStaking.sol";

import {OsmoticPoolFactory} from "./proxy/OsmoticPoolFactory.sol";

import {OsmoticPool, ParticipantSupportUpdate} from "./OsmoticPool.sol";

error ErrorNotOsmoticPool();

contract OsmoticController is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, ILockManager {
    using SafeERC20 for IERC20;

    uint256 public immutable version;

    OsmoticPoolFactory public poolFactory;
    IStakingFactory public stakingFactory; // For finding each collateral token's staking pool and locking/unlocking tokens

    mapping(address => bool) isPool;

    mapping(address => uint256) internal participantSupportedPools; // Amount of pools supported by a participant

    /* *************************************************************************************************************************************/
    /* ** Events                                                                                                                         ***/
    /* *************************************************************************************************************************************/

    event ParticipantSupportedPoolsChanged(address indexed participant, uint256 supportedPools);

    /* *************************************************************************************************************************************/
    /* ** Modifiers                                                                                                                      ***/
    /* *************************************************************************************************************************************/

    modifier onlyPool(address _pool) {
        if (!isPool[_pool]) {
            revert ErrorNotOsmoticPool();
        }

        _;
    }

    constructor(uint256 _version, OsmoticPoolFactory _poolFactory, IStakingFactory _stakingFactory) {
        _disableInitializers();

        version = _version;
        poolFactory = _poolFactory;
        stakingFactory = _stakingFactory;
    }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /* *************************************************************************************************************************************/
    /* ** Pausability Functions                                                                                                          ***/
    /* *************************************************************************************************************************************/

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /* *************************************************************************************************************************************/
    /* ** Upgradeability Functions                                                                                                       ***/
    /* *************************************************************************************************************************************/

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /* *************************************************************************************************************************************/
    /* ** Pool Creation Function                                                                                                       ***/
    /* *************************************************************************************************************************************/

    function createPool(bytes calldata _poolInitPayload) external whenNotPaused returns (address pool_) {
        isPool[pool_ = poolFactory.createOsmoticPool(_poolInitPayload)] = true;
    }

    /* *************************************************************************************************************************************/
    /* ** Locking Functions                                                                                                              ***/
    /* *************************************************************************************************************************************/

    function lockBalance(address _token, uint256 _amount) public whenNotPaused {
        IStaking staking = IStaking(stakingFactory.getOrCreateInstance(_token));

        _lockBalance(staking, msg.sender, _amount);
    }

    function unlockBalance(address _token, uint256 _amount) public whenNotPaused {
        IStaking staking = IStaking(stakingFactory.getInstance(_token));

        _unlockBalance(staking, msg.sender, _amount);
    }

    /* *************************************************************************************************************************************/
    /* ** Locking and Supporting Functions                                                                                               ***/
    /* *************************************************************************************************************************************/

    function lockAndSupport(
        OsmoticPool _pool,
        uint256 _lockedAmount,
        ParticipantSupportUpdate[] calldata _participantUpdates
    ) external whenNotPaused {
        lockBalance(address(_pool.governanceToken()), _lockedAmount);

        _pool.changeProjectSupports(_participantUpdates);
    }

    function unsupportAndUnlock(
        OsmoticPool _pool,
        uint256 _unlockedAmount,
        ParticipantSupportUpdate[] calldata _participantUpdates
    ) external whenNotPaused {
        _pool.changeProjectSupports(_participantUpdates);

        unlockBalance(address(_pool.governanceToken()), _unlockedAmount);
    }

    /* *************************************************************************************************************************************/
    /* ** Participant Supported Pools Functions                                                                                          ***/
    /* *************************************************************************************************************************************/

    function increaseParticipantSupportedPools(address _participant, address _pool)
        external
        whenNotPaused
        onlyPool(_pool)
    {
        participantSupportedPools[_participant]++;

        emit ParticipantSupportedPoolsChanged(_participant, participantSupportedPools[_participant]);
    }

    function decreaseParticipantSupportedPools(address _participant, address _pool)
        external
        whenNotPaused
        onlyPool(_pool)
    {
        participantSupportedPools[_participant]--;

        emit ParticipantSupportedPoolsChanged(_participant, participantSupportedPools[_participant]);
    }

    /* *************************************************************************************************************************************/
    /* ** View Functions                                                                                                                 ***/
    /* *************************************************************************************************************************************/

    /**
     * @dev ILockManager conformance.
     *      The Staking contract checks this on each request to unlock an amount managed by this Controller.
     *      Check the participant amount of supported pools and disable owners from unlocking their funds
     *      arbitrarily, as we want to control the release of the locked amount  when there is no remaining
     *      supported pools.
     * @return Whether the request to unlock tokens of a given owner should be allowed
     */
    function canUnlock(address _user, uint256) external view returns (bool) {
        return participantSupportedPools[_user] == 0;
    }

    function getParticipantStaking(address _participant, address _token) public view returns (uint256) {
        return IStaking(stakingFactory.getInstance(_token)).lockedBalanceOf(_participant);
    }

    /* *************************************************************************************************************************************/
    /* ** Internal Locking Functions                                                                                                     ***/
    /* *************************************************************************************************************************************/

    /**
     * @dev Lock some tokens in the staking pool for a user
     * @param _staking Staking pool for the ERC20 token to be locked
     * @param _user Address of the user to lock tokens for
     * @param _amount Amount of collateral tokens to be locked
     */
    function _lockBalance(IStaking _staking, address _user, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }

        _staking.lock(_user, _amount);
    }

    /**
     * @dev Unlock some tokens in the staking pool for a user
     * @param _staking Staking pool for the ERC20 token to be unlocked
     * @param _user Address of the user to unlock tokens for
     * @param _amount Amount of collateral tokens to be unlocked
     */
    function _unlockBalance(IStaking _staking, address _user, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }

        _staking.unlock(_user, address(this), _amount);
    }
}