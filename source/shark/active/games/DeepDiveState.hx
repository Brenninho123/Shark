package shark.active.games;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;

class DeepDiveState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_DANGER:FlxColor = 0xFFF87171;

	var player:FlxSprite;
	var rocks:Array<FlxSprite> = [];
	var depthText:FlxText;
	var messageText:FlxText;
	var backButton:FlxButton;

	var depth:Float = 0;
	var descendSpeed:Float = 120;
	var spawnTimer:Float = 0;
	var isGameOver:Bool = false;
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_DEEP;

		player = new FlxSprite(FlxG.width / 2 - 15, 80);
		player.makeGraphic(30, 30, COLOR_FOAM);
		add(player);

		depthText = new FlxText(20, 20, 240, "Depth: 0m");
		depthText.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, LEFT);
		add(depthText);

		messageText = new FlxText(0, FlxG.height / 2 - 40, FlxG.width, "");
		messageText.setFormat(null, isMobile ? 32 : 26, COLOR_FOAM, CENTER);
		add(messageText);

		backButton = new FlxButton(20, FlxG.height - (isMobile ? 70 : 50), "Back", onBackPressed);
		backButton.setSize(isMobile ? 120 : 90, isMobile ? 50 : 32);
		backButton.color = COLOR_ACCENT;
		backButton.label.color = COLOR_ABYSS;
		add(backButton);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isGameOver)
		{
			handleRestartInput();
			return;
		}

		depth += descendSpeed * elapsed / 20;
		descendSpeed = 120 + depth * 1.5;

		handleMovementInput(elapsed);
		updateRocks(elapsed);
		checkCollisions();

		depthText.text = 'Depth: ${Std.int(depth)}m';
	}

	function handleMovementInput(elapsed:Float):Void
	{
		var moveSpeed:Float = 320;

		if (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A)
			player.x -= moveSpeed * elapsed;

		if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D)
			player.x += moveSpeed * elapsed;

		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null)
		{
			var targetX:Float = touch.x - player.width / 2;
			player.x += (targetX - player.x) * Math.min(elapsed * 10, 1);
		}
		#end

		if (player.x < 0)
			player.x = 0;

		if (player.x > FlxG.width - player.width)
			player.x = FlxG.width - player.width;
	}

	function updateRocks(elapsed:Float):Void
	{
		spawnTimer -= elapsed;

		if (spawnTimer <= 0)
		{
			spawnRock();
			spawnTimer = 0.9 - Math.min(depth / 400, 0.5);
		}

		var i:Int = rocks.length - 1;

		while (i >= 0)
		{
			var rock:FlxSprite = rocks[i];
			rock.y += descendSpeed * elapsed;

			if (rock.y > FlxG.height)
			{
				remove(rock, true);
				rocks.splice(i, 1);
			}

			i--;
		}
	}

	function spawnRock():Void
	{
		var size:Int = 24 + Std.random(30);
		var rock = new FlxSprite(Std.random(FlxG.width - size), -size);
		rock.makeGraphic(size, size, COLOR_DANGER);
		add(rock);
		rocks.push(rock);
	}

	function checkCollisions():Void
	{
		for (rock in rocks)
		{
			if (player.overlaps(rock))
			{
				endGame();
				return;
			}
		}
	}

	function endGame():Void
	{
		isGameOver = true;
		messageText.text = 'You hit a rock! Depth reached: ${Std.int(depth)}m\nTap or press SPACE to retry';
	}

	function handleRestartInput():Void
	{
		var restartPressed:Bool = FlxG.keys.justPressed.SPACE;

		#if FLX_TOUCH
		if (!restartPressed && FlxG.touches.getFirst() != null && FlxG.touches.getFirst().justPressed)
			restartPressed = true;
		#end

		if (restartPressed)
			FlxG.resetState();
	}

	function onBackPressed():Void
	{
		FlxG.switchState(new shark.active.GameState());
	}
}
