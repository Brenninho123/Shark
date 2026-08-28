package shark.mobile.backend;

import haxe.Timer;
import shark.ui.debug.CrasherLog;

#if js
import js.Browser;
#end

enum abstract HapticStyle(Int)
{
	var LIGHT = 0;
	var MEDIUM = 1;
	var HEAVY = 2;
	var SELECTION = 3;
	var SUCCESS = 4;
	var WARNING = 5;
	var ERROR = 6;
	var NOTIFICATION = 7;
	var CUSTOM = 8;
}

typedef HapticProfile = {
	durationMs:Int,
	amplitude:Float,
	pattern:Array<Int>
}

typedef QueuedHaptic = {
	style:HapticStyle,
	profile:HapticProfile,
	critical:Bool
}

typedef NativeCallResult = {
	found:Bool,
	value:Dynamic
}

class Vibration
{
	public static var enabled:Bool = true;
	public static var globalIntensity(default, null):Float = 1;
	public static var batteryAware:Bool = true;
	public static var lowBatteryThresholdPercent:Float = 15;
	public static var respectReducedMotion:Bool = true;

	public static var minIntervalMsNormal:Int = 40;
	public static var minIntervalMsCritical:Int = 0;

	static var reducedMotionProvider:Void->Bool;
	static var batteryLevelProvider:Void->Float;

	static var lastTriggerTimeMs:Float = -1000;
	static var isCurrentlyVibrating:Bool = false;
	static var releaseTimer:Timer;
	static var hasWarnedNoBackend:Bool = false;

	static var queue:Array<QueuedHaptic> = [];
	static inline var MAX_QUEUE_LENGTH:Int = 6;

	static var cachedSupportChecked:Bool = false;
	static var cachedSupported:Bool = false;
	static var cachedAmplitudeChecked:Bool = false;
	static var cachedHasAmplitudeControl:Bool = false;

	static var totalTriggers:Int = 0;
	static var totalSkippedCooldown:Int = 0;
	static var totalSkippedBattery:Int = 0;
	static var totalSkippedReducedMotion:Int = 0;
	static var totalSkippedDisabled:Int = 0;
	static var lastStyleTriggered:HapticStyle = LIGHT;

	public static function trigger(style:HapticStyle, ?critical:Bool = false, ?intensityOverride:Float):Void
	{
		if (!enabled)
		{
			totalSkippedDisabled++;
			return;
		}

		if (respectReducedMotion && !critical && reducedMotionProvider != null && reducedMotionProvider())
		{
			totalSkippedReducedMotion++;
			return;
		}

		if (batteryAware && !critical && getBatteryLevelPercent() < lowBatteryThresholdPercent)
		{
			totalSkippedBattery++;
			return;
		}

		var nowMs:Float = Timer.stamp() * 1000;
		var minInterval:Int = critical ? minIntervalMsCritical : minIntervalMsNormal;

		if (!critical && nowMs - lastTriggerTimeMs < minInterval)
		{
			totalSkippedCooldown++;
			return;
		}

		var baseProfile:HapticProfile = styleToProfile(style);
		var scaled:Float = clamp01((intensityOverride != null ? intensityOverride : 1) * globalIntensity);

		var profile:HapticProfile = {
			durationMs: baseProfile.durationMs,
			amplitude: clamp01(baseProfile.amplitude * scaled),
			pattern: baseProfile.pattern
		};

		lastStyleTriggered = style;
		requestPlayback(style, profile, critical);
	}

	public static function vibrate(durationMs:Int, ?amplitude:Float = 1, ?critical:Bool = false):Void
	{
		var profile:HapticProfile = {
			durationMs: durationMs,
			amplitude: clamp01(amplitude * globalIntensity),
			pattern: [durationMs]
		};

		requestPlayback(CUSTOM, profile, critical);
	}

	public static function playPattern(durations:Array<Int>, ?amplitudes:Array<Float>, ?repeatIndex:Int = -1, ?critical:Bool = false):Void
	{
		var totalMs:Int = sumArray(durations);
		var averageAmplitude:Float = 1;

		if (amplitudes != null && amplitudes.length > 0)
		{
			var sum:Float = 0;

			for (a in amplitudes)
				sum += a;

			averageAmplitude = sum / amplitudes.length;
		}

		var profile:HapticProfile = {
			durationMs: totalMs,
			amplitude: clamp01(averageAmplitude * globalIntensity),
			pattern: durations
		};

		requestPlayback(CUSTOM, profile, critical);
	}

	public static function cancel():Void
	{
		cancelInternal();
		queue = [];
	}

	public static function noteHit(?critical:Bool = false):Void
	{
		trigger(LIGHT, critical);
	}

	public static function noteMiss():Void
	{
		trigger(WARNING, true);
	}

	public static function comboBreak():Void
	{
		trigger(ERROR, true);
	}

