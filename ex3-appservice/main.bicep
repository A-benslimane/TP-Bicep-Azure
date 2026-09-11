param prefix string = 'abdel'
param location string = resourceGroup().location

var planName = '${prefix}-appservice-plan'
var webAppName = '${prefix}-web-${uniqueString(resourceGroup().id)}'

// =======================
// APP SERVICE PLAN
// =======================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location

  sku: {
    name: 'S1'
    tier: 'Standard'
    capacity: 1
  }

  kind: 'linux'

  properties: {
    reserved: true
  }
}

// =======================
// WEB APP
// =======================

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location

  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true

    siteConfig: {
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/azuredocs/aci-helloworld:latest'

      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '80'
        }
      ]
    }
  }
}

// =======================
// SLOT STAGING
// =======================

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: webApp
  name: 'staging'
  location: location

  properties: {
    serverFarmId: appServicePlan.id

    siteConfig: {
      linuxFxVersion: 'DOCKER|nginx:alpine'

      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '80'
        }
      ]
    }
  }
}

// =======================
// OUTPUTS
// =======================

output webAppName string = webApp.name
output productionUrl string = 'https://${webApp.properties.defaultHostName}'
output stagingUrl string = 'https://${webApp.name}-staging.azurewebsites.net'
