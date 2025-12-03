# Troubleshooting Application Insights Logger Deployment

## Problem Summary

When deploying APIM configurations using APIops, the deployment failed with error:
```
ValidationError: One or more Properties ['{0}'] specified are missing.
Message: Logger-Credentials--6846da9ec22a8e22f09e05ea
```

Later evolved to:
```
ValidationError: Invalid instrumentation key for Application Insights Logger
```

## Root Cause

The issue had multiple layers:

1. **Named Value Dependency**: The logger configuration referenced a named value (`Logger-Credentials--6846da9ec22a8e22f09e05ea`) for storing the Application Insights instrumentation key
2. **Deployment Order**: APIops was attempting to deploy the logger before the named value was created, causing a dependency failure
3. **Missing Token Replacement**: The placeholder `{#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}` in artifact files wasn't being replaced with actual secrets during deployment
4. **Environment-Specific Resources**: Dev and prod environments use different Application Insights instances

## Solution

### Step 1: Remove Named Value Dependency

**Changed**: `apimartifacts/loggers/apim-logger/loggerInformation.json`

**From:**
```json
{
  "properties": {
    "loggerType": "applicationInsights",
    "credentials": {
      "instrumentationKey": "{{Logger-Credentials--6846da9ec22a8e22f09e05ea}}"
    },
    ...
  }
}
```

**To:**
```json
{
  "properties": {
    "loggerType": "applicationInsights",
    "credentials": {
      "instrumentationKey": "{#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}"
    },
    ...
  }
}
```

**Why**: This eliminates the dependency on a named value being created first. The instrumentation key is now injected directly during deployment.

### Step 2: Update Configuration Override

**Changed**: `configuration.prod.yaml`

**From:**
```yaml
namedValues:
  - name: Logger-Credentials--6846da9ec22a8e22f09e05ea
    displayName: Logger-Credentials--6846da9ec22a8e22f09e05ea
    secret: true
    value: {#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}
loggers:
  - name: apim-logger
    credentials:
      instrumentationKey: "{{Logger-Credentials--6846da9ec22a8e22f09e05ea}}"
```

**To:**
```yaml
namedValues:
loggers:
  - name: apim-logger
    credentials:
      instrumentationKey: {#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}
```

**Why**: Aligns the prod configuration override with the direct instrumentation key approach.

### Step 3: Add Token Replacement for Artifacts

**Changed**: `.github/workflows/run-publisher-with-env.yaml`

**Added:**
```yaml
# Replace tokens in artifacts folder for all environments
- name: "Perform secret substitution in artifacts folder"
  uses: cschleiden/replace-tokens@v1.3
  with:
    tokenPrefix: "{#"
    tokenSuffix: "#}"
    files: '["**/apimartifacts/**/*.json"]'
  env:
    APPLICATION_INSIGHTS_INSTRUMENTATION_KEY: ${{ secrets.APPLICATION_INSIGHTS_INSTRUMENTATION_KEY }}
```

**Why**: This ensures that placeholders in artifact JSON files are replaced with actual secrets from GitHub environment variables **before** the publisher runs.

## How It Works

### For Dev Environment Deployment

1. Workflow runs with `API_MANAGEMENT_ENVIRONMENT: dev`
2. GitHub Actions uses secrets from the **dev** environment
3. Token replacement step replaces `{#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}` in `loggerInformation.json` with dev's App Insights key
4. Publisher deploys logger with dev's instrumentation key directly
5. Dev APIM connects to dev Application Insights

### For Prod Environment Deployment

1. Workflow runs with `API_MANAGEMENT_ENVIRONMENT: prod`
2. GitHub Actions uses secrets from the **prod** environment
3. Token replacement steps process both `configuration.prod.yaml` and artifacts folder
4. `{#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}` gets replaced with prod's App Insights key
5. Publisher deploys logger with prod's instrumentation key
6. Prod APIM connects to prod Application Insights

## Key Concepts

### Named Values vs Direct Configuration

**Named Values**: APIM resources that store reusable values (useful for values shared across multiple APIs/policies)
- **Pros**: Centralized management, can be updated independently
- **Cons**: Creates deployment dependencies, requires specific creation order

**Direct Configuration**: Values embedded directly in the resource configuration
- **Pros**: No dependencies, simpler deployment
- **Cons**: Less reusable, harder to update centrally

### Token Replacement Flow

```
Source Code (Git)
  ↓
[Checkout Code]
  ↓
[Token Replacement] ← GitHub Environment Secrets
  ↓
Modified Files with Actual Values
  ↓
[APIops Publisher]
  ↓
Azure APIM
```

### Environment-Specific Secrets

GitHub Actions environments allow the same secret name to have different values:
- **dev environment**: `APPLICATION_INSIGHTS_INSTRUMENTATION_KEY` = dev App Insights key
- **prod environment**: `APPLICATION_INSIGHTS_INSTRUMENTATION_KEY` = prod App Insights key

The workflow automatically uses the correct value based on which environment is being deployed.

## Required GitHub Secrets

Each environment (dev and prod) must have:

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `APPLICATION_INSIGHTS_INSTRUMENTATION_KEY` | App Insights instrumentation key | Azure Portal → Application Insights → Overview → Instrumentation Key |
| `APPLICATION_INSIGHTS_RESOURCE_ID` | (Optional) ARM resource ID | Azure Portal → Application Insights → Properties → Resource ID |

## Troubleshooting Checklist

If logger deployment fails:

- [ ] Verify `APPLICATION_INSIGHTS_INSTRUMENTATION_KEY` secret exists in both dev and prod GitHub environments
- [ ] Confirm the secret value is the correct instrumentation key (not connection string)
- [ ] Check that token replacement is running before the publisher step in workflow logs
- [ ] Verify `loggerInformation.json` uses placeholder `{#APPLICATION_INSIGHTS_INSTRUMENTATION_KEY#}`, not named value reference
- [ ] Ensure the Application Insights resource exists in the target Azure subscription
- [ ] Confirm the resource ID in `loggerInformation.json` points to the correct App Insights instance

## Files Modified

1. `apimartifacts/loggers/apim-logger/loggerInformation.json` - Changed to use direct instrumentation key
2. `configuration.prod.yaml` - Removed named value definition, updated logger override
3. `.github/workflows/run-publisher-with-env.yaml` - Added token replacement for artifacts folder

## Additional Notes

- The named value folder `apimartifacts/named values/6846da9ec22a8e22f09e05e9/` can remain in the repo; the publisher will skip it with a warning since it has no value
- If you need to use different Application Insights per environment, also parameterize the `resourceId` field
- This approach works for any secret that needs environment-specific values (not just App Insights keys)
