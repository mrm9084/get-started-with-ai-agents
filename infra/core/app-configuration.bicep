@description('The name of the App Configuration store')
param name string

@description('The location of the App Configuration store')
param location string = resourceGroup().location

@description('The tags to apply to the App Configuration store')
param tags object = {}

@description('The SKU of the App Configuration store')
@allowed(['Free', 'Standard'])
param sku string = 'Standard'

@description('The Azure AI Agent Model Name')
param agentModelName string

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {}
}

// Set the AZURE_AI_AGENT_MODEL_NAME configuration key
resource agentModelNameConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AZURE_AI_AGENT_MODEL_NAME'
  parent: appConfig
  properties: {
    value: agentModelName
  }
}

output name string = appConfig.name
output id string = appConfig.id
output endpoint string = appConfig.properties.endpoint