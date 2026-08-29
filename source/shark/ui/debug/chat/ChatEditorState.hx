package shark.ui.debug.chat;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxTextAlign;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import git.graphic.GraphicGit;
import shark.functions.ChatEngine;
import shark.mobile.backend.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.online.Online;
import shark.ui.debug.CrasherLog;
import shark.ui.debug.menu.DebugMenuState;

enum abstract EditorFieldKind(Int)
{
	var NUMBER_FLOAT = 0;
	var NUMBER_INT = 1;
	var TOGGLE = 2;
	var ACTION = 3;
}

typedef EditorField = {
	label:String,
	kind:EditorFieldKind,
	getValue:Void->String,
	?adjust:Int->Void,
	?activate:Void->Void
}

class ChatEditorState extends FlxState
{
	static inline var PANEL_WIDTH:Float = 480;
	static inline var ROW_HEIGHT:Float = 34;
	static inline var ROW_SPACING:Float = 6;
	static inline var PROMPT_HEIGHT:Float = 120;
	static inline var MODEL_FIELD_HEIGHT:Float = 26;

	var fields:Array<EditorField>;
	var selectedIndex:Int = 0;

	var rowBackgrounds:Array<FlxSprite> = [];
	var rowLabels:Array<FlxText> = [];
	var rowValues:Array<FlxText> = [];

	var promptField:TextField;
	var modelField:TextField;

	var flashText:FlxText;
	var flashTween:FlxTween;
	var statusText:FlxText;

	var panelX:Float;
	var fieldsStartY:Float;

	public function new()
	{
		super();

		fields = buildFields();
	}

	override function create():Void
	{
		super.create();

		panelX = (FlxG.width - PANEL_WIDTH) / 2;

		buildBackground();
		buildTitle();
		buildPromptField();
		buildModelField();
		buildFieldRows();
		buildFooter();

		CrasherLog.setContext("editor", "chat");
		CrasherLog.addBreadcrumb("Opened chat editor", "navigation");
	}

	function buildFields():Array<EditorField>
	{
		return [
			numberField("Temperature", 0.1, 0, 2, function() return ChatEngine.temperature, function(v) ChatEngine.temperature = v),
			intField("Max Tokens", 64, 64, 4096, function() return ChatEngine.maxTokens, function(v) ChatEngine.maxTokens = v),
			intField("Max History", 5, 0, 200, function() return ChatEngine.maxHistory, function(v) ChatEngine.maxHistory = v),
			intField("Max Message Length", 50, 50, 5000, function() return ChatEngine.maxMessageLength, function(v) ChatEngine.maxMessageLength = v),
			numberField("Min Request Interval", 0.5, 0, 30, function() return ChatEngine.minRequestInterval, function(v) ChatEngine.minRequestInterval = v),
			intField("Max Retries", 1, 0, 10, function() return ChatEngine.maxRetries, function(v) ChatEngine.maxRetries = v),
			toggleField("Require Online", function() return ChatEngine.requireOnline, function(v) ChatEngine.requireOnline = v),
			actionField("Apply Prompt & Model", applyTextFields),
			actionField("Back", goBack)
		];
	}

	function numberField(label:String, step:Float, min:Float, max:Float, getter:Void->Float, setter:Float->Void):EditorField
	{
		return {
			label: label,
			kind: NUMBER_FLOAT,
			getValue: function():String return formatDecimal(getter(), 2),
			adjust: function(direction:Int):Void setter(clampFloat(getter() + step * direction, min, max))
		};
	}

	function intField(label:String, step:Int, min:Int, max:Int, getter:Void->Int, setter:Int->Void):EditorField
	{
		return {
			label: label,
			kind: NUMBER_INT,
			getValue: function():String return Std.string(getter()),
			adjust: function(direction:Int):Void setter(clampInt(getter() + step * direction, min, max))
		};
	}

	function toggleField(label:String, getter:Void->Bool, setter:Bool->Void):EditorField
	{
		return {
			label: label,
			kind: TOGGLE,
			getValue: function():String return getter() ? "on" : "off",
			adjust: function(direction:Int):Void setter(!getter()),
			activate: function():Void setter(!getter())
		};
	}

