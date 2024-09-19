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

local function renderGame()
    stdio.write("\x1b[H");
    stdio.write("\x1b[2J");
    stdio.write(`Score: {#snake.tail}`);
    stdio.write(`\x1b[{snake.food.y + 1};{snake.food.x * 2}H`);
    stdio.write(`🍎`);
    stdio.write(`\x1b[{snake.y + 1};{snake.x * 2}H`);
    stdio.write(`🟩`);
    for i, v in snake.tail do
        stdio.write(`\x1b[{v.y + 1};{v.x * 2}H`);
        stdio.write(`🟩`);
    end
    stdio.write(`\x1b[{WIN_Y + 2};{0}H`);
end

spawnFood();

local _ = stdio.prompt("confirm", "How to play on lune:\n\n- Press ESC to continue to next frame.\n- Select the direction using arrow keys & press enter\n\nEnjoy!");

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
