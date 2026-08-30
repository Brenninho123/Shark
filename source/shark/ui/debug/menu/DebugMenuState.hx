package shark.ui.debug.menu;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import git.graphic.GraphicGit;
import shark.menus.MainMenuState;
import shark.mobile.backend.Vibration.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.modding.api.ModVersion;
import shark.ui.debug.CrasherLog;
import Main;

typedef DebugMenuEntry = {
	label:String,
	description:String,
	stateClassName:String,
	enabled:Bool
}

class DebugMenuState extends FlxState
{
	static inline var ROW_HEIGHT:Float = 64;
	static inline var ROW_WIDTH:Float = 420;
	static inline var ROW_SPACING:Float = 12;
	static inline var TOP_MARGIN:Float = 120;

	var entries:Array<DebugMenuEntry>;
	var selectedIndex:Int = 0;

	var rowBackgrounds:Array<FlxSprite> = [];
	var rowLabels:Array<FlxText> = [];
	var rowDescriptions:Array<FlxText> = [];

	var titleText:FlxText;
	var footerText:FlxText;
	var unavailableText:FlxText;
	var unavailableTween:FlxTween;

	public function new()
	{
		super();

		entries = buildEntries();
	}

	function buildEntries():Array<DebugMenuEntry>
	{
		return [
			{
				label: "Chat Editor",
				description: "Edit chat prompts, history, and live API settings.",
				stateClassName: "shark.ui.debug.chat.ChatEditorState",
				enabled: true
			}
		];
	}

	override function create():Void
	{
		super.create();

		buildBackground();
		buildTitle();
		buildRows();
		buildFooter();

		CrasherLog.addBreadcrumb("Opened debug menu (editor mode)", "navigation");
	}

	function buildBackground():Void
	{
		var background:FlxSprite = GraphicGit.makeGradientSprite(0, 0, Std.int(FlxG.width), Std.int(FlxG.height), FlxColor.fromRGB(10, 18, 28),
			FlxColor.fromRGB(4, 8, 14));
		background.scrollFactor.set(0, 0);
		add(background);
	}

	function buildTitle():Void
	{
		titleText = new FlxText(0, 40, FlxG.width, "EDITOR MODE");
		titleText.setFormat(null, 28, FlxColor.WHITE, FlxTextAlign.CENTER);
		titleText.alpha = 0.95;
		add(titleText);

		var subtitle:FlxText = new FlxText(0, 76, FlxG.width, "Select a tool to open");
		subtitle.setFormat(null, 14, FlxColor.fromRGB(160, 180, 200), FlxTextAlign.CENTER);
		add(subtitle);
	}

	function buildRows():Void
	{
		var startX:Float = (FlxG.width - ROW_WIDTH) / 2;

		for (i in 0...entries.length)
		{
			var entry:DebugMenuEntry = entries[i];
			var rowY:Float = TOP_MARGIN + i * (ROW_HEIGHT + ROW_SPACING);

			var background:FlxSprite = GraphicGit.makeFilledRoundedRectWithBorderSprite(startX, rowY, Std.int(ROW_WIDTH), Std.int(ROW_HEIGHT),
				rowFillColor(i), rowBorderColor(i), 10, 2);
			background.alpha = entry.enabled ? 1 : 0.5;
			add(background);
			rowBackgrounds.push(background);

			var label:FlxText = new FlxText(startX + 20, rowY + 10, ROW_WIDTH - 40, entry.label);
			label.setFormat(null, 20, entry.enabled ? FlxColor.WHITE : FlxColor.GRAY);
			add(label);
			rowLabels.push(label);

			var description:FlxText = new FlxText(startX + 20, rowY + 36, ROW_WIDTH - 40, entry.description);
			description.setFormat(null, 12, entry.enabled ? FlxColor.fromRGB(190, 205, 220) : FlxColor.fromRGB(120, 120, 120));
			add(description);
			rowDescriptions.push(description);
		}

		refreshSelectionVisuals();
	}