	function actionField(label:String, action:Void->Void):EditorField
	{
		return {
			label: label,
			kind: ACTION,
			getValue: function():String return "",
			activate: action
		};
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
		var title:FlxText = new FlxText(0, 20, FlxG.width, "CHAT EDITOR");
		title.setFormat(null, 24, FlxColor.WHITE, FlxTextAlign.CENTER);
		add(title);
	}

	function buildPromptField():Void
	{
		var labelY:Float = 56;

		var label:FlxText = new FlxText(panelX, labelY, PANEL_WIDTH, "System prompt");
		label.setFormat(null, 13, FlxColor.fromRGB(160, 180, 200));
		add(label);

		promptField = new TextField();
		promptField.type = TextFieldType.INPUT;
		promptField.multiline = true;
		promptField.wordWrap = true;
		promptField.x = panelX;
		promptField.y = labelY + 20;
		promptField.width = PANEL_WIDTH;
		promptField.height = PROMPT_HEIGHT;
		promptField.background = true;
		promptField.backgroundColor = 0x101820;
		promptField.border = true;
		promptField.borderColor = 0x2C4256;
		promptField.defaultTextFormat = new TextFormat(null, 13, 0xFFFFFF);
		promptField.text = ChatEngine.systemPrompt != null ? ChatEngine.systemPrompt : "";
		promptField.setTextFormat(promptField.defaultTextFormat);

		FlxG.stage.addChild(promptField);
	}

	function buildModelField():Void
	{
		var labelY:Float = 56 + 20 + PROMPT_HEIGHT + 10;

		var label:FlxText = new FlxText(panelX, labelY, PANEL_WIDTH, "Model");
		label.setFormat(null, 13, FlxColor.fromRGB(160, 180, 200));
		add(label);

		modelField = new TextField();
		modelField.type = TextFieldType.INPUT;
		modelField.multiline = false;
		modelField.x = panelX;
		modelField.y = labelY + 20;
		modelField.width = PANEL_WIDTH;
		modelField.height = MODEL_FIELD_HEIGHT;
		modelField.background = true;
		modelField.backgroundColor = 0x101820;
		modelField.border = true;
		modelField.borderColor = 0x2C4256;
		modelField.defaultTextFormat = new TextFormat(null, 13, 0xFFFFFF);
		modelField.text = ChatEngine.model != null ? ChatEngine.model : "";
		modelField.setTextFormat(modelField.defaultTextFormat);

		FlxG.stage.addChild(modelField);

		fieldsStartY = labelY + 20 + MODEL_FIELD_HEIGHT + 20;
	}

	function buildFieldRows():Void
	{
		for (i in 0...fields.length)
		{
			var rowY:Float = fieldsStartY + i * (ROW_HEIGHT + ROW_SPACING);

			var background:FlxSprite = GraphicGit.makeRoundedRectSprite(panelX, rowY, Std.int(PANEL_WIDTH), Std.int(ROW_HEIGHT), rowFillColor(i), 6);
			add(background);
			rowBackgrounds.push(background);

			var label:FlxText = new FlxText(panelX + 16, rowY + 7, PANEL_WIDTH * 0.6, fields[i].label);
			label.setFormat(null, 14, FlxColor.WHITE);
			add(label);
			rowLabels.push(label);

			var value:FlxText = new FlxText(panelX + PANEL_WIDTH * 0.55, rowY + 7, PANEL_WIDTH * 0.45 - 16, "");
			value.setFormat(null, 14, FlxColor.fromRGB(140, 200, 255), FlxTextAlign.RIGHT);
			add(value);
			rowValues.push(value);
		}

		refreshFieldValues();
	}

	function buildFooter():Void
	{
		var footerY:Float = fieldsStartY + fields.length * (ROW_HEIGHT + ROW_SPACING) + 10;

		var help:FlxText = new FlxText(0, footerY, FlxG.width, "Up/Down select - Left/Right adjust - Enter confirm - Esc back");
		help.setFormat(null, 12, FlxColor.fromRGB(140, 150, 160), FlxTextAlign.CENTER);
		add(help);

		statusText = new FlxText(0, footerY + 20, FlxG.width, "");
		statusText.setFormat(null, 12, FlxColor.fromRGB(120, 200, 150), FlxTextAlign.CENTER);
		add(statusText);

		flashText = new FlxText(0, footerY + 40, FlxG.width, "");
		flashText.setFormat(null, 13, FlxColor.fromRGB(140, 220, 160), FlxTextAlign.CENTER);
		flashText.alpha = 0;
		add(flashText);

		refreshStatus();
	}

