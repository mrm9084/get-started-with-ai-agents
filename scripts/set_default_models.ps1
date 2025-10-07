$SubscriptionId = ([System.Environment]::GetEnvironmentVariable('AZURE_SUBSCRIPTION_ID', "Process"))
$Location = ([System.Environment]::GetEnvironmentVariable('AZURE_LOCATION', "Process"))

$Errors = 0

if (-not $SubscriptionId) {
    Write-Error "❌ ERROR: Missing AZURE_SUBSCRIPTION_ID"
    $Errors++
}

if (-not $Location) {
    Write-Error "❌ ERROR: Missing AZURE_LOCATION"
    $Errors++
}

if ($Errors -gt 0) {
    exit 1
}


# Function to get all AZURE_AI configuration values from Azure App Configuration
function Get-AppConfigValues {
    $appConfigName = ([System.Environment]::GetEnvironmentVariable('AZURE_APP_CONFIG_STORE_NAME', "Process"))
    $configValues = @{}
    
    if ($appConfigName) {
        try {
            Write-Host "🔍 Retrieving AZURE_AI* configuration from App Configuration..."
            $jsonResult = az appconfig kv list --name $appConfigName --key "AZURE_AI*" --query "[].{key:key, value:value}" --output json 2>$null
            if ($jsonResult) {
                $configs = $jsonResult | ConvertFrom-Json
                foreach ($config in $configs) {
                    if ($config.value -and $config.value -ne "null" -and $config.value.Trim() -ne "") {
                        $configValues[$config.key] = $config.value
                        Write-Host "✅ Retrieved $($config.key): $($config.value)"
                    }
                }
            }
        }
        catch {
            Write-Warning "⚠️ Could not retrieve configuration from App Configuration, using defaults"
        }
    }
    
    return $configValues
}

# Function to get config value with fallback to default
function Get-ConfigValue {
    param(
        [hashtable]$ConfigValues,
        [string]$Key,
        [string]$DefaultValue
    )
    
    if ($ConfigValues.ContainsKey($Key) -and $ConfigValues[$Key]) {
        return $ConfigValues[$Key]
    }
    return $DefaultValue
}

# Get all App Configuration values once
$appConfigValues = Get-AppConfigValues

$defaultEnvVars = @{
    AZURE_AI_EMBED_DEPLOYMENT_NAME = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_EMBED_DEPLOYMENT_NAME' -DefaultValue 'text-embedding-3-small')
    AZURE_AI_EMBED_MODEL_NAME = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_EMBED_MODEL_NAME' -DefaultValue 'text-embedding-3-small')
    AZURE_AI_EMBED_MODEL_FORMAT = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_EMBED_MODEL_FORMAT' -DefaultValue 'OpenAI')
    AZURE_AI_EMBED_MODEL_VERSION = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_EMBED_MODEL_VERSION' -DefaultValue '1')
    AZURE_AI_EMBED_DEPLOYMENT_SKU = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_EMBED_DEPLOYMENT_SKU' -DefaultValue 'Standard')
    AZURE_AI_EMBED_DEPLOYMENT_CAPACITY = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_EMBED_DEPLOYMENT_CAPACITY' -DefaultValue '50')
    AZURE_AI_AGENT_DEPLOYMENT_NAME = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_AGENT_DEPLOYMENT_NAME' -DefaultValue 'gpt-4o-mini')
    AZURE_AI_AGENT_MODEL_NAME = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_AGENT_MODEL_NAME' -DefaultValue 'gpt-4o-mini')
    AZURE_AI_AGENT_MODEL_VERSION = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_AGENT_MODEL_VERSION' -DefaultValue '2024-07-18')
    AZURE_AI_AGENT_MODEL_FORMAT = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_AGENT_MODEL_FORMAT' -DefaultValue 'OpenAI')
    AZURE_AI_AGENT_DEPLOYMENT_SKU = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_AGENT_DEPLOYMENT_SKU' -DefaultValue 'GlobalStandard')
    AZURE_AI_AGENT_DEPLOYMENT_CAPACITY = (Get-ConfigValue -ConfigValues $appConfigValues -Key 'AZURE_AI_AGENT_DEPLOYMENT_CAPACITY' -DefaultValue '80')
}

