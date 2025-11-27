# MCP Server Anbindung an MCP Client

## Übersicht

Die Anbindung eines MCP Servers an einen MCP Client erfolgt über ein standardisiertes Protokoll, das auf JSON-RPC 2.0 basiert. Der Client initiiert die Verbindung und kommuniziert mit dem Server über verschiedene Transport-Mechanismen.

## Architektur-Überblick

```
┌─────────────────┐         Transport Layer        ┌─────────────────┐
│   MCP Client    │ ◄─────────────────────────────► │   MCP Server    │
│   (z.B. Claude) │     (stdio/HTTP/WebSocket)     │  (z.B. Drive)   │
└─────────────────┘                                 └─────────────────┘
        │                                                     │
        │              JSON-RPC 2.0 Messages                 │
        │                                                     │
        ├─── initialize ────────────────────────────────────►│
        │◄── initialized ────────────────────────────────────┤
        │                                                     │
        ├─── tools/list ────────────────────────────────────►│
        │◄── tools/list response ────────────────────────────┤
        │                                                     │
        ├─── tools/call ────────────────────────────────────►│
        │◄── result ─────────────────────────────────────────┤
```

## Transport-Mechanismen

### 1. Standard Input/Output (stdio)

**Am häufigsten verwendet für lokale Server**

Der Server läuft als Prozess und kommuniziert über stdin/stdout.

**Client-Konfiguration (z.B. in Claude Desktop):**

```json
{
  "mcpServers": {
    "mein-server": {
      "command": "python",
      "args": ["-m", "mein_mcp_server"],
      "env": {
        "API_KEY": "geheimer_schluessel"
      }
    }
  }
}
```

**Was passiert:**
1. Client startet den Server-Prozess mit `python -m mein_mcp_server`
2. Server schreibt auf stdout, Client liest von stdin
3. Client schreibt auf stdin, Server liest von stdout
4. Alle Nachrichten sind JSON-RPC 2.0 formatiert

### 2. HTTP/SSE (Server-Sent Events)

**Für remote Server und Web-Integrationen**

```json
{
  "mcpServers": {
    "remote-server": {
      "url": "https://api.example.com/mcp",
      "transport": "sse"
    }
  }
}
```

**Ablauf:**
- Client sendet HTTP POST Requests
- Server antwortet mit Server-Sent Events für Streaming

### 3. WebSocket

**Für bidirektionale Echtzeit-Kommunikation**

```json
{
  "mcpServers": {
    "websocket-server": {
      "url": "wss://api.example.com/mcp",
      "transport": "websocket"
    }
  }
}
```

## Verbindungsaufbau - Schritt für Schritt

### Phase 1: Initialization

**1. Client sendet `initialize` Request**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "roots": {
        "listChanged": true
      },
      "sampling": {}
    },
    "clientInfo": {
      "name": "Claude Desktop",
      "version": "1.0.0"
    }
  }
}
```

**2. Server antwortet mit Capabilities**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {},
      "resources": {
        "subscribe": true,
        "listChanged": true
      },
      "prompts": {
        "listChanged": true
      },
      "logging": {}
    },
    "serverInfo": {
      "name": "mein-mcp-server",
      "version": "1.0.0"
    }
  }
}
```

**3. Client sendet `initialized` Notification**

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/initialized"
}
```

### Phase 2: Discovery

**Client fragt verfügbare Funktionen ab**

**Tools abfragen:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list"
}
```

**Server-Antwort:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "tools": [
      {
        "name": "search_stations",
        "description": "Sucht nach Stationen im RMV-Netz",
        "inputSchema": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "Suchbegriff"
            },
            "max_results": {
              "type": "integer",
              "default": 10
            }
          },
          "required": ["query"]
        }
      }
    ]
  }
}
```

**Resources abfragen:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "resources/list"
}
```

**Prompts abfragen:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "prompts/list"
}
```

### Phase 3: Normale Kommunikation

**Tool aufrufen:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tools/call",
  "params": {
    "name": "search_stations",
    "arguments": {
      "query": "Frankfurt Hauptbahnhof",
      "max_results": 5
    }
  }
}
```

**Server führt Funktion aus und antwortet:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Gefundene Stationen:\n1. Frankfurt (Main) Hauptbahnhof\n2. Frankfurt (Main) Hbf (tief)"
      }
    ],
    "isError": false
  }
}
```

## Implementierung - Client-Seite

### Python Client Beispiel

```python
import asyncio
import json
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def connect_to_server():
    # Server-Parameter definieren
    server_params = StdioServerParameters(
        command="python",
        args=["-m", "mein_mcp_server"],
        env={"API_KEY": "secret"}
    )
    
    # Verbindung aufbauen
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            # Initialize
            await session.initialize()
            
            # Tools abfragen
            tools = await session.list_tools()
            print(f"Verfügbare Tools: {[tool.name for tool in tools.tools]}")
            
            # Tool aufrufen
            result = await session.call_tool(
                "search_stations",
                arguments={"query": "Frankfurt"}
            )
            print(f"Ergebnis: {result.content}")

# Ausführen
asyncio.run(connect_to_server())
```

### TypeScript Client Beispiel

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

async function connectToServer() {
  // Transport erstellen
  const transport = new StdioClientTransport({
    command: "node",
    args: ["mein-server.js"],
    env: { API_KEY: "secret" }
  });

  // Client erstellen
  const client = new Client({
    name: "mein-client",
    version: "1.0.0"
  }, {
    capabilities: {
      tools: {}
    }
  });

  // Verbinden
  await client.connect(transport);

  // Tools abfragen
  const tools = await client.listTools();
  console.log("Tools:", tools.tools.map(t => t.name));

  // Tool aufrufen
  const result = await client.callTool({
    name: "search_stations",
    arguments: { query: "Frankfurt" }
  });
  console.log("Ergebnis:", result);
}

connectToServer();
```

