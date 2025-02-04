targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'westus3', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string


// SETUP/INIT  =============================================================

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
param uploadDataServiceName string = ''
param uploadDataAppServicePlanName string = ''
param orchestrateIngestionServiceName string = ''
param orchestrateIngestionAppServicePlanName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param storageAccountName string = ''
param serviceBusNamespaceName string = ''
param vNetName string = ''
param resourceGroupName string = ''
param uploadDataUserAssignedIdentityName string = ''
param orchestrateUserAssignedIdentityName string = ''
param uxServiceName string = ''
param uxAppServicePlanName string = ''
param uxUserAssignedIdentityName string = ''
param staticWebsiteName string = ''

param postgreSQLAdministratorLogin string = 'myadmin'
@secure()
param postgreSQLAdministratorPassword string

@description('Additional id of the user or app to assign application roles to access the secured resources in this template.')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
// Generate unique function app names if one is not provided.
var uploadDataAppName = !empty(uploadDataServiceName) ? uploadDataServiceName : '${abbrs.webSitesFunctions}uploaddata-${resourceToken}'
var orchestrateIngestionAppName = !empty(orchestrateIngestionServiceName) ? orchestrateIngestionServiceName : '${abbrs.webSitesFunctions}orchestrateingest-${resourceToken}'
var uxAppName = !empty(uxServiceName) ? uxServiceName : '${abbrs.webSitesFunctions}ux-${resourceToken}'
// Generate a unique storage container name that will be used for Function App deployments.
var uploadDataDeploymentStorageContainerName = 'app-package-uploaddata-${take(resourceToken, 7)}'
var orchestrateIngestionDeploymentStorageContainerName = 'app-package-orchestrateingest-${take(resourceToken, 7)}'
var uxStorageContainerName = 'app-package-ux-${take(resourceToken, 7)}'
var dataUploadContanerName = 'data-${take(resourceToken, 7)}'
var singleLineServiceBusQueueName = '${abbrs.serviceBusNamespacesQueues}singleline-${resourceToken}'
var fullFileServiceBusQueueName = '${abbrs.serviceBusNamespacesQueues}fullfile-${resourceToken}'
var shareName = 'openaifiles'
// we use this as a marker to check for resource existence
var tagName = 'resourcesExist'

// ACA variables
var acrName = 'acr${resourceToken}'
var acaEnvName = 'aca-env-${resourceToken}'
//var sessionPoolName = 'aca-session-${resourceToken}'

// TODO: figure out how we can weave this into both functions as well as ACA
//      maybe we use monitor instead of log analytics
//var logAnalyticsWorkspaceName = 'log-lab-loganalytics-${uniqueString(resourceGroup().id)}'

// openAI vars
var openAIAccountName = 'openai-${resourceToken}'
var postgresSqlName = 'stats-data-${resourceToken}'

// Azure Search vars
param searchServiceName string = ''
@allowed([ 'free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2' ])
param searchServiceSkuName string
param searchServiceIndexName string

//Load Testing vars
var altResName = '${abbrs.loadtesting}${resourceToken}'
var profileMappingName = guid(toLower(uniqueString(subscription().id, altResName)))
var testProfileId = '${abbrs.loadtestingProfiles}${guid(toLower(uniqueString(subscription().id, altResName)))}'
var loadtestTestId = '${abbrs.loadtestingTests}${guid(toLower(uniqueString(subscription().id, altResName)))}'

// END SETUP/INIT  =============================================================


// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}


// TODO: this might have to be generated explicitly for ACA
//resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
//  name: logAnalyticsWorkspaceName
//  location: resourceGroup().location
//  properties: any({
//    retentionInDays: 30
//    features: {
//      searchVersion: 1
//    }
//    sku: {
//      name: 'PerGB2018'
//    }
//  })
//}


// OPENAI RESOURCES =============================================================

// openAI account, llm and embedding model
module openAIModule 'app/openai.bicep' = {
  scope: rg
  name: openAIAccountName
  params: {
    openAIAccountName: openAIAccountName
    azureOpenAILocation: location
  }
}
var openAIAccount = openAIModule.outputs.openAIAccount

