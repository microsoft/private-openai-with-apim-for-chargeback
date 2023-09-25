param eventHubName string
param location string = resourceGroup().location
param tags object = {}
param eventHubSku string = 'Standard'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
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

//Create connectionstring
var eventHubConnectionString = listKeys(eventHubListenSendRule.id, eventHubListenSendRule.apiVersion).primaryConnectionString

//output connectionstring
output eventHubConnectionString string = eventHubConnectionString

//output eventHubName
output eventHubName string = eventHub.name
