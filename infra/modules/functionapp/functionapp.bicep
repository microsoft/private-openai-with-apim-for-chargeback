
param functionAppName string 
param tags object = {}
param azdserviceName string
param storageAccountName string

param functionAppIdentityName string

param applicationInsightsName string
param eventHubNamespace string
param eventHubName string
param vnetName string
param functionAppSubnetId string


param location string = resourceGroup().location

param functionPlanOS string= 'Linux'
param functionRuntime string = 'dotnet-isolated'
param linuxFxVersion string = 'DOTNET-ISOLATED|6.0'
var isReserved = functionPlanOS == 'Linux'


resource functionAppmanagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: functionAppIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'hosting-plan-${functionAppName}'
  tags: union(tags, { 'azd-service-name': 'hosting-plan-${functionAppName}' })
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    family: 'EP'
  }
  kind: 'elastic'
  properties: {    
    reserved: isReserved    
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: union(tags, { 'azd-service-name': azdserviceName })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionAppmanagedIdentity.id}': {}
    }
  }
  properties: {
    enabled: true
    serverFarmId: hostingPlan.id
    reserved: isReserved
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      detailedErrorLoggingEnabled: true
      vnetRouteAllEnabled: true  
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      minimumElasticInstanceCount: 1      
      vnetName: vnetName   
      publicNetworkAccess: 'Enabled'  
      functionsRuntimeScaleMonitoringEnabled: true 
    }    
    virtualNetworkSubnetId: functionAppSubnetId    
  }
}

// Add the function to the subnet
resource networkConfig 'Microsoft.Web/sites/networkConfig@2022-03-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: functionAppSubnetId
    swiftSupported: true
  }
}

resource functionAppSettings 'Microsoft.Web/sites/config@2020-12-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      //AzureWebJobsStorage: storageAccountConnectionString
      AzureWebJobsStorage__accountname: storageAccountName      
      FUNCTIONS_EXTENSION_VERSION:  '~4'
      FUNCTIONS_WORKER_RUNTIME: functionRuntime
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
      WEBSITE_CONTENTSHARE: toLower(functionAppName)
      WEBSITE_VNET_ROUTE_ALL: '1'    
      
      //EventHub Input Trigger Settings With Managed Identity
      //https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference?tabs=eventhubs&pivots=programming-language-csharp#common-properties-for-identity-based-connections
      EventHubConnection__clientId: functionAppmanagedIdentity.properties.clientId
      EventHubConnection__credential: 'managedidentity'
      EventHubConnection__fullyQualifiedNamespace: '${eventHubNamespace}.servicebus.windows.net'
      EventHubName: eventHubName
  }  
}


