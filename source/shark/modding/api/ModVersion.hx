package shark.modding.api;

enum abstract ModApiFeature(String) to String
{
	var SCRIPT_HOOKS = "scriptHooks";
	var ASSET_OVERRIDES = "assetOverrides";
	var MOD_UPDATE_LOOP = "modUpdateLoop";
	var VIBRATION_ACCESS = "vibrationAccess";
	var CRASH_BREADCRUMBS = "crashBreadcrumbs";
	var MOD_STORAGE = "modStorage";
	var CONNECTIVITY_STATUS = "connectivityStatus";
}

typedef SemVer = {
	major:Int,
	minor:Int,
	patch:Int
}

typedef VersionEntry = {
	version:String,
	releasedFeatures:Array<ModApiFeature>,
	deprecated:Array<String>,
	removed:Array<String>,
	notes:String
}

class ModVersion
{
	public static inline var CURRENT:String = "0.2.0";
	public static inline var MIN_SUPPORTED:String = "0.1.0";

	public static var history(default, null):Array<VersionEntry> = [
		{
			version: "0.1.0",
			releasedFeatures: [SCRIPT_HOOKS, ASSET_OVERRIDES, MOD_UPDATE_LOOP],
			deprecated: [],
			removed: [],
			notes: "Initial modding API - HScript hooks, Polymod asset overrides, and the per-frame mod update loop."
		},
		{
			version: "0.2.0",
			releasedFeatures: [VIBRATION_ACCESS, CRASH_BREADCRUMBS, MOD_STORAGE, CONNECTIVITY_STATUS],
			deprecated: ["Mods.legacyUpdateHook"],
			removed: [],
			notes: "Adds haptics access, crash log breadcrumbs, per-mod persistent storage, and connectivity status for mods."
		}
	];

	public static function parse(version:String):SemVer
	{
		var parts:Array<String> = version.split(".");

		return {
			major: parts.length > 0 ? safeParseInt(parts[0]) : 0,
			minor: parts.length > 1 ? safeParseInt(parts[1]) : 0,
			patch: parts.length > 2 ? safeParseInt(parts[2]) : 0
		};
	}

	static function safeParseInt(value:String):Int
	{
		var digitsOnly:EReg = ~/[^0-9]/g;
		var cleaned:String = digitsOnly.replace(value, "");
		var parsed:Null<Int> = Std.parseInt(cleaned);

		return parsed != null ? parsed : 0;
	}

	static function semverToString(v:SemVer):String
	{
		return '${v.major}.${v.minor}.${v.patch}';
	}

	public static function compare(a:String, b:String):Int
	{
		var va:SemVer = parse(a);
		var vb:SemVer = parse(b);

		if (va.major != vb.major)
			return va.major > vb.major ? 1 : -1;

		if (va.minor != vb.minor)
			return va.minor > vb.minor ? 1 : -1;

		if (va.patch != vb.patch)
			return va.patch > vb.patch ? 1 : -1;

		return 0;
	}

	public static function isAtLeast(version:String, minVersion:String):Bool
	{
		return compare(version, minVersion) >= 0;
	}

	public static function isAtMost(version:String, maxVersion:String):Bool
	{
		return compare(version, maxVersion) <= 0;
	}

	public static function satisfiesRange(version:String, range:String):Bool
	{
		var trimmed:String = StringTools.trim(range);

		if (trimmed.length == 0)
			return true;

		if (StringTools.startsWith(trimmed, "^"))
			return satisfiesCaret(version, trimmed.substr(1));

		if (StringTools.startsWith(trimmed, "~"))
			return satisfiesTilde(version, trimmed.substr(1));

		if (StringTools.startsWith(trimmed, ">="))
			return compare(version, StringTools.trim(trimmed.substr(2))) >= 0;

		if (StringTools.startsWith(trimmed, "<="))
			return compare(version, StringTools.trim(trimmed.substr(2))) <= 0;

		if (StringTools.startsWith(trimmed, ">"))
			return compare(version, StringTools.trim(trimmed.substr(1))) > 0;

		if (StringTools.startsWith(trimmed, "<"))
			return compare(version, StringTools.trim(trimmed.substr(1))) < 0;

		if (StringTools.startsWith(trimmed, "="))
			return compare(version, StringTools.trim(trimmed.substr(1))) == 0;

		return compare(version, trimmed) == 0;
	}

	static function satisfiesCaret(version:String, base:String):Bool
	{
		var baseVer:SemVer = parse(base);
		var upperBound:SemVer;

		if (baseVer.major > 0)
			upperBound = {major: baseVer.major + 1, minor: 0, patch: 0};
		else if (baseVer.minor > 0)
			upperBound = {major: 0, minor: baseVer.minor + 1, patch: 0};
		else
			upperBound = {major: 0, minor: 0, patch: baseVer.patch + 1};

		return isAtLeast(version, base) && compare(version, semverToString(upperBound)) < 0;
	}

	static function satisfiesTilde(version:String, base:String):Bool
	{
		var baseVer:SemVer = parse(base);
		var upperBound:SemVer = {major: baseVer.major, minor: baseVer.minor + 1, patch: 0};

		return isAtLeast(version, base) && compare(version, semverToString(upperBound)) < 0;
	}

	public static function isModCompatible(modDeclaredApiVersion:String, ?range:String):Bool
	{
		if (range != null)
			return satisfiesRange(CURRENT, range);

		return satisfiesRange(CURRENT, '^$modDeclaredApiVersion');
	}

	public static function isModSupported(modDeclaredApiVersion:String):Bool
	{
		return isAtLeast(modDeclaredApiVersion, MIN_SUPPORTED) && isModCompatible(modDeclaredApiVersion);
	}

	public static function getDeprecationWarnings(modDeclaredApiVersion:String):Array<String>
	{
		var warnings:Array<String> = [];

		for (entry in history)
		{
			if (compare(entry.version, modDeclaredApiVersion) <= 0)
				continue;

			if (compare(entry.version, CURRENT) > 0)
				continue;

			for (name in entry.deprecated)
				warnings.push('$name was deprecated in ${entry.version}');

			for (name in entry.removed)
				warnings.push('$name was removed in ${entry.version}');
		}

		return warnings;
	}

	public static function versionIntroduced(feature:ModApiFeature):String
	{
		for (entry in history)
			if (entry.releasedFeatures.indexOf(feature) != -1)
				return entry.version;

		return "unknown";
	}

	public static function isFeatureSupported(feature:ModApiFeature):Bool
	{
		var introducedAt:String = versionIntroduced(feature);
		return introducedAt != "unknown" && isAtLeast(CURRENT, introducedAt);
	}

	public static function getChangelog(?sinceVersion:String):Array<VersionEntry>
	{
		if (sinceVersion == null)
			return history.copy();

		return history.filter(function(entry:VersionEntry):Bool
		{
			return compare(entry.version, sinceVersion) > 0;
		});
	}

	public static function getLatestFeatures():Array<ModApiFeature>
	{
		if (history.length == 0)
			return [];

		return history[history.length - 1].releasedFeatures.copy();
	}

	public static function getSummary():String
	{
		var lines:Array<String> = ['Shark Modding API $CURRENT (minimum supported: $MIN_SUPPORTED)'];

		for (entry in history)
		{
			var featureNames:Array<String> = [for (f in entry.releasedFeatures) (f : String)];
			lines.push('${entry.version}: ${entry.notes} (features: ${featureNames.join(", ")})');
		}

		return lines.join("\n");
	}
}