$envVars = @{}

foreach ($key in $defaultEnvVars.Keys) {
    $val = [System.Environment]::GetEnvironmentVariable($key, "Process")
    $envVars[$key] = $val
    if (-not $val) {
        $envVars[$key] = $defaultEnvVars[$key]
    }
    azd env set $key $envVars[$key]
}

# --- If we do not use existing AI Project, we don't deploy models, so skip validation ---
$resourceId = [System.Environment]::GetEnvironmentVariable('AZURE_EXISTING_AIPROJECT_RESOURCE_ID', "Process")
if (-not [string]::IsNullOrEmpty($resourceId)) {
    Write-Host "✅ AZURE_EXISTING_AIPROJECT_RESOURCE_ID is set, skipping model deployment validation."
    exit 0
}

$chatDeployment = @{
    name = $envVars.AZURE_AI_AGENT_DEPLOYMENT_NAME
    model = @{
        name = $envVars.AZURE_AI_AGENT_MODEL_NAME
        version = $envVars.AZURE_AI_AGENT_MODEL_VERSION
        format = $envVars.AZURE_AI_AGENT_MODEL_FORMAT
    }
    sku = @{
        name = $envVars.AZURE_AI_AGENT_DEPLOYMENT_SKU
        capacity = $envVars.AZURE_AI_AGENT_DEPLOYMENT_CAPACITY
    } 
    capacity_env_var_name = 'AZURE_AI_AGENT_DEPLOYMENT_CAPACITY'
}



$aiModelDeployments = @($chatDeployment)

$useSearchService = ([System.Environment]::GetEnvironmentVariable('USE_AZURE_AI_SEARCH_SERVICE', "Process"))

if ($useSearchService -eq 'true') {
    $embedDeployment = @{
        name = $envVars.AZURE_AI_EMBED_DEPLOYMENT_NAME
        model = @{
            name = $envVars.AZURE_AI_EMBED_MODEL_NAME
            version = $envVars.AZURE_AI_EMBED_MODEL_VERSION
            format = $envVars.AZURE_AI_EMBED_MODEL_FORMAT
        }
        sku = @{
            name = $envVars.AZURE_AI_EMBED_DEPLOYMENT_SKU
            capacity = $envVars.AZURE_AI_EMBED_DEPLOYMENT_CAPACITY
            min_capacity = 30
        }
        capacity_env_var_name = 'AZURE_AI_EMBED_DEPLOYMENT_CAPACITY'
    }

    $aiModelDeployments += $embedDeployment
}


az account set --subscription $SubscriptionId
Write-Host "🎯 Active Subscription: $(az account show --query '[name, id]' --output tsv)"

$QuotaAvailable = $true

try {
    Write-Host "🔍 Validating model deployments against quotas..."
} catch {
    Write-Error "❌ ERROR: Failed to validate model deployments. Ensure you have the necessary permissions."
    exit 1
}

foreach ($deployment in $aiModelDeployments) {
    $name = $deployment.name
    $model = $deployment.model.name
    $type = $deployment.sku.name
    $format = $deployment.model.format
    $capacity = $deployment.sku.capacity
    $capacity_env_var_name = $deployment.capacity_env_var_name
    Write-Host "🔍 Validating model deployment: $name ..."
    & .\scripts\resolve_model_quota.ps1 -Location $Location -Model $model -Format $format -Capacity $capacity -CapacityEnvVarName $capacity_env_var_name -DeploymentType $type

    # Check if the script failed
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ ERROR: Quota validation failed for model deployment: $name"
        $QuotaAvailable = $false
    }
}


if (-not $QuotaAvailable) {
    exit 1
} else {
    Write-Host "✅ All model deployments passed quota validation successfully."
    exit 0
}