	public static function menuSelect():Void
	{
		trigger(SELECTION);
	}

	public static function menuConfirm():Void
	{
		trigger(MEDIUM);
	}

	public static function achievementUnlocked():Void
	{
		trigger(SUCCESS, true);
	}

	static function requestPlayback(style:HapticStyle, profile:HapticProfile, critical:Bool):Void
	{
		if (!isSupported())
			return;

		totalTriggers++;

		if (isCurrentlyVibrating)
		{
			if (critical)
			{
				cancelInternal();
				playNow(style, profile);
			}
			else if (queue.length < MAX_QUEUE_LENGTH)
			{
				queue.push({style: style, profile: profile, critical: critical});
			}

			return;
		}

		playNow(style, profile);
	}

	static function playNow(style:HapticStyle, profile:HapticProfile):Void
	{
		isCurrentlyVibrating = true;
		lastTriggerTimeMs = Timer.stamp() * 1000;

		#if android
		playAndroid(style, profile);
		#elseif ios
		playIOS(style, profile);
		#elseif js
		playHTML5(profile);
		#else
		playFallback(profile);
		#end

		var totalMs:Int = profile.pattern.length > 1 ? sumArray(profile.pattern) : profile.durationMs;

		if (totalMs <= 0)
			totalMs = 10;

		if (releaseTimer != null)
			releaseTimer.stop();

		releaseTimer = Timer.delay(function():Void
		{
			isCurrentlyVibrating = false;
			processQueue();
		}, totalMs);
	}

	static function processQueue():Void
	{
		if (queue.length == 0)
			return;

		var next:QueuedHaptic = queue.shift();
		playNow(next.style, next.profile);
	}

	static function cancelInternal():Void
	{
		#if android
		tryNativeCall(androidCandidates(), "cancel", []);
		#elseif ios
		tryNativeCall(iosCandidates(), "cancel", []);
		#elseif js
		if (Browser.navigator != null && Reflect.hasField(Browser.navigator, "vibrate"))
			Browser.navigator.vibrate(0);
		#end

		if (releaseTimer != null)
		{
			releaseTimer.stop();
			releaseTimer = null;
		}

		isCurrentlyVibrating = false;
	}

	static function playAndroid(style:HapticStyle, profile:HapticProfile):Void
	{
		#if android
		var candidates:Array<String> = androidCandidates();

		if (profile.pattern.length > 1)
		{
			var result:NativeCallResult = tryNativeCall(candidates, "vibratePattern", [profile.pattern, -1]);

			if (result.found)
				return;
		}
		else if (hasAmplitudeControl())
		{
			var amplitudeValue:Int = Std.int(profile.amplitude * 255);
			var result:NativeCallResult = tryNativeCall(candidates, "vibrateAmplitude", [profile.durationMs, amplitudeValue]);

			if (result.found)
				return;
		}

		var basic:NativeCallResult = tryNativeCall(candidates, "vibrate", [profile.durationMs]);

		if (!basic.found)
			playFallback(profile);
		#end
	}

	static function playIOS(style:HapticStyle, profile:HapticProfile):Void
	{
		#if ios
		var candidates:Array<String> = iosCandidates();
		var methodName:String = styleToIOSMethod(style);

		if (methodName != null)
		{
			var result:NativeCallResult = tryNativeCall(candidates, methodName, []);

			if (result.found)
				return;
		}

		var basic:NativeCallResult = tryNativeCall(candidates, "vibrate", [profile.durationMs]);

		if (!basic.found)
			playFallback(profile);
		#end
	}

	static function playHTML5(profile:HapticProfile):Void
	{
		#if js
		if (Browser.navigator == null || !Reflect.hasField(Browser.navigator, "vibrate"))
		{
			playFallback(profile);
			return;
		}

		if (profile.pattern.length > 1)
			Browser.navigator.vibrate(profile.pattern);
		else
			Browser.navigator.vibrate(profile.durationMs);
		#end
	}

	static function playFallback(profile:HapticProfile):Void
	{
		if (hasWarnedNoBackend)
			return;

		hasWarnedNoBackend = true;
		CrasherLog.logWarning('Vibration requested (${profile.durationMs}ms) but no supported haptic backend is available on this platform.');
	}

	static function androidCandidates():Array<String>
	{
		return ["extension.androidtools.Vibrator", "extension.androidtools.device.Vibrator"];
	}

	static function iosCandidates():Array<String>
	{
		return ["shark.mobile.backend.natives.IOSHaptics", "extension.iostools.Haptics"];
	}

	static function styleToIOSMethod(style:HapticStyle):Null<String>
	{
		return switch (style)
		{
			case LIGHT: "impactLight";
			case MEDIUM: "impactMedium";
			case HEAVY: "impactHeavy";
			case SELECTION: "selectionChanged";
			case SUCCESS: "notificationSuccess";
			case WARNING: "notificationWarning";
			case ERROR: "notificationError";
			case NOTIFICATION: "notificationSuccess";
			case CUSTOM: null;
		}
	}

