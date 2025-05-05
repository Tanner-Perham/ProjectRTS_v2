# Multiplayer Implementation for Unit Synchronization

This document explains how unit position and state synchronization is implemented in the multiplayer RTS game.

## Components Modified

### 1. Unit Script (`scripts/test_unit.gd`)
- Added multiplayer synchronization of key properties:
  - `sync_position`: Custom property that syncs and applies position updates from server to clients
  - `sync_rotation`: Custom property that syncs and applies rotation updates from server to clients
  - `sync_animation`: Custom property that syncs animation states between server and clients
  - `pathing`: Synchronizes pathing state with animation control
  - `player_owner`: Synchronizes unit ownership information across network
- Implemented custom property setters for immediate state updates on clients
- Implemented automatic animation transitions based on movement state
- Added RPC functions for client-to-server communication:
  - `server_unit_path_new`: Handles secure path calculation requests
  - `update_client_transform`: Updates client-side positions and rotations
  - `update_client_pathing`: Updates client-side pathing state
  - `sync_animation_state`: Ensures animations are synchronized
  - `update_player_owner`: Ensures ownership is properly set

### 2. World Script (`scripts/world.gd`)
- Configured MultiplayerSpawner to include both Player and TestUnit scenes
- Added functions for secure unit spawning with proper ownership:
  - `spawn_test_unit`: Server-side function to create and replicate units
  - `request_spawn_test_unit`: RPC allowing clients to request unit creation
- Implemented server-client connection handling with ENetMultiplayerPeer

### 3. Player Interface Script (`scripts/Player_Interface.gd`)
- Implemented ownership-aware selection system:
  - Modified selection logic to only allow selecting enemy units individually
  - Prevented multi-selecting enemy units alongside friendly units
- Added ownership verification for unit commands:
  - Single and formation movement commands check unit ownership
  - Only units owned by the controlling player accept movement commands
- Implemented unit spawning interface with proper networking:
  - Server directly spawns units
  - Clients request unit spawning via RPC

## How It Works

1. **Connection Establishment**
   - Host creates a server using ENetMultiplayerPeer
   - Clients connect to the server using IP address and port
   - Server assigns a unique ID to each client (server is always ID 1)
   - Player instances are created for each connected peer

2. **Unit Authority Model**
   - The server (ID 1) has authority over all units via MultiplayerSynchronizer
   - Units have a player_owner property storing the ID of the owning player
   - Server handles all physics calculations and path planning

3. **Command Flow**
   - Player selects units (with ownership restrictions)
   - Player issues movement commands
   - If the player owns the units:
     - Commands are sent to the server via RPC calls
     - Server verifies command legitimacy and unit ownership
     - Server calculates paths and updates unit states
     - State changes are synchronized to all clients

4. **Client-Side Behavior**
   - Custom property setters apply position and rotation changes on clients
   - Animation states are automatically updated based on synced properties
   - Clients display unit states but cannot directly modify them
   - Selection logic respects ownership constraints:
     - Players can select their own units freely
     - Enemy units can only be selected one at a time

## Synchronization Details

The solution uses a comprehensive two-way synchronization approach:

1. **Commands**: Client → Server via RPCs
   - Movement commands
   - Unit spawning requests
   - Selection changes (handled locally)

2. **State**: Server → Client via MultiplayerSynchronizer and RPCs
   - Position and rotation updates
   - Animation state changes
   - Pathing status
   - Ownership information

Custom properties with setters are used to apply received changes immediately for smooth visualization on clients.

## Developer Notes

### Testing Multiplayer
1. Run the game as host (press "Host" button)
2. Run a second instance as client (press "Join" button, ensure IP address is correct)
3. Verify that both players can spawn units using the spawn unit button
4. Verify units appear in the same positions across both instances
5. Test movement and selection behaviors:
   - Own units should move when commanded
   - Enemy units should not respond to movement commands
   - Enemy units can only be selected individually

### Troubleshooting
- If units don't appear on clients, check:
  - MultiplayerSpawner configuration in world.gd
  - Network connectivity between host and client
- If units appear but don't move on clients, check:
  - sync_position and sync_rotation properties in test_unit.gd
  - RPC calls for position updates
- If animations don't play correctly, verify:
  - sync_animation property synchronization
  - animation_player references in test_unit.gd
- If unit selection behaves incorrectly:
  - Check player_owner property is set correctly
  - Verify selection logic in Player_Interface.gd

### Future Improvements
- Add network interpolation for smoother unit movement
- Implement client-side prediction to reduce perceived latency
- Add visual feedback for ownership (different colors for different players)
- Implement lag compensation techniques
- Add network quality indicators and diagnostics
- Implement reconnection handling for dropped clients 