	function buildFooter():Void
	{
		footerText = new FlxText(0, FlxG.height - 40, FlxG.width, "Up/Down to navigate - Enter to open - Esc to go back");
		footerText.setFormat(null, 12, FlxColor.fromRGB(140, 150, 160), FlxTextAlign.CENTER);
		add(footerText);

		var statusLine:String = 'Mod API ${ModVersion.CURRENT}${Main.isSafeMode ? " - SAFE MODE" : ""}';
		var statusText:FlxText = new FlxText(0, FlxG.height - 22, FlxG.width, statusLine);
		statusText.setFormat(null, 11, FlxColor.fromRGB(100, 110, 120), FlxTextAlign.CENTER);
		add(statusText);

		unavailableText = new FlxText(0, FlxG.height - 64, FlxG.width, "");
		unavailableText.setFormat(null, 13, FlxColor.fromRGB(255, 140, 140), FlxTextAlign.CENTER);
		unavailableText.alpha = 0;
		add(unavailableText);
	}

	function rowFillColor(index:Int):FlxColor
	{
		return index == selectedIndex ? FlxColor.fromRGB(30, 60, 90) : FlxColor.fromRGB(18, 28, 40);
	}

	function rowBorderColor(index:Int):FlxColor
	{
		return index == selectedIndex ? FlxColor.fromRGB(90, 180, 255) : FlxColor.fromRGB(50, 60, 72);
	}

	function refreshSelectionVisuals():Void
	{
		for (i in 0...rowBackgrounds.length)
		{
			var entry:DebugMenuEntry = entries[i];

			rowBackgrounds[i].pixels = GraphicGit.createFilledRoundedRectWithBorder(Std.int(ROW_WIDTH), Std.int(ROW_HEIGHT), rowFillColor(i),
				rowBorderColor(i), 10, 2);
			rowBackgrounds[i].alpha = entry.enabled ? 1 : 0.5;
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		handleKeyboardInput();
		handlePointerInput();
	}

	function handleKeyboardInput():Void
	{
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
			moveSelection(-1);
		else if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
			moveSelection(1);
		else if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			confirmSelection();
		else if (FlxG.keys.justPressed.ESCAPE)
			goBack();
	}

	function handlePointerInput():Void
	{
		if (!FlxG.mouse.justPressed)
			return;

		for (i in 0...rowBackgrounds.length)
		{
			if (FlxG.mouse.overlaps(rowBackgrounds[i]))
			{
				selectedIndex = i;
				refreshSelectionVisuals();
				confirmSelection();
				return;
			}
		}
	}

	function moveSelection(direction:Int):Void
	{
		if (entries.length == 0)
			return;

		selectedIndex = (selectedIndex + direction + entries.length) % entries.length;
		refreshSelectionVisuals();
		Vibration.trigger(HapticStyle.SELECTION);
	}

	function confirmSelection():Void
	{
		if (entries.length == 0)
			return;

		var entry:DebugMenuEntry = entries[selectedIndex];

		if (!entry.enabled)
		{
			showUnavailable('${entry.label} is disabled.');
			return;
		}

		openEntry(entry);
	}

	function openEntry(entry:DebugMenuEntry):Void
	{
		var stateClass:Dynamic = Type.resolveClass(entry.stateClassName);

		if (stateClass == null)
		{
			CrasherLog.logWarning('Debug menu entry "${entry.label}" points to missing class ${entry.stateClassName}', "editor");
			showUnavailable('${entry.label} is not available yet.');
			Vibration.trigger(HapticStyle.WARNING);
			return;
		}

		try
		{
			var instance:Dynamic = Type.createInstance(stateClass, []);

			if (!Std.isOfType(instance, FlxState))
			{
				showUnavailable('${entry.label} could not be opened.');
				return;
			}

			CrasherLog.addBreadcrumb('Opened editor: ${entry.label}', "navigation");
			Vibration.trigger(HapticStyle.MEDIUM);
			FlxG.switchState(cast instance);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to open debug menu entry "${entry.label}": ${Std.string(e)}', "editor");
			showUnavailable('${entry.label} failed to open.');
			Vibration.trigger(HapticStyle.FAILURE);
		}
	}

	function showUnavailable(message:String):Void
	{
		unavailableText.text = message;

		if (unavailableTween != null)
			unavailableTween.cancel();

		unavailableText.alpha = 1;
		unavailableTween = FlxTween.tween(unavailableText, {alpha: 0}, 2, {ease: FlxEase.quadOut, startDelay: 1.2});
	}

	function goBack():Void
	{
		Vibration.menuSelect();
		CrasherLog.addBreadcrumb("Left debug menu", "navigation");
		FlxG.switchState(new MainMenuState());
	}

	override function destroy():Void
	{
		if (unavailableTween != null)
			unavailableTween.cancel();

		super.destroy();
	}

	public static function open():Void
	{
		FlxG.switchState(new DebugMenuState());
	}
}
