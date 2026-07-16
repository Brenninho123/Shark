package shark.active;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shark.active.games.BubblePopState;
import shark.active.games.ReefRunnerState;
import shark.active.games.DeepDiveState;
import shark.menus.MainMenuState;

typedef GameEntry = {
	id:String,
	title:String,
	description:String,
	icon:String,
	accentColor:FlxColor,
	?stateClass:Class<FlxState>
}

class GameState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_WAVE:FlxColor = 0xFF2C7DA0;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;
	static inline var COLOR_BUBBLE:FlxColor = 0xFF7FD8E8;
	static inline var COLOR_REEF:FlxColor = 0xFFEF9F76;

	var games:Array<GameEntry> = [
		{
			id: "bubble_pop",
			title: "Bubble Pop",
			description: "Pop rising bubbles before they escape.",
			icon: "o O o",
			accentColor: COLOR_BUBBLE,
			stateClass: BubblePopState
		},
		{
			id: "reef_runner",
			title: "Reef Runner",
			description: "Dodge obstacles swimming through the reef.",
			icon: ">>>",
			accentColor: COLOR_REEF,
			stateClass: ReefRunnerState
		},
		{
			id: "deep_dive",
			title: "Deep Dive",
			description: "See how far you can dive before hitting a rock.",
			icon: "\\ /",
			accentColor: COLOR_ACCENT,
			stateClass: DeepDiveState
		}
	];

	var buttonGroup:FlxTypedGroup<FlxButton>;
	var titleText:FlxText;
	var subtitleText:FlxText;
	var backButton:FlxButton;
	var isMobile:Bool;

	var cardSprites:Array<{sprite:FlxSprite, baseY:Float, offset:Float}> = [];
	var bubbles:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];
	var lightRays:Array<FlxSprite> = [];

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		createDepthGradient();
		createLightRays();
		createKelp();
		createBubbles();

		titleText = new FlxText(0, isMobile ? 26 : 18, FlxG.width, "SELECT A GAME");
		titleText.setFormat(null, isMobile ? 34 : 28, COLOR_FOAM, CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		subtitleText = new FlxText(0, titleText.y + titleText.height + 2, FlxG.width, "type !play in chat anytime to come back here");
		subtitleText.setFormat(null, isMobile ? 14 : 12, COLOR_ACCENT, CENTER);
		add(subtitleText);

		createGameList();

		backButton = new FlxButton(20, FlxG.height - (isMobile ? 70 : 50), "Back", onBackPressed);
		backButton.setSize(isMobile ? 120 : 90, isMobile ? 50 : 32);
		backButton.color = COLOR_MID;
		backButton.label.color = COLOR_FOAM;
		backButton.alpha = 0;
		add(backButton);

		FlxTween.tween(backButton, {alpha: 1}, 0.4, {startDelay: 0.2 + games.length * 0.1});
	}

	function createDepthGradient():Void
	{
		var bands:Array<FlxColor> = [COLOR_ABYSS, COLOR_DEEP, COLOR_MID];
		var bandHeight:Int = Std.int(FlxG.height / bands.length) + 2;

		for (i in 0...bands.length)
		{
			var band = new FlxSprite(0, i * bandHeight);
			band.makeGraphic(FlxG.width, bandHeight, bands[i]);
			band.scrollFactor.set(0, 0);
			add(band);
		}
	}

	function createLightRays():Void
	{
		var rayCount:Int = isMobile ? 3 : 5;

		for (i in 0...rayCount)
		{
			var ray = new FlxSprite(Std.random(FlxG.width), -100);
			ray.makeGraphic(30 + Std.random(20), FlxG.height + 200, COLOR_FOAM);
			ray.angle = -15;
			ray.alpha = 0.03 + Std.random(4) / 100;
			ray.scrollFactor.set(0, 0);
			add(ray);
			lightRays.push(ray);

			FlxTween.tween(ray, {x: ray.x + 60}, 8 + Std.random(4), {
				ease: FlxEase.sineInOut,
				type: PINGPONG
			});
		}
	}

	function createKelp():Void
	{
		var bladeCount:Int = isMobile ? 4 : 7;

		for (i in 0...bladeCount)
		{
			var height:Int = 30 + Std.random(50);
			var blade = new FlxSprite((i / bladeCount) * FlxG.width + Std.random(20), FlxG.height - height);
			blade.makeGraphic(8, height, COLOR_KELP);
			blade.alpha = 0.4;
			blade.origin.set(4, height);
			add(blade);

			kelpBlades.push({sprite: blade, offset: Std.random(6283) / 1000, speed: 1 + Std.random(50) / 100});
		}
	}

	function createBubbles():Void
	{
		var bubbleCount:Int = isMobile ? 6 : 10;

		for (i in 0...bubbleCount)
		{
			var size:Int = 3 + Std.random(8);
			var bubble = new FlxSprite(Std.random(FlxG.width), FlxG.height + Std.random(200));
			bubble.makeGraphic(size, size, COLOR_ACCENT);
			bubble.alpha = 0.25 + Std.random(30) / 100;
			add(bubble);
			bubbles.push(bubble);
		}
	}

	function createGameList():Void
	{
		buttonGroup = new FlxTypedGroup<FlxButton>();
		add(buttonGroup);

		var startY:Float = isMobile ? 130 : 100;
		var spacing:Float = isMobile ? 130 : 92;
		var cardWidth:Float = FlxG.width - (isMobile ? 50 : 120);
		var cardX:Float = (FlxG.width - cardWidth) / 2;
		var cardHeight:Float = spacing - 14;

		for (i in 0...games.length)
		{
			var entry:GameEntry = games[i];
			var cardY:Float = startY + i * spacing;

			var shadow = new FlxSprite(cardX + 4, cardY + 4).makeGraphic(Std.int(cardWidth), Std.int(cardHeight), COLOR_ABYSS);
			shadow.alpha = 0.4;
			add(shadow);

			var card = new FlxSprite(cardX, cardY).makeGraphic(Std.int(cardWidth), Std.int(cardHeight), COLOR_MID);
			add(card);

			var accentBar = new FlxSprite(cardX, cardY).makeGraphic(6, Std.int(cardHeight), entry.accentColor);
			add(accentBar);

			var iconBadge = new FlxSprite(cardX + 20, cardY + cardHeight / 2 - 18).makeGraphic(36, 36, entry.accentColor);
			add(iconBadge);

			var iconLabel = new FlxText(cardX + 20, cardY + cardHeight / 2 - 18, 36, entry.icon);
			iconLabel.setFormat(null, 10, COLOR_ABYSS, CENTER);
			add(iconLabel);

			var titleLabel = new FlxText(cardX + 70, cardY + 12, cardWidth - 90, entry.title);
			titleLabel.setFormat(null, isMobile ? 22 : 18, COLOR_FOAM, LEFT);
			add(titleLabel);

			var descLabel = new FlxText(cardX + 70, cardY + 12 + (isMobile ? 28 : 24), cardWidth - 190, entry.description);
			descLabel.setFormat(null, isMobile ? 13 : 12, COLOR_ACCENT, LEFT);
			add(descLabel);

			var playButton = new FlxButton(cardX + cardWidth - (isMobile ? 100 : 80), cardY + cardHeight / 2 - (isMobile ? 22 : 16), "Play",
				makeSelectHandler(entry));
			playButton.setSize(isMobile ? 80 : 64, isMobile ? 44 : 32);
			playButton.color = entry.accentColor;
			playButton.label.color = COLOR_ABYSS;
			buttonGroup.add(playButton);

			var delay:Float = i * 0.1;

			animateCardElement(shadow, 0.4, delay);
			animateCardElement(card, 0.35, delay);
			animateCardElement(accentBar, 0.9, delay);
			animateCardElement(iconBadge, 0.85, delay);
			animateCardElement(iconLabel, 1, delay);
			animateCardElement(titleLabel, 1, delay);
			animateCardElement(descLabel, 1, delay);
			animateCardElement(playButton, 1, delay);

			cardSprites.push({sprite: card, baseY: cardY, offset: Std.random(6283) / 1000});
			cardSprites.push({sprite: accentBar, baseY: cardY, offset: cardSprites[cardSprites.length - 1].offset});
		}
	}

	function animateCardElement(sprite:FlxSprite, targetAlpha:Float, delay:Float):Void
	{
		var startY:Float = sprite.y;
		sprite.y += 20;
		sprite.alpha = 0;

		FlxTween.tween(sprite, {y: startY, alpha: targetAlpha}, 0.4, {
			ease: FlxEase.quadOut,
			startDelay: delay
		});
	}

	function makeSelectHandler(entry:GameEntry):Void->Void
	{
		return function():Void
		{
			onGameSelected(entry);
		};
	}

	function onGameSelected(entry:GameEntry):Void
	{
		if (entry.stateClass != null)
		{
			FlxG.switchState(Type.createInstance(entry.stateClass, []));
			return;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (bubble in bubbles)
		{
			bubble.y -= elapsed * (18 + bubble.width * 4);

			if (bubble.y < -bubble.height)
			{
				bubble.y = FlxG.height + Std.random(100);
				bubble.x = Std.random(FlxG.width);
			}
		}

		for (blade in kelpBlades)
		{
			blade.offset += elapsed * blade.speed;
			blade.sprite.angle = Math.sin(blade.offset) * 5;
		}
	}

	function onBackPressed():Void
	{
		FlxG.switchState(new MainMenuState());
	}
}
