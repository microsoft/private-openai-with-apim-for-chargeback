param eventHubName string
param location string = resourceGroup().location
param tags object = {}
param eventHubSku string = 'Standard'

param eventHubPrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param eventHubDnsZoneName string

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: '${eventHubName}-ns'
  location: location
  tags: union(tags, { 'service-name': eventHubName })
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    publicNetworkAccess: 'Disabled'
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

resource eventHubListenSendRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' = {
  parent: eventHub
  name: 'ListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
  dependsOn: [
    eventHubNamespace
  ]
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${eventHubName}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'namespace'
    ]
    dnsZoneName: eventHubDnsZoneName
    name: eventHubPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: eventHubNamespace.id
    vNetName: vNetName
    location: location
  }
}

//Create connectionstring
var eventHubConnectionString = listKeys(eventHubListenSendRule.id, eventHubListenSendRule.apiVersion).primaryConnectionString

//output connectionstring
output eventHubConnectionString string = eventHubConnectionString

//output eventHubName
output eventHubName string = eventHub.name