module searchService 'app/search-services.bicep' = {
  name: 'search-service'
  scope: rg
  params: {
    name: !empty(searchServiceName) ? searchServiceName : 'gptkb-${resourceToken}'
    location: location
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'free'
  }
}
// AZURE OPENAI RESOURCES =============================================================


// FUNCTION RESOURCES =============================================================

// Create a separate app service plan for each of the Flex Consumption apps (Flex Consumption apps don't share app service plans)
module uploadDataAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'uploadDataAppServicePlan'
  scope: rg
  params: {
    name: !empty(uploadDataAppServicePlanName) ? uploadDataAppServicePlanName : '${abbrs.webServerFarms}uploaddata${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

module orchestrateIngestionAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'orchestrateIngestionAppServicePlan'
  scope: rg
  params: {
    name: !empty(orchestrateIngestionAppServicePlanName) ? orchestrateIngestionAppServicePlanName : '${abbrs.webServerFarms}orchestrateingest${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

module uxAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'uxAppServicePlan'
  scope: rg
  params: {
    name: !empty(uxAppServicePlanName) ? uxAppServicePlanName : '${abbrs.webServerFarms}ux${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module uploadDataUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'uploadDataAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(uploadDataUserAssignedIdentityName) ? uploadDataUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}uploaddata-${resourceToken}'
  }
}

// The upload data application backend powered by Azure Functions Flex Consumption
module uploadData './app/app.bicep' = {
  name: 'uploaddata'
  scope: rg
  params: {
    name: uploadDataAppName
    serviceName: 'uploaddata'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: uploadDataAppServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    instanceMemoryMB: 2048
    maximumInstanceCount: 250
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: uploadDataDeploymentStorageContainerName
    dataUploadContanerName: dataUploadContanerName
    identityId: uploadDataUserAssignedIdentity.outputs.identityId
    identityClientId: uploadDataUserAssignedIdentity.outputs.identityClientId
    appSettings: {
    }
    alwaysReady:[
      {
        name: 'http'
        instanceCount: 1
      }
    ]
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.uploadDataSubnetID
    singleLineServiceBusQueueName: singleLineServiceBusQueueName
    fullFileServiceBusQueueName: fullFileServiceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
  }
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module orchestrateUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'orchestrateAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(orchestrateUserAssignedIdentityName) ? orchestrateUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}orchestrate-${resourceToken}'
  }
}

// The orchestration data application backend powered by Azure Functions Flex Consumption
module orchestrateIngestion './app/app.bicep' = {
  name: 'orchestrateingest'
  scope: rg
  params: {
    name: orchestrateIngestionAppName
    serviceName: 'orchestrateingest'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: orchestrateIngestionAppServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    instanceMemoryMB: 2048
    maximumInstanceCount: 250
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: orchestrateIngestionDeploymentStorageContainerName
    dataUploadContanerName: dataUploadContanerName
    identityId: orchestrateUserAssignedIdentity.outputs.identityId
    identityClientId: orchestrateUserAssignedIdentity.outputs.identityClientId
    appSettings: {
      BATCH_SIZE : 1000
      SUB_BATCH_SIZE : 100
      DATABASE_ENDPOINT: postgreSQL.outputs.endpoint
    }
    alwaysReady:[
      {
        name: 'durable'
        instanceCount: 1
      }
    ]
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.orchestrateIngestionSubnetID
    singleLineServiceBusQueueName: singleLineServiceBusQueueName
    fullFileServiceBusQueueName: fullFileServiceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
  }
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module uxUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'uxAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(uxUserAssignedIdentityName) ? uxUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}ux-${resourceToken}'
  }
}

