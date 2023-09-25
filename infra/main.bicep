targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources (filtered on available regions for Azure Open AI Service).')
@allowed(['westeurope','southcentralus','australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth'])
param location string

//Leave blank to use default naming
param openAiServiceName string = ''
param keyVaultName string = ''
param identityName string = ''
param apimServiceName string = ''
param logAnalyticsName string = ''
param applicationInsightsName string = ''
param vnetName string = ''
param apimSubnetName string = ''
param apimNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var openAiSkuName = 'S0'
var chatGptDeploymentName = 'gpt-35'
var chatGptModelName = 'gpt-35-turbo'
var openaiApiKeySecretName = 'openai-apikey'
var tags = { 'env-name': environmentName }

var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'
var keyVaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'
var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'

var privateDnsZoneNames = [
  openAiPrivateDnsZoneName
  keyVaultPrivateDnsZoneName
  monitorPrivateDnsZoneName
]


module dnsDeployment './modules/networking/dns.bicep' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: 'dns-deployment-${privateDnsZoneName}'
  params: {
    name: privateDnsZoneName
  }
}]

module managedIdentity './modules/security/managed-identity.bicep' = {
  name: 'managed-identity'
  params: {
    name: !empty(identityName) ? identityName : 'id-${resourceToken}'
    location: location
    tags: tags
  }
}

module keyVault './modules/security/key-vault.bicep' = {
  name: 'key-vault'
  params: {
    name: !empty(keyVaultName) ? keyVaultName : 'kv-${resourceToken}'
    location: location
    tags: tags
    keyVaultPrivateEndpointName: 'kv-pe-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    managedIdentityName: managedIdentity.outputs.managedIdentityName
    keyVaultDnsZoneName: keyVaultPrivateDnsZoneName
  }
}

module openaiKeyVaultSecret './modules/security/keyvault-secret.bicep' = {
  name: 'openai-keyvault-secret'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    secretName: openaiApiKeySecretName
    openAiName: openAi.outputs.openAiName
  }
}

module vnet './modules/networking/vnet.bicep' = {
  name: 'vnet'
  params: {
    name: !empty(vnetName) ? vnetName : 'vnet-${resourceToken}'
    apimSubnetName: !empty(apimSubnetName) ? apimSubnetName : 'snet-apim-${resourceToken}'
    apimNsgName: !empty(apimNsgName) ? apimNsgName : 'nsg-apim-${resourceToken}'
    privateEndpointSubnetName: !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : 'snet-private-endpoint-${resourceToken}'
    privateEndpointNsgName: !empty(privateEndpointNsgName) ? privateEndpointNsgName : 'nsg-pe-${resourceToken}'
    location: location
    tags: tags
    privateDnsZoneNames: privateDnsZoneNames
  }
}

module monitoring './modules/monitor/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : 'log-${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : 'appins-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    applicationInsightsDnsZoneName: monitorPrivateDnsZoneName
    applicationInsightsPrivateEndpointName: 'appins-pe-${resourceToken}'
  }
}

module eventhub './modules/eventhub/eventhub.bicep' = {
  name: 'eventhub'
  params: {
    location: location
    tags: tags
    eventHubName: 'eh-${resourceToken}'
  }
}

module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  params: {
    name: !empty(apimServiceName) ? apimServiceName : 'apim-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    openaiKeyVaultSecretName: openaiKeyVaultSecret.outputs.keyVaultSecretName
    keyVaultEndpoint: keyVault.outputs.keyVaultEndpoint
    openAiUri: openAi.outputs.openAiEndpointUri
    managedIdentityName: managedIdentity.outputs.managedIdentityName
    apimSubnetId: vnet.outputs.apimSubnetId
    eventHubConnectionString: eventhub.outputs.eventHubConnectionString
    eventHubName: eventhub.outputs.eventHubName
  }
}

module openAi 'modules/openai/cognitiveservices.bicep' = {
  name: 'openai'
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : 'cog-${resourceToken}'
    location: location
    tags: tags
    openAiPrivateEndpointName: 'cog-pe-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    openAiDnsZoneName: openAiPrivateDnsZoneName
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
    ]
  }
}

output TENANT_ID string = subscription().tenantId
output AOI_DEPLOYMENTID string = chatGptDeploymentName
output APIM_NAME string = apim.outputs.apimName
output APIM_AOI_PATH string = apim.outputs.apimOpenaiApiPath