	static function styleToProfile(style:HapticStyle):HapticProfile
	{
		return switch (style)
		{
			case LIGHT: {durationMs: 10, amplitude: 0.3, pattern: [10]};
			case MEDIUM: {durationMs: 20, amplitude: 0.6, pattern: [20]};
			case HEAVY: {durationMs: 35, amplitude: 1, pattern: [35]};
			case SELECTION: {durationMs: 8, amplitude: 0.2, pattern: [8]};
			case SUCCESS: {durationMs: 80, amplitude: 0.7, pattern: [15, 50, 15]};
			case WARNING: {durationMs: 130, amplitude: 0.8, pattern: [25, 80, 25]};
			case ERROR: {durationMs: 165, amplitude: 1, pattern: [40, 60, 40, 60, 40]};
			case NOTIFICATION: {durationMs: 160, amplitude: 0.6, pattern: [20, 100, 20, 100, 20]};
			case CUSTOM: {durationMs: 0, amplitude: 1, pattern: []};
		}
	}

	static function tryNativeCall(candidates:Array<String>, method:String, args:Array<Dynamic>):NativeCallResult
	{
		for (className in candidates)
		{
			try
			{
				var cls:Dynamic = Type.resolveClass(className);

				if (cls == null)
					continue;

				var fn:Dynamic = Reflect.field(cls, method);

				if (fn == null || !Reflect.isFunction(fn))
					continue;

				var result:Dynamic = Reflect.callMethod(cls, fn, args);

				return {found: true, value: result};
			}
			catch (e:Dynamic) {}
		}

		return {found: false, value: null};
	}

	public static function isSupported():Bool
	{
		if (cachedSupportChecked)
			return cachedSupported;

		cachedSupportChecked = true;

		#if android
		var result:NativeCallResult = tryNativeCall(androidCandidates(), "hasVibrator", []);
		cachedSupported = result.found ? (result.value == true) : true;
		#elseif ios
		cachedSupported = true;
		#elseif js
		cachedSupported = Browser.navigator != null && Reflect.hasField(Browser.navigator, "vibrate");
		#else
		cachedSupported = false;
		#end

		return cachedSupported;
	}

	public static function hasAmplitudeControl():Bool
	{
		if (cachedAmplitudeChecked)
			return cachedHasAmplitudeControl;

		cachedAmplitudeChecked = true;
		cachedHasAmplitudeControl = false;

		#if android
		var result:NativeCallResult = tryNativeCall(androidCandidates(), "hasAmplitudeControl", []);
		cachedHasAmplitudeControl = result.found && result.value == true;
		#end

		return cachedHasAmplitudeControl;
	}

	public static function setEnabled(value:Bool):Void
	{
		enabled = value;

		if (!value)
			cancel();
	}

	public static function setGlobalIntensity(value:Float):Void
	{
		globalIntensity = clamp01(value);
	}

	public static function setReducedMotionProvider(provider:Void->Bool):Void
	{
		reducedMotionProvider = provider;
	}

	public static function setBatteryLevelProvider(provider:Void->Float):Void
	{
		batteryLevelProvider = provider;
	}

	static function getBatteryLevelPercent():Float
	{
		if (batteryLevelProvider == null)
			return 100;

		try
		{
			return batteryLevelProvider();
		}
		catch (e:Dynamic)
		{
			return 100;
		}
	}

	public static function resetStatistics():Void
	{
		totalTriggers = 0;
		totalSkippedCooldown = 0;
		totalSkippedBattery = 0;
		totalSkippedReducedMotion = 0;
		totalSkippedDisabled = 0;
	}

	public static function getStatusSummary():String
	{
		var lines:Array<String> = [];

		lines.push('enabled: $enabled, supported: ${isSupported()}, amplitude control: ${hasAmplitudeControl()}');
		lines.push('intensity: ${globalIntensity}, battery aware: $batteryAware (threshold ${lowBatteryThresholdPercent}%)');
		lines.push('triggers: $totalTriggers total, ${queue.length} queued, currently vibrating: $isCurrentlyVibrating');
		lines.push('skipped: $totalSkippedDisabled disabled / $totalSkippedCooldown cooldown / $totalSkippedBattery battery / $totalSkippedReducedMotion reduced-motion');
		lines.push('last style: $lastStyleTriggered');

		return lines.join("\n");
	}

	static function sumArray(values:Array<Int>):Int
	{
		var total:Int = 0;

		for (value in values)
			total += value;

		return total;
	}

	static function clamp01(value:Float):Float
	{
		return Math.max(0, Math.min(1, value));
	}
}
