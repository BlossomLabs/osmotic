// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableUpgradeable} from "@oz-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IProjectList, Project} from "../interfaces/IProjectList.sol";

error BeneficiaryNotProvided();
error BeneficiaryAlreadyExists(address beneficiary);
error ProjectDoesNotExist(uint256 projectId);

contract ProjectRegistry is Initializable, OwnableUpgradeable, UUPSUpgradeable, IProjectList {
    uint256 public immutable version;

    mapping(uint256 => Project) projects;
    mapping(address => bool) internal registeredBeneficiaries;

    uint256 nextProjectId;

    event ProjectUpdated(uint256 indexed projectId, address beneficiary, bytes contenthash);

    modifier isValidBeneficiary(address _beneficiary) {
        if (_beneficiary == address(0)) {
            revert BeneficiaryNotProvided();
        }

        if (registeredBeneficiaries[_beneficiary]) {
            revert BeneficiaryAlreadyExists(_beneficiary);
        }

        _;
    }

    constructor(uint256 _version) {
        version = _version;
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        nextProjectId = 1;
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function registrerProject(address _beneficiary, bytes calldata _contenthash)
        external
        returns (uint256 _projectId)
    {
        _projectId = nextProjectId++;

        _updateProject(_projectId, _beneficiary, _contenthash);
    }

    function updateProject(uint256 _projectId, address _beneficiary, bytes calldata _contenthash) external {
        _updateProject(_projectId, _beneficiary, _contenthash);
    }

    function _updateProject(uint256 _projectId, address _beneficiary, bytes calldata _contenthash)
        internal
        isValidBeneficiary(_beneficiary)
    {
        Project memory oldProject = projects[_projectId];

        registeredBeneficiaries[oldProject.beneficiary] = false;

        projects[_projectId] = Project({beneficiary: _beneficiary, contenthash: _contenthash});
        registeredBeneficiaries[_beneficiary] = true;

        emit ProjectUpdated(_projectId, _beneficiary, _contenthash);
    }

    function getProject(uint256 _projectId) public view returns (Project memory) {
        return projects[_projectId];
    }

    function projectExists(uint256 _projectId) external view returns (bool) {
        return projects[_projectId].beneficiary != address(0);
    }
}