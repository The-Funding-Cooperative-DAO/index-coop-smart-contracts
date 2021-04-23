/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { AddressArrayUtils } from "../lib/AddressArrayUtils.sol";

import { IManagerIssuanceHook } from "../interfaces/IManagerIssuanceHook.sol";
import { ISetToken } from "../interfaces/ISetToken.sol";


/**
 * @title SupplyCapAllowedCallerIssuanceHook
 * @author Set Protocol
 *
 * Issuance hook that checks new issuances won't push SetToken totalSupply over supply cap and checks if caller is allowed
 */
contract SupplyCapAllowedCallerIssuanceHook is Ownable, IManagerIssuanceHook {
    using SafeMath for uint256;
    using AddressArrayUtils for address[];

    /* ============ Events ============ */

    event SupplyCapUpdated(uint256 _newCap);
    event CallerStatusUpdated(address indexed _caller, bool _status);
    event AnyoneCallableUpdated(bool indexed _status);
    
    /* ============ State Variables ============ */

    // Cap on totalSupply of Sets
    uint256 public supplyCap;

    // Boolean indicating if anyone can call function
    bool public anyoneCallable;

    // Mapping of addresses allowed to call function
    mapping(address => bool) public callAllowList;

    /* ============ Constructor ============ */

    /**
     * Constructor, overwrites owner and original supply cap.
     *
     * @param _initialOwner      Owner address, overwrites Ownable logic which sets to deployer as default
     * @param _supplyCap         Supply cap for Set (in wei of Set)
     */
    constructor(
        address _initialOwner,
        uint256 _supplyCap
    )
        public
    {
        supplyCap = _supplyCap;

        // Overwrite _owner param of Ownable contract
        transferOwnership(_initialOwner);
    }

    /* ============ External Functions ============ */

    /**
     * Adheres to IManagerIssuanceHook interface, and checks to make sure the current issue call won't push total supply over cap.
     */
    function invokePreIssueHook(
        ISetToken _setToken,
        uint256 _issueQuantity,
        address _sender,
        address /*_to*/
    )
        external
        override
    {
        uint256 totalSupply = _setToken.totalSupply();
        require(totalSupply.add(_issueQuantity) <= supplyCap, "Supply cap exceeded");

        _validateAllowedCaller(_sender);
    }

    /**
     * Adheres to IManagerIssuanceHook interface
     */
    function invokePreRedeemHook(
        ISetToken /* _setToken */,
        uint256 /* _redeemQuantity */,
        address _sender,
        address /* _to */
    )
        external
        override
    {
        _validateAllowedCaller(_sender);
    }

    /**
     * ONLY OWNER: Updates supply cap
     */
    function updateSupplyCap(uint256 _newCap) external onlyOwner {
        supplyCap = _newCap;
        SupplyCapUpdated(_newCap);
    }

    /**
     * ONLY OWNER: Toggle ability for passed addresses to call only allowed caller functions
     *
     * @param _callers           Array of caller addresses to toggle status
     * @param _statuses          Array of statuses for each caller
     */
    function updateCallerStatus(address[] calldata _callers, bool[] calldata _statuses) external onlyOwner {
        require(_callers.length == _statuses.length, "Array length mismatch");
        require(_callers.length > 0, "Array length must be > 0");
        require(!_callers.hasDuplicate(), "Cannot duplicate callers");

        for (uint256 i = 0; i < _callers.length; i++) {
            address caller = _callers[i];
            bool status = _statuses[i];
            callAllowList[caller] = status;
            emit CallerStatusUpdated(caller, status);
        }
    }

    /**
     * ONLY OWNER: Toggle whether anyone can call function, bypassing the callAllowlist 
     *
     * @param _status           Boolean indicating whether to allow anyone call
     */
    function updateAnyoneCallable(bool _status) external onlyOwner {
        anyoneCallable = _status;
        emit AnyoneCallableUpdated(_status);
    }

    /* ============ Internal Functions ============ */

    /**
     * Validate if passed address is allowed to call function. If anyoneCallable set to true anyone can call otherwise needs to be approved or an EOA.
     */
    function _validateAllowedCaller(address _caller) internal view {
        bool isEOA = msg.sender == tx.origin;

        require(anyoneCallable || isEOA || callAllowList[_caller], "Address not permitted to call");
    }
}