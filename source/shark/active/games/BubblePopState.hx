package shark.active.games;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;

class BubblePopState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_DANGER:FlxColor = 0xFFF87171;

	static inline var MAX_MISSES:Int = 5;
	static inline var ROUND_SECONDS:Float = 60;

	var bubbles:Array<FlxSprite> = [];
	var scoreText:FlxText;
	var missesText:FlxText;
	var timeText:FlxText;
	var messageText:FlxText;
	var backButton:FlxButton;

	var score:Int = 0;
	var misses:Int = 0;
	var timeLeft:Float = ROUND_SECONDS;
	var spawnTimer:Float = 0;
	var isGameOver:Bool = false;
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		scoreText = new FlxText(20, 20, 200, "Score: 0");
		scoreText.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, LEFT);
		add(scoreText);

		missesText = new FlxText(20, 46, 200, 'Missed: 0/$MAX_MISSES');
		missesText.setFormat(null, isMobile ? 18 : 14, COLOR_DANGER, LEFT);
		add(missesText);

		timeText = new FlxText(FlxG.width - 140, 20, 120, "");
		timeText.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, RIGHT);
		add(timeText);

		messageText = new FlxText(0, FlxG.height / 2 - 40, FlxG.width, "");
		messageText.setFormat(null, isMobile ? 32 : 26, COLOR_FOAM, CENTER);
		add(messageText);

		backButton = new FlxButton(20, FlxG.height - (isMobile ? 70 : 50), "Back", onBackPressed);
		backButton.setSize(isMobile ? 120 : 90, isMobile ? 50 : 32);
		backButton.color = COLOR_ACCENT;
		backButton.label.color = COLOR_ABYSS;
		add(backButton);

		updateHud();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (isGameOver)
			return;

		timeLeft -= elapsed;

		if (timeLeft <= 0)
		{
			endGame(true);
			return;
		}

		spawnTimer -= elapsed;

		if (spawnTimer <= 0)
		{
			spawnBubble();
			spawnTimer = 0.5 + Std.random(60) / 100;
		}

		updateBubbles(elapsed);
		handleInput();
		updateHud();
	}

	function spawnBubble():Void
	{
		var size:Int = 24 + Std.random(28);
		var bubble = new FlxSprite(Std.random(FlxG.width - size), FlxG.height + size);
		bubble.makeGraphic(size, size, COLOR_ACCENT);
		bubble.alpha = 0.75;
		add(bubble);
		bubbles.push(bubble);
	}

	function updateBubbles(elapsed:Float):Void
	{
		var i:Int = bubbles.length - 1;

		while (i >= 0)
		{
			var bubble:FlxSprite = bubbles[i];
			bubble.y -= elapsed * (60 + bubble.width);

			if (bubble.y < -bubble.height)
			{
				remove(bubble, true);
				bubbles.splice(i, 1);
				registerMiss();
			}

			i--;
		}
	}

	function handleInput():Void
	{
		var pointerDown:Bool = FlxG.mouse.justPressed;

		#if FLX_TOUCH
		if (!pointerDown && FlxG.touches.getFirst() != null && FlxG.touches.getFirst().justPressed)
			pointerDown = true;
		#end

		if (!pointerDown)
			return;

		var pointer:FlxPoint = FlxG.mouse.getWorldPosition();
		var i:Int = bubbles.length - 1;

		while (i >= 0)
		{
			var bubble:FlxSprite = bubbles[i];

			if (bubble.overlapsPoint(pointer))
			{
				remove(bubble, true);
				bubbles.splice(i, 1);
				score++;
				break;
			}

			i--;
		}

		pointer.put();
	}

	function registerMiss():Void
	{
		misses++;

		if (misses >= MAX_MISSES)
			endGame(false);
	}

	function updateHud():Void
	{
		scoreText.text = 'Score: $score';
		missesText.text = 'Missed: $misses/$MAX_MISSES';
		timeText.text = 'Time: ${Std.int(timeLeft)}';
	}

	function endGame(completedRound:Bool):Void
	{
		isGameOver = true;
		messageText.text = completedRound ? 'Time up! Final score: $score' : 'Too many escaped! Score: $score';
	}

	function onBackPressed():Void
	{
		FlxG.switchState(new shark.active.GameState());
	}
}
