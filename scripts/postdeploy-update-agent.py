#!/usr/bin/env python3
"""
Post-deploy script to update AI agent model deployment in Azure AI Foundry.
Runs after model deployments to ensure agents use the correct models.
Gets configuration from Azure App Configuration.
"""

import os
import sys
import argparse
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.appconfiguration.provider import load
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient
from azure.mgmt.cognitiveservices.models import Deployment, DeploymentModel, Sku


def create_deployment_via_sdk(deployment_name, model_name, model_version, ai_service, resource_group, subscription_id, credential, verbose=False):
    """Create a model deployment using Azure SDK."""
    
    if not ai_service or not resource_group:
        print(f"❌ Missing required values - AI Service: {ai_service or 'MISSING'}, Resource Group: {resource_group or 'MISSING'}")
        return False
    
    try:
        # Create Cognitive Services management client
        cs_client = CognitiveServicesManagementClient(credential, subscription_id)
        
        # Check if deployment exists
        try:
            existing_deployment = cs_client.deployments.get(
                resource_group_name=resource_group,
                account_name=ai_service,
                deployment_name=deployment_name
            )
            if existing_deployment:
                print(f"Deployment '{deployment_name}' already exists")
                return True
        except Exception:
            # Deployment doesn't exist, continue to create
            pass
        
        # Create deployment
        print(f"Creating deployment: {deployment_name} with model {model_name}")
        
        deployment = Deployment(
            properties=DeploymentModel(
                model={
                    "format": "OpenAI",
                    "name": model_name,
                    "version": model_version
                }
            ),
            sku=Sku(name="GlobalStandard", capacity=10)
        )
        
        # Create the deployment (this is a long-running operation)
        operation = cs_client.deployments.begin_create_or_update(
            resource_group_name=resource_group,
            account_name=ai_service,
            deployment_name=deployment_name,
            deployment=deployment
        )
        
        # Wait for completion
        result = operation.result()
        print(f"✅ Created deployment: {deployment_name}")
        return True
        
    except Exception as e:
        print(f"❌ Error creating deployment: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Post-deploy script: Update agent model deployment",
        epilog="Typically run after model deployments to sync agent configurations"
    )
    parser.add_argument("--app-config", help="App Configuration store name (defaults to AZURE_APP_CONFIG_STORE_NAME env var)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be changed")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    
    args = parser.parse_args()

    if not args.verbose:
        # Minimal output for post-deploy scripts
        print("🔄 Post-deploy: Updating agent model deployment...")

    # Get App Configuration name from argument or environment variable
    app_config_name = args.app_config or os.getenv("AZURE_APP_CONFIG_STORE_NAME")
    if not app_config_name:
        print("❌ Error: Need --app-config argument or AZURE_APP_CONFIG_STORE_NAME environment variable")
        sys.exit(1)

    if args.verbose:
        print(f"Using App Configuration: {app_config_name}")

    # Create credential once and reuse
    credential = DefaultAzureCredential()
    
    # Get all configuration values in one call
    config_endpoint = f"https://{app_config_name}.azconfig.io"
    config = load(endpoint=config_endpoint, credential=credential)
    
    # Extract values from config
    agent_name = config.get("AZURE_AI_AGENT_NAME")
    new_model = config.get("AZURE_AI_AGENT_DEPLOYMENT_NAME")
    model_name = config.get("AZURE_AI_AGENT_MODEL_NAME")
    model_version = config.get("AZURE_AI_AGENT_MODEL_VERSION")
    project_endpoint = config.get("AZURE_EXISTING_AIPROJECT_ENDPOINT")
    
    # Get Azure resources from environment variables or config
    ai_service = os.getenv("AZURE_AISERVICES_NAME") or config.get("AZURE_AISERVICES_NAME")
    resource_group = os.getenv("AZURE_RESOURCE_GROUP") or config.get("AZURE_RESOURCE_GROUP")
    subscription_id = os.getenv("AZURE_SUBSCRIPTION_ID") or config.get("AZURE_SUBSCRIPTION_ID")

    if not all([agent_name, new_model, model_name, model_version, project_endpoint, ai_service, resource_group, subscription_id]):
        print("❌ Error: Missing required configuration values:")
        if args.verbose:
            print(f"  Agent name: {agent_name or 'MISSING'}")
            print(f"  New model: {new_model or 'MISSING'}")
            print(f"  Model name: {model_name or 'MISSING'}")
            print(f"  Model version: {model_version or 'MISSING'}")
            print(f"  Project endpoint: {project_endpoint or 'MISSING'}")
            print(f"  AI Service: {ai_service or 'MISSING'}")
            print(f"  Resource Group: {resource_group or 'MISSING'}")
            print(f"  Subscription ID: {subscription_id or 'MISSING'}")
        sys.exit(1)

    if args.verbose:
        print(f"Configuration:")
        print(f"  Agent: {agent_name}")
        print(f"  Target deployment: {new_model}")
        print(f"  Model: {model_name} v{model_version}")
        print(f"  Project endpoint: {project_endpoint}")

    try:
        # Connect to project
        client = AIProjectClient(endpoint=project_endpoint, credential=credential)
        
        # Find agent
        agents = list(client.agents.list_agents())
        agent = next((a for a in agents if a.name == agent_name), None)
        
        if not agent:
            print(f"❌ Agent '{agent_name}' not found")
            if args.verbose:
                print("Available agents:", [a.name for a in agents])
            sys.exit(1)

        if args.verbose:
            print(f"Current model: {agent.model}")
        
        if agent.model == new_model:
            print("✅ Agent already using target model - no changes needed")
            return 0

        if args.dry_run:
            print(f"📋 Would change: {agent.model} → {new_model}")
            return 0

        # Ensure deployment exists
        deployment_success = create_deployment_via_sdk(new_model, model_name, model_version, ai_service, resource_group, subscription_id, credential, args.verbose)
        
        if not deployment_success:
            print("❌ Failed to ensure deployment exists")
            sys.exit(1)

        # Update agent
        old_model = agent.model
        client.agents.update_agent(
            agent_id=agent.id,
            model=new_model,
            name=agent.name,
            instructions=agent.instructions,
            tools=agent.tools or []
        )
        
        print(f"✅ Updated agent: {old_model} → {new_model}")
        return 0

    except Exception as e:
        print(f"❌ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()