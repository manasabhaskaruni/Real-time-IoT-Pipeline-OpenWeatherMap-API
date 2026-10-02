param accountName string
param location string = resourceGroup().location
@allowed([
  'free'
  'serverless'
])
param capacityMode string = 'free'
param databaseName string = 'weather'

var tags = {
  project: 'weather-iot'
  env: 'dev'
}

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: capacityMode == 'free'
    disableLocalAuth: true // Entra ID only, no account keys
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: capacityMode == 'serverless' ? [
      {
        name: 'EnableServerless'
      }
    ] : []
  }
}

// 400 RU/s shared by all containers (free tier). Serverless has no provisioned throughput.
resource db 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: capacityMode == 'free' ? {
      throughput: 400
    } : {}
  }
}

// Alerts: partition key city_id, auto-delete after 30 days, only index what we query
resource alerts 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: 'alerts'
  properties: {
    resource: {
      id: 'alerts'
      partitionKey: {
        paths: [
          '/city_id'
        ]
        kind: 'Hash'
        version: 2
      }
      defaultTtl: 2592000
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/city_id/?'
          }
          {
            path: '/alert_type/?'
          }
          {
            path: '/alert_ts/?'
          }
        ]
        excludedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
  }
}

// City metrics: one "latest" and one "rolling60" document per city, upserted by ASA
resource metrics 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: 'city_metrics'
  properties: {
    resource: {
      id: 'city_metrics'
      partitionKey: {
        paths: [
          '/city_id'
        ]
        kind: 'Hash'
        version: 2
      }
      defaultTtl: 604800
    }
  }
}

output endpoint string = account.properties.documentEndpoint
