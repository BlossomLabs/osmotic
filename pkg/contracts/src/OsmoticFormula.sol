// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {ABDKMath64x64} from "abdk-libraries/ABDKMath64x64.sol";

abstract contract OsmoticFormula is Initializable {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // Shift to left to leave space for decimals
    int128 private constant ONE = 1 << 64;

    int128 public decay;
    int128 public drop;
    int128 public maxFlow;
    int128 public minStakeRatio;

    event OsmoticParamsChanged(uint256 decay, uint256 drop, uint256 maxFlow, uint256 minStakeRatio);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __OsmoticFormula_init(uint256 _decay, uint256 _drop, uint256 _maxFlow, uint256 _minStakeRatio)
        internal
        onlyInitializing
    {
        _setOsmoticParams(_decay, _drop, _maxFlow, _minStakeRatio);
    }

    function _setOsmoticParams(uint256 _decay, uint256 _drop, uint256 _maxFlow, uint256 _minStakeRatio) internal {
        decay = _decay.divu(1e18).add(1);
        drop = _drop.divu(1e18).add(1);
        maxFlow = _maxFlow.divu(1e18).add(1);
        minStakeRatio = _minStakeRatio.divu(1e18).add(1);

        emit OsmoticParamsChanged(_decay, _drop, _maxFlow, _minStakeRatio);
    }

    function minStake(uint256 _totalStaked) public view returns (uint256) {
        return minStakeRatio.mulu(_totalStaked);
    }

    /**
     * @dev targetRate = (1 - sqrt(minStake / min(staked, minStake))) * maxFlow * funds
     */
    function calculateTargetRate(uint256 _funds, uint256 _stake, uint256 _totalStaked)
        public
        view
        returns (uint256 _targetRate)
    {
        if (_stake == 0) {
            _targetRate = 0;
        } else {
            uint256 _minStake = minStake(_totalStaked);
            _targetRate =
                (ONE.sub(_minStake.divu(_stake > _minStake ? _stake : _minStake).sqrt())).mulu(maxFlow.mulu(_funds));
        }
    }

    /**
     * @notice Get current
     * @dev rate = (alpha ^ time * lastRate + _targetRate * (1 - alpha ^ time)
     */
    function calculateRate(uint256 _timePassed, uint256 _lastRate, uint256 _targetRate) public view returns (uint256) {
        int128 at = decay.pow(_timePassed);
        return at.mulu(_lastRate) + (ONE.sub(at).mulu(_targetRate)); // No need to check overflow on solidity >=0.8.0
    }
}