	function refreshStatus():Void
	{
		var apiState:String = Online.apiOnline ? "reachable" : "unreachable";
		var latency:String = Online.apiLatencyMs < 0 ? "n/a" : '${Std.int(Online.apiLatencyMs)}ms';

		statusText.text = 'API: $apiState ($latency)   |   ${ChatEngine.getHistorySummary()}';
	}

	function rowFillColor(index:Int):FlxColor
	{
		return index == selectedIndex ? FlxColor.fromRGB(30, 60, 90) : FlxColor.fromRGB(18, 28, 40);
	}

	function refreshFieldValues():Void
	{
		for (i in 0...fields.length)
		{
			rowValues[i].text = fields[i].getValue();
			rowBackgrounds[i].pixels = GraphicGit.createRoundedRect(Std.int(PANEL_WIDTH), Std.int(ROW_HEIGHT), rowFillColor(i), 6);
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		handleKeyboardInput();
		handlePointerInput();
		refreshStatus();
	}

	function handleKeyboardInput():Void
	{
		if (FlxG.keys.justPressed.UP)
			moveSelection(-1);
		else if (FlxG.keys.justPressed.DOWN)
			moveSelection(1);
		else if (FlxG.keys.justPressed.LEFT)
			adjustSelected(-1);
		else if (FlxG.keys.justPressed.RIGHT)
			adjustSelected(1);
		else if (FlxG.keys.justPressed.ENTER)
			activateSelected();
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
				refreshFieldValues();
				activateSelected();
				return;
			}
		}
	}

	function moveSelection(direction:Int):Void
	{
		if (fields.length == 0)
			return;

		selectedIndex = (selectedIndex + direction + fields.length) % fields.length;
		refreshFieldValues();
		Vibration.trigger(HapticStyle.SELECTION);
	}

	function adjustSelected(direction:Int):Void
	{
		var field:EditorField = fields[selectedIndex];

		if (field.adjust == null)
			return;

		field.adjust(direction);
		refreshFieldValues();
		Vibration.trigger(HapticStyle.LIGHT);
	}

	function activateSelected():Void
	{
		var field:EditorField = fields[selectedIndex];

		if (field.activate == null)
			return;

		field.activate();
		refreshFieldValues();
	}

	function applyTextFields():Void
	{
		ChatEngine.systemPrompt = promptField.text;
		ChatEngine.model = modelField.text;

		CrasherLog.addBreadcrumb("Applied chat prompt/model from editor", "editor");
		Vibration.trigger(HapticStyle.SUCCESS);
		showFlash("Applied prompt and model.");
	}

	function showFlash(message:String):Void
	{
		flashText.text = message;

		if (flashTween != null)
			flashTween.cancel();

		flashText.alpha = 1;
		flashTween = FlxTween.tween(flashText, {alpha: 0}, 2, {ease: FlxEase.quadOut, startDelay: 1.2});
	}

	function goBack():Void
	{
		Vibration.menuSelect();
		CrasherLog.addBreadcrumb("Left chat editor", "navigation");
		FlxG.switchState(new DebugMenuState());
	}

	static function clampFloat(value:Float, min:Float, max:Float):Float
	{
		return Math.max(min, Math.min(max, value));
	}

	static function clampInt(value:Int, min:Int, max:Int):Int
	{
		return Std.int(Math.max(min, Math.min(max, value)));
	}

	static function formatDecimal(value:Float, decimals:Int):String
	{
		var factor:Float = Math.pow(10, decimals);
		var rounded:Float = Math.round(value * factor) / factor;
		var text:String = Std.string(rounded);

		if (text.indexOf(".") == -1)
			text += ".0";

		return text;
	}

	override function destroy():Void
	{
		if (flashTween != null)
			flashTween.cancel();

		if (promptField != null && promptField.parent != null)
			promptField.parent.removeChild(promptField);

		if (modelField != null && modelField.parent != null)
			modelField.parent.removeChild(modelField);

		super.destroy();
	}
}
