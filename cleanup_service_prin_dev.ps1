# Cleanup script for service_prin_dev.ps1
# This will delete the service principal, app registration, and role assignment

$spDisplayName = "apiops-dev-sp"
$rgScope = "/subscriptions/04111ead-4a81-46d8-bc64-74cd5d3026af/resourceGroups/lab-model-context-protocol"

Write-Output "Starting cleanup..."

# Get the app by display name
$app = az ad app list --display-name $spDisplayName | ConvertFrom-Json
if ($app -and $app.Count -gt 0) {
    $appId = $app[0].appId
    Write-Output "Found app: $appId"
    
    # Get the service principal
    $sp = az ad sp list --filter "appId eq '$appId'" | ConvertFrom-Json
    if ($sp -and $sp.Count -gt 0) {
        $spId = $sp[0].id
        Write-Output "Found service principal: $spId"
        
        # Remove role assignment
        Write-Output "Removing role assignment..."
        az role assignment delete --assignee $spId --scope $rgScope
        Write-Output "Role assignment removed"
    }
    
    # Delete the service principal
    Write-Output "Deleting service principal..."
    az ad sp delete --id $appId
    Write-Output "Service principal deleted"
    
    # Delete the app registration
    Write-Output "Deleting app registration..."
    az ad app delete --id $appId
    Write-Output "App registration deleted"
    
    Write-Output "`nCleanup completed successfully!"
} else {
    Write-Output "No app found with display name: $spDisplayName"
    Write-Output "It may have already been deleted."
}
