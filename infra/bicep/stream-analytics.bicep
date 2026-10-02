param jobName string
param eventHubNamespace string
param eventHubName string
param storageAccountName string
param consumerGroup string = 'asa-cg'
param location string = resourceGroup().location
param cosmosAccountName string
param cosmosDatabase string = 'weather'

var tags = {
  project: 'weather-iot'
  env: 'dev'
}

resource job 'Microsoft.StreamAnalytics/streamingjobs@2020-03-01' = {
  name: jobName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Standard'
    }
    jobType: 'Cloud'
    compatibilityLevel: '1.2'
    dataLocale: 'en-US'
    eventsOutOfOrderPolicy: 'Adjust'
    eventsOutOfOrderMaxDelayInSeconds: 10
    eventsLateArrivalMaxDelayInSeconds: 60
    outputErrorPolicy: 'Drop'
  }
}

resource inWeather 'Microsoft.StreamAnalytics/streamingjobs/inputs@2020-03-01' = {
  parent: job
  name: 'weather_in'
  properties: {
    type: 'Stream'
    datasource: {
      type: 'Microsoft.EventHub/EventHub'
      properties: {
        serviceBusNamespace: eventHubNamespace
        eventHubName: eventHubName
        consumerGroupName: consumerGroup
        authenticationMode: 'Msi'
      }
    }
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
      }
    }
  }
}

resource outBronze 'Microsoft.StreamAnalytics/streamingjobs/outputs@2020-03-01' = {
  parent: job
  name: 'out_bronze'
  properties: {
    datasource: {
      type: 'Microsoft.Storage/Blob'
      properties: {
        storageAccounts: [
          {
            accountName: storageAccountName
          }
        ]
        container: 'bronze'
        pathPattern: 'raw/date={date}/hour={time}'
        dateFormat: 'yyyy-MM-dd'
        timeFormat: 'HH'
        authenticationMode: 'Msi'
      }
    }
    serialization: {
      type: 'Parquet'
      properties: {}
    }
    timeWindow: '00:05:00'
    sizeWindow: 100
  }
}

resource outRolling 'Microsoft.StreamAnalytics/streamingjobs/outputs@2020-03-01' = {
  parent: job
  name: 'out_rolling'
  properties: {
    datasource: {
      type: 'Microsoft.Storage/Blob'
      properties: {
        storageAccounts: [
          {
            accountName: storageAccountName
          }
        ]
        container: 'stream-out'
        pathPattern: 'rolling_avg/date={date}'
        dateFormat: 'yyyy-MM-dd'
        timeFormat: 'HH'
        authenticationMode: 'Msi'
      }
    }
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
        format: 'LineSeparated'
      }
    }
  }
}

resource outAlerts 'Microsoft.StreamAnalytics/streamingjobs/outputs@2020-03-01' = {
  parent: job
  name: 'out_alerts'
  properties: {
    datasource: {
      type: 'Microsoft.Storage/Blob'
      properties: {
        storageAccounts: [
          {
            accountName: storageAccountName
          }
        ]
        container: 'stream-out'
        pathPattern: 'alerts/date={date}'
        dateFormat: 'yyyy-MM-dd'
        timeFormat: 'HH'
        authenticationMode: 'Msi'
      }
    }
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
        format: 'LineSeparated'
      }
    }
  }
}

// Cosmos outputs need the preview API: managed identity for Cosmos output is not in 2020-03-01
resource outAlertsCosmos 'Microsoft.StreamAnalytics/streamingjobs/outputs@2021-10-01-preview' = {
  parent: job
  name: 'out_alerts_cosmos'
  properties: {
    datasource: {
      type: 'Microsoft.Storage/DocumentDB'
      properties: {
        accountId: cosmosAccountName
        database: cosmosDatabase
        collectionNamePattern: 'alerts'
        documentId: 'id'
        authenticationMode: 'Msi'
      }
    }
  }
}

resource outLatestCosmos 'Microsoft.StreamAnalytics/streamingjobs/outputs@2021-10-01-preview' = {
  parent: job
  name: 'out_latest_cosmos'
  properties: {
    datasource: {
      type: 'Microsoft.Storage/DocumentDB'
      properties: {
        accountId: cosmosAccountName
        database: cosmosDatabase
        collectionNamePattern: 'city_metrics'
        documentId: 'id'
        authenticationMode: 'Msi'
      }
    }
  }
}

resource outRollingCosmos 'Microsoft.StreamAnalytics/streamingjobs/outputs@2021-10-01-preview' = {
  parent: job
  name: 'out_rolling_cosmos'
  properties: {
    datasource: {
      type: 'Microsoft.Storage/DocumentDB'
      properties: {
        accountId: cosmosAccountName
        database: cosmosDatabase
        collectionNamePattern: 'city_metrics'
        documentId: 'id'
        authenticationMode: 'Msi'
      }
    }
  }
}

resource transformation 'Microsoft.StreamAnalytics/streamingjobs/transformations@2020-03-01' = {
  parent: job
  name: 'Transformation'
  properties: {
    streamingUnits: 1
    query: loadTextContent('../../streaming/weather-job.asaql')
  }
  dependsOn: [
    inWeather
    outBronze
    outRolling
    outAlerts
    outAlertsCosmos
    outLatestCosmos
    outRollingCosmos
  ]
}

output principalId string = job.identity.principalId
