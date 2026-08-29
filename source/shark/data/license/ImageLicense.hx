package shark.data.license;

import haxe.Timer;
import haxe.crypto.Md5;
import shark.backend.Paths;
import shark.ui.debug.CrasherLog;

enum abstract LicenseDecision(Int)
{
	var ALLOW = 0;
	var REQUIRE_CONSENT = 1;
	var BLOCK = 2;
}

typedef LicenseResult = {
	decision:LicenseDecision,
	reason:String,
	matchedTerm:String
}

typedef LicensePolicy = {
	blockedTerms:Array<String>,
	consentTerms:Array<String>,
	artistStylePhrases:Array<String>,
	realPersonPhrases:Array<String>
}

class ImageLicense
{
	static inline var POLICY_KEY:String = "copyright_policy";

	public static var enabled:Bool = true;
	public static var consentDurationSeconds:Float = 3600;

	static var policy:LicensePolicy;
	static var policyLoaded:Bool = false;
	static var consentedPromptHashes:Map<String, Float> = new Map();

	static var totalChecks:Int = 0;
	static var totalBlocked:Int = 0;
	static var totalRequiredConsent:Int = 0;

	static var stylePatternRegex:EReg = ~/(in the style of|style of|styled like|drawn like|art style of)\s+([A-Z][a-zA-Z.'-]*(?:\s+[A-Z][a-zA-Z.'-]*){0,2})/;
	static var realPersonPatternRegex:EReg = ~/(photo of|photograph of|photorealistic|realistic (photo|picture|image) of|selfie of)\s+([A-Z][a-zA-Z.'-]*(?:\s+[A-Z][a-zA-Z.'-]*){0,2})/;

	public static function evaluate(prompt:String):LicenseResult
	{
		ensurePolicyLoaded();
		totalChecks++;

		if (!enabled)
			return {decision: ALLOW, reason: "License checks disabled", matchedTerm: null};

		if (prompt == null || StringTools.trim(prompt).length == 0)
			return {decision: BLOCK, reason: "Empty prompt", matchedTerm: null};

		var trimmed:String = StringTools.trim(prompt);
		var normalized:String = trimmed.toLowerCase();

		var blockedMatch:String = findMatch(normalized, policy.blockedTerms);

		if (blockedMatch != null)
		{
			totalBlocked++;
			logDecision(prompt, BLOCK, blockedMatch);
			return {
				decision: BLOCK,
				reason: 'Matches a blocked term ("$blockedMatch") - likely a copyrighted character, franchise, or trademark',
				matchedTerm: blockedMatch
			};
		}

		var sensitiveMatch:String = findArtistStyleMatch(trimmed);

		if (sensitiveMatch == null)
			sensitiveMatch = findRealPersonMatch(trimmed);

		if (sensitiveMatch == null)
			sensitiveMatch = findMatch(normalized, policy.consentTerms);

		if (sensitiveMatch != null)
		{
			if (hasValidConsent(prompt))
			{
				logDecision(prompt, ALLOW, sensitiveMatch);
				return {
					decision: ALLOW,
					reason: 'Allowed - rights already confirmed for a similar request ("$sensitiveMatch")',
					matchedTerm: sensitiveMatch
				};
			}

			totalRequiredConsent++;
			logDecision(prompt, REQUIRE_CONSENT, sensitiveMatch);
			return {
				decision: REQUIRE_CONSENT,
				reason: 'Matches a sensitive term ("$sensitiveMatch") - confirm you have the rights to request this before continuing',
				matchedTerm: sensitiveMatch
			};
		}

		logDecision(prompt, ALLOW, null);
		return {decision: ALLOW, reason: "No copyright concerns detected", matchedTerm: null};
	}

	public static function requestGeneration(prompt:String, onAllowed:Void->Void, onNeedsConsent:String->Void, onBlocked:String->Void):Void
	{
		var result:LicenseResult = evaluate(prompt);

		switch (result.decision)
		{
			case ALLOW:
				if (onAllowed != null)
					onAllowed();
			case REQUIRE_CONSENT:
				if (onNeedsConsent != null)
					onNeedsConsent(result.reason);
			case BLOCK:
				if (onBlocked != null)
					onBlocked(result.reason);
		}
	}

	static function findMatch(normalized:String, terms:Array<String>):String
	{
		if (terms == null)
			return null;

		for (term in terms)
		{
			var candidate:String = StringTools.trim(term).toLowerCase();

			if (candidate.length == 0)
				continue;

			if (normalized.indexOf(candidate) != -1)
				return term;
		}

		return null;
	}

	static function findArtistStyleMatch(trimmed:String):String
	{
		var explicitMatch:String = findMatch(trimmed.toLowerCase(), policy.artistStylePhrases);

		if (explicitMatch != null)
			return explicitMatch;

		if (stylePatternRegex.match(trimmed))
			return stylePatternRegex.matched(2);

		return null;
	}

	static function findRealPersonMatch(trimmed:String):String
	{
		var explicitMatch:String = findMatch(trimmed.toLowerCase(), policy.realPersonPhrases);

		if (explicitMatch != null)
			return explicitMatch;

		if (realPersonPatternRegex.match(trimmed))
			return realPersonPatternRegex.matched(3);

		return null;
	}

	public static function hasValidConsent(prompt:String):Bool
	{
		var hash:String = hashPrompt(normalizeForHash(prompt));

		if (!consentedPromptHashes.exists(hash))
			return false;

		var consentedAt:Float = consentedPromptHashes.get(hash);
		return Timer.stamp() - consentedAt <= consentDurationSeconds;
	}

	public static function recordConsent(prompt:String):Void
	{
		var hash:String = hashPrompt(normalizeForHash(prompt));
		consentedPromptHashes.set(hash, Timer.stamp());

		CrasherLog.addBreadcrumb("User confirmed copyright/rights permission for an image prompt", "license");
	}

	public static function clearConsent():Void
	{
		consentedPromptHashes = new Map();
	}

	static function countActiveConsents():Int
	{
		var now:Float = Timer.stamp();
		var count:Int = 0;

		for (consentedAt in consentedPromptHashes)
			if (now - consentedAt <= consentDurationSeconds)
				count++;

		return count;
	}

	static function normalizeForHash(prompt:String):String
	{
		return prompt == null ? "" : StringTools.trim(prompt).toLowerCase();
	}

	static function hashPrompt(normalized:String):String
	{
		return Md5.encode(normalized);
	}

	static function logDecision(prompt:String, decision:LicenseDecision, matchedTerm:String):Void
	{
		var promptHash:String = hashPrompt(normalizeForHash(prompt)).substr(0, 8);
		var decisionLabel:String = decisionToString(decision);
		var termTag:String = matchedTerm != null ? ' ($matchedTerm)' : "";

		CrasherLog.addBreadcrumb('Image prompt license check: $decisionLabel$termTag [hash:$promptHash]', "license");

		if (decision == BLOCK)
			CrasherLog.logWarning('Blocked an image prompt for copyright reasons (hash:$promptHash)', "license");
	}

	static function decisionToString(decision:LicenseDecision):String
	{
		return switch (decision)
		{
			case ALLOW: "allow";
			case REQUIRE_CONSENT: "require_consent";
			case BLOCK: "block";
		}
	}

	static function ensurePolicyLoaded():Void
	{
		if (policyLoaded)
			return;

		policyLoaded = true;

		var loaded:Dynamic = null;

		try
		{
			loaded = Paths.getJson(POLICY_KEY);
		}
		catch (e:Dynamic) {}

		if (loaded != null)
		{
			policy = {
				blockedTerms: extractStringArray(loaded, "blockedTerms"),
				consentTerms: extractStringArray(loaded, "consentTerms"),
				artistStylePhrases: extractStringArray(loaded, "artistStylePhrases"),
				realPersonPhrases: extractStringArray(loaded, "realPersonPhrases")
			};
		}
		else
		{
			policy = buildDefaultPolicy();
			CrasherLog.logWarning('assets/data/$POLICY_KEY.json not found - using a minimal built-in copyright policy. Add your own denylist there.', "license");
		}
	}

	public static function reloadPolicy():Void
	{
		policyLoaded = false;
		ensurePolicyLoaded();
	}

	static function extractStringArray(source:Dynamic, field:String):Array<String>
	{
		var raw:Dynamic = Reflect.field(source, field);

		if (raw == null)
			return [];

		var result:Array<String> = [];

		try
		{
			var array:Array<Dynamic> = raw;

			for (item in array)
				if (item != null)
					result.push(Std.string(item));
		}
		catch (e:Dynamic) {}

		return result;
	}

	static function buildDefaultPolicy():LicensePolicy
	{
		return {
			blockedTerms: [
				"official logo",
				"exact copy of",
				"screenshot from",
				"movie still from",
				"album cover of"
			],
			consentTerms: [
				"trademarked",
				"branded merchandise",
				"official mascot"
			],
			artistStylePhrases: [],
			realPersonPhrases: []
		};
	}

	public static function getStatusSummary():String
	{
		ensurePolicyLoaded();

		return 'ImageLicense: enabled=$enabled, checks=$totalChecks, blocked=$totalBlocked, consent-required=$totalRequiredConsent, blocklist terms=${policy.blockedTerms.length}, active consents=${countActiveConsents()}';
	}
}
