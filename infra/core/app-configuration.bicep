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

@description('The Azure AI Agent Name')
param azureAiAgentName string

@description('Existing Azure AI Project Endpoint')
param existingAiProjectEndpoint string

@description('Existing Azure AI Agent ID')
param existingAgentId string

@description('Enable Azure Monitor Tracing')
param enableAzureMonitorTracing string

@description('Azure AI Search Connection Name')
param searchConnectionName string = ''

@description('Azure AI Embed Deployment Name')
param embedDeploymentName string = ''

@description('Azure AI Embed Dimensions')
param embedDimensions string = ''

@description('Azure AI Search Index Name')
param searchIndexName string = ''

@description('Azure AI Search Endpoint')
param searchEndpoint string = ''

@description('Azure Tenant ID')
param azureTenantId string = ''

@description('Azure Subscription ID')
param azureSubscriptionId string = ''

@description('Azure Resource Group')
param azureResourceGroup string = ''

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

// Set the AZURE_EXISTING_AIPROJECT_ENDPOINT configuration key
resource existingAiProjectEndpointConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AZURE_EXISTING_AIPROJECT_ENDPOINT'
  parent: appConfig
  properties: {
    value: existingAiProjectEndpoint
  }
}

// Set the AZURE_EXISTING_AGENT_ID configuration key
resource existingAAgentIdConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AZURE_EXISTING_AGENT_ID'
  parent: appConfig
  properties: {
    value: existingAgentId
  }
}

// Set the AZURE_AI_AGENT_NAME configuration key
resource azureAiAgentNameConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AZURE_AI_AGENT_NAME'
  parent: appConfig
  properties: {
    value: azureAiAgentName
  }
}

// Set the ENABLE_AZURE_MONITOR_TRACING configuration key
resource enableAzureMonitorTracingConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'ENABLE_AZURE_MONITOR_TRACING'
  parent: appConfig
  properties: {
    value: enableAzureMonitorTracing
  }
}

// Set the AZURE_AI_SEARCH_CONNECTION_NAME configuration key
resource searchConnectionNameConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (searchConnectionName != '') {
  name: 'AZURE_AI_SEARCH_CONNECTION_NAME'
  parent: appConfig
  properties: {
    value: searchConnectionName
  }
}

// Set the AZURE_AI_EMBED_DEPLOYMENT_NAME configuration key
resource embedDeploymentNameConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (embedDeploymentName != '') {
  name: 'AZURE_AI_EMBED_DEPLOYMENT_NAME'
  parent: appConfig
  properties: {
    value: embedDeploymentName
  }
}

// Set the AZURE_AI_EMBED_DIMENSIONS configuration key
resource embedDimensionsConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (embedDimensions != '') {
  name: 'AZURE_AI_EMBED_DIMENSIONS'
  parent: appConfig
  properties: {
    value: embedDimensions
  }
}

// Set the AZURE_AI_SEARCH_INDEX_NAME configuration key
resource searchIndexNameConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (searchIndexName != '') {
  name: 'AZURE_AI_SEARCH_INDEX_NAME'
  parent: appConfig
  properties: {
    value: searchIndexName
  }
}

// Set the AZURE_AI_SEARCH_ENDPOINT configuration key
resource searchEndpointConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (searchEndpoint != '') {
  name: 'AZURE_AI_SEARCH_ENDPOINT'
  parent: appConfig
  properties: {
    value: searchEndpoint
  }
}

// Set the AZURE_TENANT_ID configuration key
resource azureTenantIdConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (azureTenantId != '') {
  name: 'AZURE_TENANT_ID'
  parent: appConfig
  properties: {
    value: azureTenantId
  }
}

// Set the AZURE_SUBSCRIPTION_ID configuration key
resource azureSubscriptionIdConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (azureSubscriptionId != '') {
  name: 'AZURE_SUBSCRIPTION_ID'
  parent: appConfig
  properties: {
    value: azureSubscriptionId
  }
}

// Set the AZURE_RESOURCE_GROUP configuration key
resource azureResourceGroupConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if (azureResourceGroup != '') {
  name: 'AZURE_RESOURCE_GROUP'
  parent: appConfig
  properties: {
    value: azureResourceGroup
  }
}

output name string = appConfig.name
output id string = appConfig.id
output endpoint string = appConfig.properties.endpoint