## Implementierung - Server-Seite

### Python Server Beispiel

```python
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
import asyncio

# Server erstellen
server = Server("mein-mcp-server")

@server.list_tools()
async def list_tools() -> list[Tool]:
    """Liste verfügbarer Tools zurückgeben"""
    return [
        Tool(
            name="search_stations",
            description="Sucht nach Stationen",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string"}
                },
                "required": ["query"]
            }
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    """Tool ausführen"""
    if name == "search_stations":
        query = arguments["query"]
        # Logik implementieren
        result = f"Suche nach: {query}"
        return [TextContent(type="text", text=result)]
    
    raise ValueError(f"Unknown tool: {name}")

async def main():
    # Server über stdio starten
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )

if __name__ == "__main__":
    asyncio.run(main())
```

### Node.js Server Beispiel

```javascript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

// Server erstellen
const server = new Server({
  name: "mein-mcp-server",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {}
  }
});

// Tools registrieren
server.setRequestHandler("tools/list", async () => {
  return {
    tools: [{
      name: "search_stations",
      description: "Sucht nach Stationen",
      inputSchema: {
        type: "object",
        properties: {
          query: { type: "string" }
        },
        required: ["query"]
      }
    }]
  };
});

// Tool-Aufrufe behandeln
server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;
  
  if (name === "search_stations") {
    const result = `Suche nach: ${args.query}`;
    return {
      content: [{
        type: "text",
        text: result
      }]
    };
  }
  
  throw new Error(`Unknown tool: ${name}`);
});

// Transport erstellen und Server starten
const transport = new StdioServerTransport();
await server.connect(transport);
```

## Konfiguration in verschiedenen Clients

### Claude Desktop (macOS/Windows)

**Konfig-Datei:** `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/username/Documents"]
    },
    "python-server": {
      "command": "python",
      "args": ["-m", "mcp_server_example"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    },
    "remote-server": {
      "url": "https://api.example.com/mcp",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer ${TOKEN}"
      }
    }
  }
}
```

### Cline (VS Code Extension)

**Konfig in VS Code Settings:**

```json
{
  "cline.mcpServers": {
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git"]
    }
  }
}
```

## Fehlerbehandlung

### Client-seitig

```python
from mcp.types import McpError

async def safe_tool_call(session, tool_name, arguments):
    try:
        result = await session.call_tool(tool_name, arguments)
        return result
    except McpError as e:
        print(f"MCP Fehler: {e.error.message}")
    except TimeoutError:
        print("Timeout beim Server-Aufruf")
    except ConnectionError:
        print("Verbindung zum Server verloren")
    except Exception as e:
        print(f"Unerwarteter Fehler: {e}")
```

### Server-seitig

```python
from mcp.types import ErrorData, INTERNAL_ERROR

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    try:
        # Tool-Logik
        pass
    except ValueError as e:
        # Validierungsfehler
        raise McpError(
            ErrorData(
                code=INVALID_PARAMS,
                message=str(e)
            )
        )
    except Exception as e:
        # Interner Fehler
        raise McpError(
            ErrorData(
                code=INTERNAL_ERROR,
                message="Serverfehler aufgetreten"
            )
        )
```

## Sicherheitsaspekte

### Authentifizierung

```python
# Server mit Token-Auth
@server.list_tools()
async def list_tools(request_context) -> list[Tool]:
    # Token aus Context prüfen
    token = request_context.meta.get("authorization")
    if not validate_token(token):
        raise McpError(ErrorData(
            code=UNAUTHORIZED,
            message="Ungültiges Token"
        ))
    return [...]
```

### Environment Variables

```json
{
  "mcpServers": {
    "secure-server": {
      "command": "python",
      "args": ["-m", "server"],
      "env": {
        "API_KEY": "${MY_SECRET_API_KEY}",
        "DB_PASSWORD": "${DATABASE_PASSWORD}"
      }
    }
  }
}
```

Die Variablen müssen in der Shell-Umgebung gesetzt sein.

## Debugging

### Client-seitiges Logging

```python
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("mcp.client")

# Alle JSON-RPC Nachrichten werden geloggt
```

### Server-seitiges Logging

```python
from mcp.server import Server

server = Server("debug-server")

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    server.request_context.session.send_log_message(
        level="info",
        data=f"Tool {name} aufgerufen mit {arguments}"
    )
    # ...
```

### Transport-Layer Debugging

```bash
# Server direkt testen
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python -m mein_server
```

## Best Practices

1. **Robuste Verbindungsverwaltung**: Timeouts und Reconnect-Logik implementieren
2. **Capability Negotiation**: Nur Features nutzen, die beide Seiten unterstützen
3. **Async/Await**: Immer asynchrone Patterns verwenden
4. **Fehlerbehandlung**: Alle möglichen Fehler abfangen
5. **Logging**: Ausreichend loggen für Debugging
6. **Versionierung**: Protocol-Version prüfen und kompatibel bleiben
7. **Sicherheit**: Niemals Secrets in Konfigurationsdateien hartcodieren
8. **Testing**: Integration-Tests für Client-Server-Kommunikation

## Zusammenfassung

Die Anbindung eines MCP Servers erfolgt in drei Hauptphasen:

1. **Initialization**: Capability Negotiation zwischen Client und Server
2. **Discovery**: Client fragt verfügbare Tools/Resources/Prompts ab
3. **Operation**: Normale Request/Response-Kommunikation

Der gesamte Prozess basiert auf JSON-RPC 2.0 über verschiedene Transport-Layer (stdio, HTTP/SSE, WebSocket), wobei stdio für lokale Server am gebräuchlichsten ist.