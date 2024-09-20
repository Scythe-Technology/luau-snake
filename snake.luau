--!strict
local stdio = require("@zcore/stdio");
local task = require("@zcore/task");
local process = require("@zcore/process");

assert(stdio.terminal.isTTY, "You must run this program in a interactive terminal");
assert(stdio.terminal:enableRawMode(), "Failed to enable raw mode");

local WIN_X, WIN_Y = stdio.terminal:getSize();

WIN_X -= 1;
WIN_Y -= 1;

WIN_X = math.min(WIN_X, 30);
WIN_Y = math.min(WIN_Y, 12);
WIN_Y -= 1;

local SPEED = 0.145;

local DIR_UP = 0;
local DIR_RIGHT = 1;
local DIR_DOWN = 2;
local DIR_LEFT = 3;

type SnakePart = {
    x: number,
    y: number,
    dir: number,
}

type SnakeTail = {
    x: number,
    y: number,
    dir: number,
    spawned: boolean?,
}

local snake = {
    x = WIN_X // 2,
    y = WIN_Y // 2,
    dir = 0,
    tail = {}::{SnakeTail},
    food = {
        x = 0,
        y = 0
    }
};

local function checkTailCollision(x, y)
    for i, v in snake.tail do
        if (v.spawned) then
            continue;
        end
        if (v.x == x and v.y == y) then
            return true;
        end
    end
    return false;
end
local function checkSnakeCollision(x, y)
    if (snake.x == x and snake.y) then
        return true;
    end
    return checkTailCollision(x, y);
end

