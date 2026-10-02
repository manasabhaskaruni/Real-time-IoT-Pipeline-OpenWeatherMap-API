param workspaceName string
param storageAccountName string
param filesystemName string = 'synapse'
param adminObjectId string
param adminLogin string
param clientIp string
param location string = resourceGroup().location

var tags = {
  project: 'weather-iot'
  env: 'dev'
}

var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storage
  name: 'default'
}

resource synapseFilesystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: filesystemName
  properties: {
    publicAccess: 'None'
  }
}

resource goldFilesystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  parent: blobService
  name: 'gold'
}

resource workspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: 'https://${storage.name}.dfs.${environment().suffixes.storage}'
      filesystem: synapseFilesystem.name
    }
    azureADOnlyAuthentication: true
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlAdministrator 'Microsoft.Synapse/workspaces/administrators@2021-06-01' = {
  parent: workspace
  name: 'activeDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: adminLogin
    sid: adminObjectId
    tenantId: tenant().tenantId
  }
}

resource firewallMyIp 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: workspace
  name: 'allow-my-ip'
  properties: {
    startIpAddress: clientIp
    endIpAddress: clientIp
  }
}

resource workspaceFilesystemRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(synapseFilesystem.id, workspace.id, storageBlobDataContributorRoleId)
  scope: synapseFilesystem
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Allow the Synapse workspace identity to use its default filesystem.'
  }
}

resource goldReadRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(goldFilesystem.id, workspace.id, storageBlobDataReaderRoleId)
  scope: goldFilesystem
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: workspace.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Allow serverless SQL to read curated gold Delta tables.'
  }
}

output workspaceId string = workspace.id
output sqlOnDemandEndpoint string = '${workspace.name}-ondemand.sql.azuresynapse.net'
output workspacePrincipalId string = workspace.identity.principalId
output filesystemName string = synapseFilesystem.name
