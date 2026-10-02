param factoryName string
param workspaceUrl string
param workspaceResourceId string
param jobId string
param startTime string
param location string = resourceGroup().location

var tags = {
  project: 'weather-iot'
  env: 'dev'
}

resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: factoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
}

// Managed identity authentication: no token or password
resource lsDatabricks 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  parent: factory
  name: 'ls_databricks'
  properties: {
    type: 'AzureDatabricks'
    typeProperties: {
      domain: workspaceUrl
      authentication: 'MSI'
      workspaceResourceId: workspaceResourceId
    }
  }
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  parent: factory
  name: 'pl_weather_daily'
  properties: {
    activities: [
      any({
        name: 'run_weather_daily_job'
        type: 'DatabricksJob'
        dependsOn: []
        policy: {
          timeout: '0.02:00:00'
          retry: 1
          retryIntervalInSeconds: 300
        }
        typeProperties: {
          jobId: jobId
          jobParameters: {
            lookback_days: '2'
          }
        }
        linkedServiceName: {
          referenceName: lsDatabricks.name
          type: 'LinkedServiceReference'
        }
      })
    ]
  }
}

// Every day at 01:00 UTC (06:30 IST)
resource trigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  parent: factory
  name: 'tr_daily_0100_utc'
  properties: {
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Day'
        interval: 1
        startTime: startTime
        timeZone: 'UTC'
        schedule: {
          hours: [
            1
          ]
          minutes: [
            0
          ]
        }
      }
    }
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline.name
          type: 'PipelineReference'
        }
      }
    ]
  }
}

output principalId string = factory.identity.principalId
