import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ProjectRegistry as ProjectRegistryEntity,
  Project as ProjectEntity,
  ProjectList as ProjectListEntity,
  ProjectProjectList as ProjectProjectListEntity,
} from "../../generated/schema";
import { OwnableProjectList } from "../../generated/templates/OwnableProjectList/OwnableProjectList";

import { formatAddress, join, ZERO_ADDR } from "./ids";

export function buildProjectRegistryId(projectRegistry: Address): string {
  return formatAddress(projectRegistry);
}

export function buildProjectId(projectRegistry: Address, projectId: BigInt): string {
  return join([formatAddress(projectRegistry), projectId.toString()]);
}

export function buildProjectListId(projectList: Address): string {
  return formatAddress(projectList);
}

export function buildProjectProjectListId(
  projectRegistry: Address,
  projectId: BigInt,
  projectList: Address
): string {
  return join([
    buildProjectId(projectRegistry, projectId),
    formatAddress(projectList),
  ]);
}

export function loadOrCreateProjectRegistryEntity(
  projectRegistry: Address
): ProjectRegistryEntity {
  const projectRegistryId = buildProjectRegistryId(projectRegistry);

  let projectRegistryEntity = ProjectRegistryEntity.load(projectRegistryId);

  if (projectRegistryEntity == null) {
    projectRegistryEntity = new ProjectRegistryEntity(projectRegistryId);
    projectRegistryEntity.version = -1
    projectRegistryEntity.owner = Bytes.fromHexString(ZERO_ADDR)
  }

  return projectRegistryEntity;
}

export function loadOrCreateProjectEntity(
  projectRegistry: Address,
  projectId: BigInt
): ProjectEntity {
  const projectEntityId = buildProjectId(projectRegistry, projectId);

  let projectEntity = ProjectEntity.load(projectEntityId);

  if (projectEntity == null) {
    projectEntity = new ProjectEntity(projectEntityId);
    projectEntity.admin = Bytes.fromHexString(ZERO_ADDR);
    projectEntity.beneficiary = Bytes.fromHexString(ZERO_ADDR);
    projectEntity.contentHash = Bytes.fromHexString(ZERO_ADDR);
    projectEntity.projectRegistry = buildProjectRegistryId(projectRegistry);
  }

  return projectEntity;
}

export function loadOrCreateProjectListEntity(
  projectList: Address
): ProjectListEntity {
  const projectListId = buildProjectListId(projectList);

  let projectListEntity = ProjectListEntity.load(projectListId);

  if (projectListEntity === null) {
    projectListEntity = new ProjectListEntity(projectListId);
    projectListEntity.owner = Bytes.fromHexString(ZERO_ADDR);
    projectListEntity.name = "";
  }

  return projectListEntity;
}

export function loadOrCreateProjectProjectListEntity(
  projectList: Address,
  projectId: BigInt
): ProjectProjectListEntity {
  const projectListContract = OwnableProjectList.bind(projectList);
  const projectRegistry = projectListContract.projectRegistry();
  const projectProjectListId = buildProjectProjectListId(
    projectRegistry,
    projectId,
    projectList
  );

  let projectProjectListEntity = ProjectProjectListEntity.load(projectProjectListId)

  if ( projectProjectListEntity === null) {
    projectProjectListEntity = new ProjectProjectListEntity(projectProjectListId)
    projectProjectListEntity.project = buildProjectId(projectRegistry, projectId)
    projectProjectListEntity.projectList = buildProjectListId(projectList)
  }

  return projectProjectListEntity
}