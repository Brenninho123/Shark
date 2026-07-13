package shark.active.games;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class ReefRunnerState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;
	static inline var COLOR_DANGER:FlxColor = 0xFFF87171;

	var player:FlxSprite;
	var obstacles:Array<FlxSprite> = [];
	var scoreText:FlxText;
	var messageText:FlxText;
	var backButton:FlxButton;

	var groundY:Float;
	var isJumping:Bool = false;
	var jumpVelocity:Float = 0;

	var spawnTimer:Float = 0;
	var speed:Float = 260;
	var survivalTime:Float = 0;
	var isGameOver:Bool = false;
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		groundY = FlxG.height - 100;

		player = new FlxSprite(80, groundY - 40);
		player.makeGraphic(34, 40, COLOR_FOAM);
		add(player);

		var ground = new FlxSprite(0, groundY + 40).makeGraphic(FlxG.width, 4, COLOR_KELP);
		add(ground);

		scoreText = new FlxText(20, 20, 240, "Distance: 0");
		scoreText.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, LEFT);
		add(scoreText);

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

		survivalTime += elapsed;
		speed = 260 + survivalTime * 8;

		handleJumpInput();
		updateJumpPhysics(elapsed);
		updateObstacles(elapsed);
		checkCollisions();

		scoreText.text = 'Distance: ${Std.int(survivalTime * 20)}';
	}

	function handleJumpInput():Void
	{
		var jumpPressed:Bool = FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.UP;

		#if FLX_TOUCH
		if (!jumpPressed && FlxG.touches.getFirst() != null && FlxG.touches.getFirst().justPressed)
			jumpPressed = true;
		#end

		if (jumpPressed && !isJumping)
		{
			isJumping = true;
			jumpVelocity = -420;
		}
	}

	function updateJumpPhysics(elapsed:Float):Void
	{
		if (!isJumping)
			return;

		jumpVelocity += 1100 * elapsed;
		player.y += jumpVelocity * elapsed;

		if (player.y >= groundY - player.height)
		{
			player.y = groundY - player.height;
			isJumping = false;
			jumpVelocity = 0;
		}
	}

	function updateObstacles(elapsed:Float):Void
	{
		spawnTimer -= elapsed;

		if (spawnTimer <= 0)
		{
			spawnObstacle();
			spawnTimer = 1.1 - Math.min(survivalTime / 60, 0.6);
		}

		var i:Int = obstacles.length - 1;

		while (i >= 0)
		{
			var obstacle:FlxSprite = obstacles[i];
			obstacle.x -= speed * elapsed;

			if (obstacle.x < -obstacle.width)
			{
				remove(obstacle, true);
				obstacles.splice(i, 1);
			}

			i--;
		}
	}

	function spawnObstacle():Void
	{
		var height:Int = 30 + Std.random(30);
		var obstacle = new FlxSprite(FlxG.width + 20, groundY - height + 40);
		obstacle.makeGraphic(24, height, COLOR_DANGER);
		add(obstacle);
		obstacles.push(obstacle);
	}

	function checkCollisions():Void
	{
		for (obstacle in obstacles)
		{
			if (player.overlaps(obstacle))
			{
				endGame();
				return;
			}
		}
	}

	function endGame():Void
	{
		isGameOver = true;
		messageText.text = 'You crashed! Distance: ${Std.int(survivalTime * 20)}\nTap or press SPACE to retry';
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
