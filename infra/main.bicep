// Define the location (Defaulting to the Resource Group's location)
param location string = resourceGroup().location

// Define the name of the app
param swaName string = 'Hugo-App'

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: swaName
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // These properties are essential for linking the "Blueprint" to GitHub
    allowConfigFileUpdates: true
    stagingEnvironmentPolicy: 'Enabled'
  }
}