// The upload data application backend powered by Azure Functions Flex Consumption
module ux './app/app.bicep' = {
  name: 'ux'
  scope: rg
  params: {
    name: uxAppName
    serviceName: 'ux'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: uxAppServicePlan.outputs.id
    runtimeName: 'dotnet-isolated'
    runtimeVersion: '8.0'
    instanceMemoryMB: 2048
    maximumInstanceCount: 250
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: uxStorageContainerName
    identityId: uxUserAssignedIdentity.outputs.identityId
    identityClientId: uxUserAssignedIdentity.outputs.identityClientId
    appSettings: {
      BATCH_SIZE : 1000
      SUB_BATCH_SIZE : 100
      AZURE_CLIENT_ID: uxUserAssignedIdentity.outputs.identityClientId
      AzureWebJobsStorage__blobServiceUri: storage.outputs.primaryEndpoints.blob
      AzureWebJobsStorage__tableServiceUri: storage.outputs.primaryEndpoints.table
      AzureWebJobsStorage__queueServiceUri: storage.outputs.primaryEndpoints.queue
      OpenAiStorageConnection__blobServiceUri: storage.outputs.primaryEndpoints.blob
      OpenAiStorageConnection__tableServiceUri: storage.outputs.primaryEndpoints.table
      OpenAiStorageConnection__queueServiceUri: storage.outputs.primaryEndpoints.queue
      OpenAiStorageConnection__clientId: uxUserAssignedIdentity.outputs.identityClientId
      OpenAiStorageConnection__credential: 'managedidentity'
      AZURE_OPENAI_SERVICE: openAIModule.outputs.openAIAccount.properties.customSubDomainName
      AZURE_OPENAI_ENDPOINT: 'https://${openAIModule.outputs.openAIAccount.properties.customSubDomainName}.openai.azure.com/'
      AZURE_OPENAI_CHATGPT_DEPLOYMENT: openAIModule.outputs.llmmodelName
      AZURE_OPENAI_EMB_DEPLOYMENT: openAIModule.outputs.embeddingsModelName
      SYSTEM_PROMPT: 'You are a helpful assistant. You are responding to requests from a user about internal emails and documents. You can and should refer to the internal documents to help respond to requests. If a user makes a request thats not covered by the documents provided in the query, you must say that you do not have access to the information and not try and get information from other places besides the documents provided. The following is a list of documents that you can refer to when answering questions. The documents are in the format [filename]: [text] and are separated by newlines. If you answer a question by referencing any of the documents, please cite the document in your answer. For example, if you answer a question by referencing info.txt, you should add "Reference: info.txt" to the end of your answer on a separate line.'
      AZURE_SEARCH_SERVICE: searchService.outputs.name
      AZURE_SEARCH_ENDPOINT: 'https://${searchService.outputs.name}.search.windows.net'
      AZURE_SEARCH_INDEX: searchServiceIndexName
      fileShare: '/mounts/${shareName}'
      SPORTS_SERVICE_URL: baseballAgentModule.outputs.baseballAgentUri
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.uxSubnetID
    singleLineServiceBusQueueName: singleLineServiceBusQueueName
    fullFileServiceBusQueueName: fullFileServiceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
  }
}
// END FUNCTION RESOURCES =============================================================

module staticwebsite 'core/host/staticwebsite.bicep' = {
  scope: rg
  name: 'website'
  params: {
    name: !empty(staticWebsiteName) ? staticWebsiteName : '${abbrs.webStaticSites}${resourceToken}'
    location: location
    sku: 'Standard'
    backendResourceId: ux.outputs.SERVICE_API_RESOURCE_ID
  }
}

// STORAGE RESOURCES =============================================================

// Backing storage for Azure functions backend API
module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
    containers: [{name: uploadDataDeploymentStorageContainerName}, {name: orchestrateIngestionDeploymentStorageContainerName}, {name: dataUploadContanerName}, {name: uxStorageContainerName}]
  }
}

// our function principal ids (will also be used for service bus below)
var principalIds = [uploadData.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, orchestrateIngestion.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, ux.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, principalId]

// Allow access from apps to storage account using managed identity
//Storage Blob Data Owner, Storage Blob Data Contributor, Storage Table Data Contributor, Storage Queue Data Contributor
var storageRoleIds = ['b7e6dc6d-f1e8-4753-8033-0f276bb0955b', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3', '974c5e8b-45b9-4653-ba55-5f855dd0fb88']
module storageRoleAssignments 'app/storage-Access.bicep' = [for roleId in storageRoleIds: {
  name: 'blobRole${roleId}'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleId: roleId
    principalIds: principalIds
  }
}]
// END STORAGE RESOURCES =============================================================


// SERVICE BUS RESOURCES =============================================================

