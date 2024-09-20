--!strict
local stdio = require("@lune/stdio");
local process = require("@lune/process");

local WIN_X = 30;
local WIN_Y = 11;

local DIR_UP = 0;
local DIR_DOWN = 1;
local DIR_LEFT = 2;
local DIR_RIGHT = 3;

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
    stdio.write(`\x1b[{part.y + 1};{(part.x * 2) + 1}H`);
    stdio.write("  ");
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
        stdio.write(`\x1b[{y + 1};{(x * 2) + 1}H`);
        stdio.write("\x1b[42m");
        stdio.write(`  `);
        stdio.write(stdio.color("reset"));
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

    for i = #RenderQueue, 1, -1 do
        local flag = false;
        for ipart, part in RenderQueue do
            if (i == ipart) then
                continue;
            end
            if (not isDiff(RenderQueue[i], part)) then
                flag = true;
                break;
            end
        end
        if (flag) then
            table.remove(RenderQueue, i);
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

local function renderBorder()
    for i = 1, WIN_Y do
        stdio.write(`\x1b[{i + 1};{1}H`);
        stdio.write("\x1b[47m");
        stdio.write("  ");
        stdio.write(stdio.color("reset"));
        stdio.write(`\x1b[{i + 1};{WIN_X + 3}H`);
        stdio.write("\x1b[47m");
        stdio.write("  ");
        stdio.write(stdio.color("reset"));
    end
    stdio.write(`\x1b[47m`);
    stdio.write(`\x1b[{WIN_Y + 2};0H`);
    stdio.write(`{string.rep(" ", WIN_X + 4)}`);
    stdio.write(stdio.color("reset"));
end

local function renderGame()
    if (LAST_RENDER_STATE.score ~= #snake.tail) then
        stdio.write(`\x1b[H`);
        local ScoreDisplay = `Score: {#snake.tail}`;
        stdio.write(`\x1b[47m{ScoreDisplay}`);
        stdio.write(`{string.rep(" ", WIN_X + 4 - #ScoreDisplay)}`);
        stdio.write(stdio.color("reset"));

        LAST_RENDER_STATE.score = #snake.tail;
    end

    local renderApple = false;
    if (isDiff(LAST_RENDER_STATE.food, snake.food)) then
        if (isInitialized(LAST_RENDER_STATE.food)) then
            clearPart(LAST_RENDER_STATE.food);
        end
        renderApple = true;
    end

    renderSnake();

    if (renderApple) then
        stdio.write(`\x1b[{snake.food.y + 1};{(snake.food.x * 2) + 1}H`);
        stdio.write("🍎");
        copyPart(LAST_RENDER_STATE.food, snake.food);
    end
    
    stdio.write(`\x1b[{WIN_Y + 3};{0}H`);
    stdio.write("\x1b[?25l");
end

spawnFood();

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

local _ = stdio.prompt("confirm", "How to play on lune:\n\n- Press ESC to continue to next frame.\n- Select the direction using arrow keys & press enter\n\nEnjoy!");

stdio.write("\x1b[2J");

renderBorder()

while true do
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

    while true do
        local input = stdio.prompt("select", "MOVE", {"UP", "DOWN", "LEFT", "RIGHT"});
        if (not input) then
            break;
        end
        local lastDir = snake.dir;
        snake.dir = input - 1;
        local nX, nY = forwardMotion(snake)
        if (checkTailCollision(nX, nY)) then
            snake.dir = lastDir;
        else
            break;
        end
    end
end

stdio.write("\x1b[H");
stdio.write("\x1b[2J");
stdio.write(`You died, score {#snake.tail}\n`);
process.exit(0);
