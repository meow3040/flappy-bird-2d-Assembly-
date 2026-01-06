# 2D Game Engine in x86_64 Assembly

A complete 2D game engine written in pure x86_64 Assembly for Windows, featuring window management, 2D rendering, input handling, collision detection, and a simple game with moving enemies.

## Features

- **Window Management**: Creates a resizable window using Windows API
- **2D Rendering**: Draws colored rectangles for player and enemies
- **Input Handling**: Keyboard input for arrow keys, space, and ESC
- **Game Loop**: Smooth 60 FPS game loop with proper frame timing
- **Collision Detection**: AABB (Axis-Aligned Bounding Box) collision detection
- **Simple Game**: Control a green player square, avoid red enemies that bounce around

## Requirements

- **NASM** (Netwide Assembler) - Download from https://www.nasm.us/
- **GCC** (MinGW-w64 for Windows) - Download from https://www.mingw-w64.org/
- **Windows 64-bit** operating system

## Installation

1. Install NASM:
   - Download NASM for Windows
   - Add NASM to your system PATH

2. Install MinGW-w64 (GCC):
   - Download MinGW-w64
   - Install the x86_64 version
   - Add the MinGW bin directory to your system PATH

3. Verify installations:
   ```cmd
   nasm -v
   gcc --version
   ```

## Building the Game

### Using the Build Script (Recommended)

Simply double-click `build.bat` or run from command line:

```cmd
build.bat
```

### Manual Build Commands

If you prefer to build manually:

```cmd
# Step 1: Assemble the .asm file
nasm -f win64 game.asm -o game.obj

# Step 2: Link with GCC
gcc game.obj -o game.exe -luser32 -lgdi32 -lkernel32 -mwindows

# Step 3: Run the game
game.exe
```

## How to Play

1. Run `game.exe`
2. A window will open showing:
   - **Green square** - Your player (starts in center)
   - **Red squares** - Enemies (5 total, bouncing around)
3. Use **Arrow Keys** to move your player
4. **Avoid the red enemies!**
5. If you collide with an enemy:
   - Your player resets to the center
   - Score increments (internal counter)
6. Press **ESC** to exit

## Controls

| Key | Action |
|-----|--------|
| ↑ | Move up |
| ↓ | Move down |
| ← | Move left |
| → | Move right |
| ESC | Exit game |

## Code Structure

The game is organized into modular functions:

### Core Systems

- **Window Management**
  - `register_window_class` - Registers the window class
  - `create_game_window` - Creates the game window
  - `window_proc` - Handles window messages

- **Game Loop**
  - `game_loop` - Main game loop (60 FPS)
  - `frame_timing` - Maintains consistent frame rate

- **Input System**
  - `update_input` - Polls keyboard state using GetAsyncKeyState

- **Game Logic**
  - `init_player` - Initializes player position
  - `init_enemies` - Sets up 5 enemies with different positions
  - `update_player` - Updates player position based on input
  - `update_enemies` - Moves enemies and bounces them off walls
  - `check_collisions` - AABB collision detection

- **Rendering**
  - `render_game` - Main rendering function
  - `render_background` - Draws black background
  - `render_player` - Draws green player square
  - `render_enemies` - Draws red enemy squares

### Data Structures

**Player**:
```
x, y          - Position (32-bit integers)
width, height - Size (32 pixels)
vx, vy        - Velocity
```

**Enemy** (5 total):
```
x, y          - Position
width, height - Size (24 pixels)
vx, vy        - Velocity (bounces on collision)
```

## Technical Details

### Architecture
- **64-bit x86 Assembly** (NASM syntax)
- **Windows API** for windowing and graphics
- **GDI (Graphics Device Interface)** for rendering

### Performance
- Target: 60 FPS (~16.67ms per frame)
- Uses `QueryPerformanceCounter` for high-resolution timing
- Sleeps when frame completes early to maintain consistent timing

### Collision Detection
Uses **AABB (Axis-Aligned Bounding Box)** algorithm:
```
Collision occurs when:
  player_x < enemy_x + enemy_width AND
  player_x + player_width > enemy_x AND
  player_y < enemy_y + enemy_height AND
  player_y + player_height > enemy_y
```

### Memory Layout
- `.data` - Initialized constants (colors, strings, sizes)
- `.bss` - Uninitialized game state (player, enemies, input)
- `.text` - Executable code

## Customization

You can easily modify the game by changing constants in the `.data` section:

```asm
WINDOW_WIDTH equ 800        ; Window width
WINDOW_HEIGHT equ 600       ; Window height
PLAYER_SIZE equ 32          ; Player size
ENEMY_SIZE equ 24           ; Enemy size
PLAYER_SPEED equ 5          ; Player movement speed
ENEMY_SPEED equ 2           ; Enemy movement speed
MAX_ENEMIES equ 5           ; Number of enemies

; Colors (RGB format)
COLOR_GREEN equ 0x0000FF00  ; Player color
COLOR_RED equ 0x000000FF    ; Enemy color
COLOR_BLACK equ 0x00000000  ; Background
```

## Extending the Engine

### Adding New Enemies
1. Increase `MAX_ENEMIES` constant
2. Add initialization code in `init_enemies`

### Adding Sprites/Textures
- Replace `FillRect` calls with `BitBlt` for bitmap rendering
- Load bitmaps using `LoadImageA`

### Adding Sound
- Use `PlaySound` from winmm.dll
- Link with `-lwinmm`

### Adding More Input
- Add more VK_* constants
- Check them in `update_input`

## Troubleshooting

**Error: "nasm: command not found"**
- NASM is not installed or not in PATH
- Install NASM and add to system PATH

**Error: "gcc: command not found"**
- MinGW-w64 is not installed or not in PATH
- Install MinGW-w64 and add bin directory to PATH

**Error: "undefined reference to GetModuleHandleA"**
- Missing library links
- Ensure you're linking with `-luser32 -lgdi32 -lkernel32`

**Game window doesn't open**
- Check Windows compatibility
- Run from command line to see error messages

**Game runs too fast/slow**
- Timing issue with `QueryPerformanceCounter`
- Adjust `TARGET_FRAME_TIME` constant

## Learning Resources

This project demonstrates:
- Windows API programming in Assembly
- 2D game development fundamentals
- Memory management
- Function calling conventions (x64 Windows)
- Game loop architecture
- Input handling
- Collision detection algorithms

## License

This is educational code provided as-is. Feel free to modify and learn from it!

## Credits

Created as a demonstration of x86_64 Assembly game programming on Windows.
