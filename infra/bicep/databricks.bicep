param workspaceName string
param connectorName string
param location string = resourceGroup().location
param managedRgName string = '${workspaceName}-managed-rg'

var tags = {
  project: 'weather-iot'
  env: 'dev'
}

// Premium is required for Unity Catalog
resource workspace 'Microsoft.Databricks/workspaces@2024-05-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: 'premium'
  }
  properties: {
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedRgName)
  }
}

// Managed identity that Unity Catalog uses to reach the data lake
resource connector 'Microsoft.Databricks/accessConnectors@2024-05-01' = {
  name: connectorName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
}

output workspaceUrl string = workspace.properties.workspaceUrl
output connectorId string = connector.id
output connectorPrincipalId string = connector.identity.principalId
