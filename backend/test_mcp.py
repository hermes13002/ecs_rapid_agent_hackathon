import asyncio
import sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test_mcp():
    server_params = StdioServerParameters(
        command=sys.executable,
        args=["-m", "fastmcp", "run", "app/google_agent/mcp_server.py"],
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("Initialized")
            result = await session.call_tool("mongodb_get_component_spec", arguments={"component_type": "led"})
            print(result)

if __name__ == "__main__":
    asyncio.run(test_mcp())
