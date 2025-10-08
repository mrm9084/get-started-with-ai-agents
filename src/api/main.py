# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE.md file in the project root for full license information.

import contextlib
import os

from azure.ai.projects.aio import AIProjectClient
from azure.identity import DefaultAzureCredential

import fastapi
from fastapi.staticfiles import StaticFiles
from fastapi import Request
from fastapi.responses import JSONResponse
from azure.appconfiguration.provider import load, SettingSelector

from logging_config import configure_logging

enable_trace = False
logger = None

# Load configuration from Azure App Configuration
endpoint = (os.getenv("AZURE_APP_CONFIG_ENDPOINT") or 
           f"https://{os.getenv('AZURE_APP_CONFIG_STORE_NAME')}.azconfig.io" if os.getenv('AZURE_APP_CONFIG_STORE_NAME') else None)

if not endpoint:
    raise RuntimeError("Azure App Configuration endpoint required. Set AZURE_APP_CONFIG_ENDPOINT or AZURE_APP_CONFIG_STORE_NAME environment variable.")

credential = DefaultAzureCredential(exclude_shared_token_cache_credential=True)
config = load(
    endpoint=endpoint,
    credential=credential,
    selectors=[SettingSelector(key_filter="*")]
)

@contextlib.asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    agent = None

    proj_endpoint = config.get("AZURE_EXISTING_AIPROJECT_ENDPOINT")
    agent_id = config.get("AZURE_EXISTING_AGENT_ID")
    try:
        ai_project = AIProjectClient(
            credential=DefaultAzureCredential(exclude_shared_token_cache_credential=True),
            endpoint=proj_endpoint,
            api_version = "2025-05-15-preview" # Evaluations yet not supported on stable (api_version="2025-05-01")
        )
        logger.info("Created AIProjectClient")

        if enable_trace:
            application_insights_connection_string = ""
            try:
                application_insights_connection_string = await ai_project.telemetry.get_connection_string()
            except Exception as e:
                e_string = str(e)
                logger.error("Failed to get Application Insights connection string, error: %s", e_string)
            if not application_insights_connection_string:
                logger.error("Application Insights was not enabled for this project.")
                logger.error("Enable it via the 'Tracing' tab in your AI Foundry project page.")
                exit()
            else:
                from azure.monitor.opentelemetry import configure_azure_monitor
                configure_azure_monitor(connection_string=application_insights_connection_string)
                app.state.application_insights_connection_string = application_insights_connection_string
                logger.info("Configured Application Insights for tracing.")

        if agent_id:
            try: 
                agent = await ai_project.agents.get_agent(agent_id)
                logger.info("Agent already exists, skipping creation")
                logger.info(f"Fetched agent, agent ID: {agent.id}")
                logger.info(f"Fetched agent, model name: {agent.model}")
            except Exception as e:
                logger.error(f"Error fetching agent: {e}", exc_info=True)

        if not agent:
            # Fallback to searching by name
            agent_name = config.get("AZURE_AI_AGENT_NAME")
            if not agent_name:
                raise ValueError("Required configuration key 'AZURE_AI_AGENT_NAME' not found")
            agent_list = ai_project.agents.list_agents()
            if agent_list:
                async for agent_object in agent_list:
                    if agent_object.name == agent_name:
                        agent = agent_object
                        logger.info(f"Found agent by name '{agent_name}', ID={agent_object.id}")
                        break

        if not agent:
            raise RuntimeError("No agent found. Ensure qunicorn.py created one or set AZURE_EXISTING_AGENT_ID.")

        app.state.ai_project = ai_project
        app.state.agent = agent
        
        yield

    except Exception as e:
        logger.error(f"Error during startup: {e}", exc_info=True)
        raise RuntimeError(f"Error during startup: {e}")

    finally:
        try:
            await ai_project.close()
            logger.info("Closed AIProjectClient")
        except Exception as e:
            logger.error("Error closing AIProjectClient", exc_info=True)


def create_app():
    global logger
    logger = configure_logging(config.get("APP_LOG_FILE", ""))

    global enable_trace
    enable_trace = str(config.get("ENABLE_AZURE_MONITOR_TRACING", "false")).lower() == "true"
    if enable_trace:
        logger.info("Tracing is enabled.")
        try:
            from azure.monitor.opentelemetry import configure_azure_monitor
        except ModuleNotFoundError:
            logger.error("Required libraries for tracing not installed.")
            logger.error("Please make sure azure-monitor-opentelemetry is installed.")
            exit()
    else:
        logger.info("Tracing is not enabled")

    directory = os.path.join(os.path.dirname(__file__), "static")
    app = fastapi.FastAPI(lifespan=lifespan)
    app.mount("/static", StaticFiles(directory=directory), name="static")
    
    # Mount React static files
    # Uncomment the following lines if you have a React frontend
    # react_directory = os.path.join(os.path.dirname(__file__), "static/react")
    # app.mount("/static/react", StaticFiles(directory=react_directory), name="react")

    from . import routes  # Import routes
    app.include_router(routes.router)

    # Global exception handler for any unhandled exceptions
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error("Unhandled exception occurred", exc_info=exc)
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )
    
    return app
