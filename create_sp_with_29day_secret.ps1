# Create service principal with 29-day secret lifespan
$spDisplayName = "apiops-prod-sp"
$subscriptionId = "04111ead-4a81-46d8-bc64-74cd5d3026af"
$resourceGroup = "apiops-rg"
$rgScope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"

Write-Output "Creating service principal with 29-day secret..."

# Calculate 29-day expiration window (UTC)
$start = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$end = (Get-Date).ToUniversalTime().AddDays(29).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Create AD application
$app = az ad app create --display-name $spDisplayName | ConvertFrom-Json
Write-Output "Created app: $($app.appId)"

# Create service principal
$sp = az ad sp create --id $app.appId | ConvertFrom-Json
Write-Output "Created service principal: $($sp.id)"

# Create credential with 29-day lifespan
Write-Output "Creating 29-day credential..."
Write-Output "  End:   $end"

$cred = az ad app credential reset `
  --id $app.appId `
  --end-date $end `
  --append | ConvertFrom-Json

Write-Output "Credential created, expires: $($cred.endDateTime)"

# Assign Contributor role
Write-Output "Assigning Contributor role..."
az role assignment create `
  --assignee $sp.id `
  --role Contributor `
  --scope $rgScope | Out-Null

Write-Output "Role assigned successfully"

# Get tenant info
$tenantId = (az account show --query tenantId -o tsv).Trim()

# Build SDK auth JSON
$sdkAuth = @{
  clientId = $app.appId
  clientSecret = $cred.password
  subscriptionId = $subscriptionId
  tenantId = $tenantId
  activeDirectoryEndpointUrl = "https://login.microsoftonline.com"
  resourceManagerEndpointUrl = "https://management.azure.com/"
  activeDirectoryGraphResourceId = "https://graph.windows.net/"
  sqlManagementEndpointUrl = "https://management.core.windows.net:8443/"
  galleryEndpointUrl = "https://gallery.azure.com/"
  managementEndpointUrl = "https://management.core.windows.net/"
} | ConvertTo-Json -Depth 10

Write-Output "`nSDK Auth JSON with 29-day secret (store securely):"
Write-Output $sdkAuth