module serviceBus 'core/message/servicebus.bicep' = {
  name: 'serviceBus'
  scope: rg
  params: {
    location: location
    tags: tags
    serviceBusNamespaceName: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    queues: [singleLineServiceBusQueueName, fullFileServiceBusQueueName]
  }
}

var ServiceBusRoleDefinitionIds  = ['090c5cfd-751d-490a-894a-3ce6f1109419', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'] //Azure Service Bus Data Owner and Data Receiver roles
// Allow access from processor to Service Bus using a managed identity and Azure Service Bus Data Owner and Data Receiver roles
module ServiceBusDataOwnerRoleAssignment 'app/servicebus-Access.bicep' = [for roleId in ServiceBusRoleDefinitionIds: {
  name: 'sbRoleAssignment${roleId}'
  scope: rg
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespace
    roleDefinitionId: roleId
    principalIds: principalIds
  }
}]
// SERVICE BUS RESOURCES =============================================================


// NETWORK RESOURCES =============================================================
// Vnets, private endpoints


// Virtual Network & private endpoint
module serviceVirtualNetwork 'app/vnet.bicep' = {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
  }
}

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.storageSubnetName
    resourceName: storage.outputs.name
  }
}

module servicePrivateEndpoint 'app/servicebus-privateEndpoint.bicep' = {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.servicebusSubnetName
    sbNamespaceId: serviceBus.outputs.namespaceId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}
// END NETWORK RESOURCES =============================================================



// POSTGRESQL RESOURCES =============================================================

module postgreSQLPrivateDnsZone './app/postgreSQL-privateDnsZone.bicep' = {
  name: 'postgreSQLPrivateDnsZone'
  scope: rg
  params: {
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    tags: tags
  }
}

module postgreSQL './core/database/postgresql/postgresql.bicep' = {
  name: 'postgreSQL'
  scope: rg
  params: {
    administratorLogin: postgreSQLAdministratorLogin
    administratorLoginPassword: postgreSQLAdministratorPassword
    location: location
    tags: tags
    serverName: postgresSqlName
    delegatedSubnetResourceId: serviceVirtualNetwork.outputs.postgreSQLSubnetID
    privateDnsZoneArmResourceId: postgreSQLPrivateDnsZone.outputs.privateDnsZoneArmResourceId
  }
}
// END POSTGRESQL RESOURCES =============================================================


// AZURE CONTAINER APPS RESOURCES =============================================================

// create the ACA env, registry and assign roles
module acaEnvModule './app/aca-env.bicep' = {
  name: acaEnvName
  scope: rg
  params: {
    containerAppsLocation: location
    acaEnvName: acaEnvName
    acrName: acrName
    subnetID: serviceVirtualNetwork.outputs.acaSubnetID
  }
}

// agent app
module baseballAgentModule 'app/container-app.bicep' = {
  name: 'container-app'
  scope: rg
  params: {
    envId: acaEnvModule.outputs.acaEnvId
    acrServer: acaEnvModule.outputs.loginServer
    ollamaEndpoint: 'https://${ollamaModelModule.outputs.endpoint}'
    openAIEndpoint: openAIAccount.properties.endpoint
    sessionPoolEndpoint: 'dummy'
    //sessionPoolEndpoint: sessionPool.properties.poolManagementEndpoint
    //postgresEndpoint: postgresstuff
    tagName: tagName
    location: location
  }
  dependsOn: [
    ollamaModelModule
  ]
}

// END AZURE CONTAINER APPS RESOURCES =============================================================

// Session Pool
// leave this out for now
// TODO: activate and weave into baseballAgent
//module sessionPoolModule 'session-pool.bicep' = {
//  name: 'session-pool'
//  params: {
//    name: sessionPoolName
//    location: actualSessionPoolLocation
//  }
//}
// var sessionPool = sessionPoolModule.outputs.sessionPool
// Q: same question here, why are we doing this via module
//module sessionPoolRoleAssignment 'session-pool-role-assignment.bicep' = {
//  name: 'session-pool-role-assignment'
//  params: {
//    chatApp: chatApp.outputs.chatApp
//    sessionPoolName: sessionPoolName
//  }
//  dependsOn: [
//    sessionPoolModule
//    baseballAgent
//  ]
//}

