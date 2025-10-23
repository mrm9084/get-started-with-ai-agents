metadata description = 'Creates an Azure App Configuration store.'
param name string
param location string = resourceGroup().location
param tags object = {}

@description('The SKU of the configuration store')
@allowed(['free', 'standard'])
param sku string = 'free'

@description('The identity to assign to the App Configuration store')
param principalId string = ''

resource appConfigStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    disableLocalAuth: false
    softDeleteRetentionInDays: 1
    enablePurgeProtection: false
  }
}

// Assign App Configuration Data Reader role to the specified principal
resource appConfigDataReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(appConfigStore.id, principalId, 'b5db35f7-d661-4e36-9642-c8779c78eef4')
  scope: appConfigStore
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b5db35f7-d661-4e36-9642-c8779c78eef4') // App Configuration Data Reader
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output id string = appConfigStore.id
output name string = appConfigStore.name
output endpoint string = appConfigStore.properties.endpoint