local function spawnFood()
    local nx = math.random(1, WIN_X // 2);
    local ny = math.random(1, WIN_Y);
    while (checkSnakeCollision(nx, ny)) do
        nx = math.random(1, WIN_X // 2);
        ny = math.random(1, WIN_Y);
    end
    snake.food.x = nx;
    snake.food.y = ny;
end

type RenderedPart = {
    x: number,
    y: number,
}

local LAST_RENDER_STATE = {
    score = -1,
    food = {
        x = -1,
        y = -1
    },
    parts = {}::{RenderedPart},
};

local function clearPart(part : RenderedPart)
    stdio.stdout:write(stdio.cursorMove("goto", part.y + 1, part.x * 2));
    stdio.stdout:write(" ");
end

local function isInitialized(part : RenderedPart)
    return part.x ~= -1 and part.y ~= -1;
end

local function copyPart(part : RenderedPart, copy : RenderedPart)
    part.x = copy.x;
    part.y = copy.y;
end

local function isDiff(part : RenderedPart, other : RenderedPart)
    return part.x ~= other.x or part.y ~= other.y;
end

local function renderSnake()
    local function renderPart(x : number, y : number)
        stdio.stdout:write(stdio.cursorMove("goto", y + 1, x * 2));
        stdio.stdout:write("🟩");
    end

    local RenderQueue = {}::{RenderedPart};
    local ClearQueue = {}::{RenderedPart};

    for i, v in LAST_RENDER_STATE.parts do
        if (not isDiff(snake, v)) then
            continue;
        end
        local flag = false;
        for _, tail in snake.tail do
            if (not isDiff(tail, v)) then
                flag = true;
                break;
            end
        end
        if (flag) then
            continue;
        end
        table.insert(ClearQueue, v);
        break;
    end

    do
        local flag = false;
        for _, part in LAST_RENDER_STATE.parts do
            if (not isDiff(snake, part)) then
                flag = true;
                break;
            end
        end
        if (not flag) then
            table.insert(RenderQueue, snake);
        end
    end

    for i, v in snake.tail do
        local flag = false;
        for _, part in LAST_RENDER_STATE.parts do
            if (not isDiff(v, part)) then
                flag = true;
                break;
            end
        end
        if (not flag) then
            table.insert(RenderQueue, v);
        end
    end

    for _, v in ClearQueue do
        clearPart(v);
        for i = #LAST_RENDER_STATE.parts, 1, -1 do
            if (not isDiff(LAST_RENDER_STATE.parts[i], v)) then
                table.remove(LAST_RENDER_STATE.parts, i);
                break;
            end
        end
    end

    for i, v in RenderQueue do
        renderPart(v.x, v.y);
        table.insert(LAST_RENDER_STATE.parts, {
            x = v.x,
            y = v.y
        });
    end
end

local function renderGame()
    stdio.stdout:write(stdio.cursorMove("home"));
    if (LAST_RENDER_STATE.score ~= #snake.tail) then
        stdio.stdout:write(`Score: {#snake.tail}`);
        LAST_RENDER_STATE.score = #snake.tail;
    end
    if (isDiff(LAST_RENDER_STATE.food, snake.food)) then
        if (isInitialized(LAST_RENDER_STATE.food)) then
            clearPart(LAST_RENDER_STATE.food);
        end
        stdio.stdout:write(stdio.cursorMove("goto", snake.food.y + 1, snake.food.x * 2));
        stdio.stdout:write("🍎");
        copyPart(LAST_RENDER_STATE.food, snake.food);
    end

    renderSnake();

    stdio.stdout:write(stdio.cursorMove("goto", WIN_Y + 1, WIN_X));
end

spawnFood();

local _sig_count = 0;
local _sig_quit_reset: thread?;
local function gameInterrupt()
    _sig_count += 1;
    if (_sig_count > 1) then
        if (not stdio.terminal:restoreMode()) then
            print("Failed to restore terminal mode, depending on your terminal you might crash");
        end
        
        process.exit(0);
    else
        print("Press Ctrl+C again to exit");
        if (_sig_quit_reset) then
            task.cancel(_sig_quit_reset);
        end
        _sig_quit_reset = task.delay(1.5, function()
            _sig_count = 0;
            _sig_quit_reset = nil;
        end);
    end
end

process.onSignal("INT", gameInterrupt);

local function growSnake()
    local last = snake.tail[#snake.tail] or snake;
    table.insert(snake.tail, {
        x = last.x,
        y = last.y,
        dir = last.dir,
        spawned = true;
    });
end


local function forwardMotion(part : SnakePart): (number, number)
    local x, y = part.x, part.y;
    if (part.dir == DIR_UP) then
        y -= 1;
    elseif (part.dir == DIR_DOWN) then
        y += 1;
    elseif (part.dir == DIR_RIGHT) then
        x += 1;
    elseif (part.dir == DIR_LEFT) then
        x -= 1;
    end

    if (x < 1) then
        x = WIN_X//2;
    elseif (x > WIN_X//2) then
        x = 1;
    end
    if (y < 1) then
        y = WIN_Y;
    elseif (y > WIN_Y) then
        y = 1;
    end
    return x, y
end

local function moveFigure(part : SnakePart)
    part.x, part.y = forwardMotion(part);
end

local DIRECTION_QUEUE = {}::{number};
task.spawn(function()
    while true do
        task.wait();
        local input = stdio.stdin:read(3);
        if (not input) then
            continue;
        end

        local inputs = {input:byte(1, 3)};
        if (inputs[1] == 0x1B) then
            if (inputs[2] ~= 91) then
                continue;
            end
            local lastDir = DIRECTION_QUEUE[#DIRECTION_QUEUE] or snake.dir;
            local newDirection;
            if (inputs[3] == 65) then
                newDirection= DIR_UP;
            elseif (inputs[3] == 66) then
                newDirection = DIR_DOWN;
            elseif (inputs[3] == 67) then
                newDirection = DIR_RIGHT;
            elseif (inputs[3] == 68) then
                newDirection = DIR_LEFT;
            else
                continue;
            end
            if (lastDir == newDirection) then
                continue;
            end
            local nX, nY = forwardMotion({
                x = snake.x,
                y = snake.y,
                dir = newDirection
            })
            if (checkTailCollision(nX, nY)) then
                continue;
            end
            table.insert(DIRECTION_QUEUE, newDirection);
        elseif (inputs[1] == 0x03 or inputs[1] == 0x04) then
            gameInterrupt();
        end
    end
end)

stdio.stdout:write(stdio.erase("entire"));

while true do
    task.wait(SPEED);

    local newDir = table.remove(DIRECTION_QUEUE, 1);
    if (newDir) then
        snake.dir = newDir;
    end

    moveFigure(snake);
    for i = #snake.tail, 1, -1 do
        local v = snake.tail[i];
        if (v.spawned) then
            v.spawned = nil;
        else
            moveFigure(v);
        end
        if (i == 1) then
            v.dir = snake.dir;
        else
            v.dir = snake.tail[i - 1].dir;
        end
    end

    if (snake.x == snake.food.x and snake.y == snake.food.y) then
        spawnFood();
        growSnake();
    end

    if (checkTailCollision(snake.x, snake.y)) then
        break;
    end

    renderGame();
end

stdio.stdout:write(stdio.cursorMove("home"));
stdio.stdout:write(stdio.erase("entire"));
stdio.stdout:write(`You died, score {#snake.tail}\n`);
if (not stdio.terminal:restoreMode()) then
    print("Failed to restore terminal mode, depending on your terminal you might crash");
end

process.exit(0);