// AZURE AI  =============================================================

// model backend
module ollamaModelModule 'app/ollama-app.bicep' = {
  name: 'ollama-model'
  scope: rg
  params: {
    envId: acaEnvModule.outputs.acaEnvId
    tagName: tagName
    location: location
    acrServer: acaEnvModule.outputs.loginServer
  }
  dependsOn: [
    acaEnvModule
  ]
}

// use this to mark apps have creation
resource existenceTags 'Microsoft.Resources/tags@2024-03-01' = {
  name: 'default'
  properties: {
    tags: {
      '${tagName}': 'true'
    }
  }
  dependsOn: [
    baseballAgentModule
    ollamaModelModule
  ]
}

// Learn more about Azure role-based access control (RBAC) and built-in-roles at https://docs.microsoft.com/en-us/azure/role-based-access-control/overview
var CognitiveServicesRoleDefinitionIds = ['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'] // Cognitive Services OpenAI User

module openAiRoleUserUX 'app/openai-access.bicep' = {
  scope: rg
  name: 'openai-roles-ux'
  params: {
    principalId: ux.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID
    openAiAccountResourceName: openAIModule.outputs.openAIAccountName
    roleDefinitionIds: CognitiveServicesRoleDefinitionIds
  }
}

module openAiRoleUserBaseballAgent 'app/openai-access.bicep' = {
  scope: rg
  name: 'openai-roles-baseballAgent'
  params: {
    principalId: baseballAgentModule.outputs.baseballAgentIdentityPrincipalId
    openAiAccountResourceName: openAIModule.outputs.openAIAccountName
    roleDefinitionIds: CognitiveServicesRoleDefinitionIds
  }
}

// END AZURE AI  =============================================================

// AZURE LOAD TESTING  =============================================================

// Setup Azure load testing Resource
module loadtesting './core/loadtesting/loadtesting.bicep' = {
  name: 'loadtesting'
  scope: rg
  params: {
    name: altResName
    tags: tags 
    location: location
  }
}

module loadtestProfileMapping './core/loadtesting/testprofile-mapping.bicep' = {
  name: 'loadtestprofilemapping'
  scope: rg
  params: {
   testProfileMappingName : profileMappingName
   functionAppResourceName:  uploadData.outputs.SERVICE_API_NAME
   loadTestingResourceName:  loadtesting.outputs.name
   loadTestProfileId: testProfileId
   }
 }

//END AZURE LOAD TESTING  =============================================================


// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output UPLOAD_DATA_BASE_URL string = uploadData.outputs.SERVICE_API_URI
output ORCHESTRATE_INGEST_BASE_URL string = orchestrateIngestion.outputs.SERVICE_API_URI
output UX_BASE_URL string = ux.outputs.SERVICE_API_URI
output RESOURCE_GROUP string = rg.name
output UPLOAD_DATA_FUNCTION_APP_NAME string = uploadData.outputs.SERVICE_API_NAME
output ORCHESTRATE_INGEST_FUNCTION_APP_NAME string = orchestrateIngestion.outputs.SERVICE_API_NAME
output UX_FUNCTION_APP_NAME string = ux.outputs.SERVICE_API_NAME
output AZURE_FUNCTION_NAME string = uploadData.outputs.SERVICE_API_NAME
output AZURE_FUNCTION_APP_TRIGGER_NAME string = 'upload_data_single'
output AZURE_FUNCTION_APP_RESOURCE_ID string = uploadData.outputs.SERVICE_API_RESOURCE_ID
output AZURE_LOADTEST_RESOURCE_ID string = loadtesting.outputs.id
output AZURE_LOADTEST_RESOURCE_NAME string = loadtesting.outputs.name
output LOADTEST_TEST_ID string = loadtestTestId
output LOADTEST_DP_URL string = loadtesting.outputs.uri
output LOADTEST_PROFILE_ID string = testProfileId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acaEnvModule.outputs.loginServer
output AZURE_STATICWEBSITE_NAME string = staticwebsite.outputs.name
output SPORTS_SERVICE_URL string = baseballAgentModule.outputs.baseballAgentUri
