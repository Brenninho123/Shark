import sys.FileSystem;
import sys.io.File;

class Setup
{
	static var repoRoot:String;

	public static function main():Void
	{
		repoRoot = resolveRepoRoot();

		Sys.println("Shark project setup");
		Sys.println("Repo root: " + repoRoot);
		Sys.println("");

		var steps:Array<Void->Void> = [
			ensureConfigJson,
			ensureCertificatesFolder,
			ensureCursorFolder,
			ensureFontsFolder,
			ensureLangFolder,
			ensureGitignoreEntries
		];

		for (step in steps)
			step();

		Sys.println("");
		Sys.println("Setup finished. Review assets/data/config.json before building.");
	}

	static function resolveRepoRoot():String
	{
		var cwd:String = Sys.getCwd();

		if (StringTools.endsWith(cwd, "setup/application") || StringTools.endsWith(cwd, "setup/application/"))
			return joinPath(joinPath(cwd, ".."), "..");

		return cwd;
	}

	static function joinPath(base:String, part:String):String
	{
		if (StringTools.endsWith(base, "/") || StringTools.endsWith(base, "\\"))
			return base + part;

		return base + "/" + part;
	}

	static function ensureDirectory(path:String):Void
	{
		if (!FileSystem.exists(path))
		{
			FileSystem.createDirectory(path);
			Sys.println("Created " + path);
		}
	}

	static function ensureConfigJson():Void
	{
		var dataDir:String = joinPath(repoRoot, "assets/data");
		ensureDirectory(dataDir);

		var configPath:String = joinPath(dataDir, "config.json");

		if (FileSystem.exists(configPath))
		{
			Sys.println("assets/data/config.json already exists, leaving it alone");
			return;
		}

		var template:String = getConfigTemplate();
		File.saveContent(configPath, template);
		Sys.println("Created assets/data/config.json from template (fill in your endpoints/keys)");
	}

	static function ensureCertificatesFolder():Void
	{
		ensureDirectory(joinPath(repoRoot, "Certificates"));
	}

	static function ensureCursorFolder():Void
	{
		ensureDirectory(joinPath(repoRoot, "assets/images/cursor"));
	}

	static function ensureFontsFolder():Void
	{
		ensureDirectory(joinPath(repoRoot, "assets/fonts"));
	}

	static function ensureLangFolder():Void
	{
		ensureDirectory(joinPath(repoRoot, "assets/data/lang"));
	}

	static function ensureGitignoreEntries():Void
	{
		var gitignorePath:String = joinPath(repoRoot, ".gitignore");
		var requiredEntries:Array<String> = [
			"assets/data/config.json",
			"Certificates/",
			"export/"
		];

		var existingContent:String = FileSystem.exists(gitignorePath) ? File.getContent(gitignorePath) : "";
		var missingEntries:Array<String> = [];

		for (entry in requiredEntries)
			if (existingContent.indexOf(entry) == -1)
				missingEntries.push(entry);

		if (missingEntries.length == 0)
			return;

		var updated:String = existingContent;

		if (updated.length > 0 && !StringTools.endsWith(updated, "\n"))
			updated += "\n";

		for (entry in missingEntries)
			updated += entry + "\n";

		File.saveContent(gitignorePath, updated);
		Sys.println("Added missing entries to .gitignore: " + missingEntries.join(", "));
	}

	static function getConfigTemplate():String
	{
		return "{\n"
			+ "\t\"network\": {\n"
			+ "\t\t\"chatEndpoint\": \"\",\n"
			+ "\t\t\"chatApiKey\": \"\",\n"
			+ "\t\t\"imageEndpoint\": \"\",\n"
			+ "\t\t\"imageApiKey\": \"\",\n"
			+ "\t\t\"requireOnline\": true\n"
			+ "\t},\n"
			+ "\t\"chat\": {\n"
			+ "\t\t\"systemPrompt\": \"You are Shark, a friendly aquatic AI assistant living inside a HaxeFlixel app.\",\n"
			+ "\t\t\"maxHistory\": 40,\n"
			+ "\t\t\"maxMessageLength\": 4000,\n"
			+ "\t\t\"minRequestInterval\": 0.6,\n"
			+ "\t\t\"maxRetries\": 2\n"
			+ "\t},\n"
			+ "\t\"api\": {\n"
			+ "\t\t\"chatModel\": \"\",\n"
			+ "\t\t\"chatTemperature\": 0.8,\n"
			+ "\t\t\"chatMaxTokens\": 1024,\n"
			+ "\t\t\"imageModel\": \"\",\n"
			+ "\t\t\"imageQuality\": \"standard\"\n"
			+ "\t},\n"
			+ "\t\"image\": {\n"
			+ "\t\t\"maxPromptLength\": 1000,\n"
			+ "\t\t\"minRequestInterval\": 1.0,\n"
			+ "\t\t\"maxRetries\": 2,\n"
			+ "\t\t\"cacheEnabled\": true,\n"
			+ "\t\t\"autoSaveToStorage\": true,\n"
			+ "\t\t\"defaultWidth\": 512,\n"
			+ "\t\t\"defaultHeight\": 512\n"
			+ "\t},\n"
			+ "\t\"audio\": {\n"
			+ "\t\t\"musicVolume\": 0.5,\n"
			+ "\t\t\"soundVolume\": 0.7,\n"
			+ "\t\t\"startMuted\": false\n"
			+ "\t},\n"
			+ "\t\"security\": {\n"
			+ "\t\t\"maxInputLength\": 4000,\n"
			+ "\t\t\"maxRequestsPerWindow\": 20,\n"
			+ "\t\t\"rateLimitWindowSeconds\": 60\n"
			+ "\t},\n"
			+ "\t\"connectivity\": {\n"
			+ "\t\t\"onlineCheckInterval\": 20,\n"
			+ "\t\t\"offlineCheckIntervalBase\": 5,\n"
			+ "\t\t\"checkTimeoutMs\": 8000\n"
			+ "\t},\n"
			+ "\t\"app\": {\n"
			+ "\t\t\"buildVersion\": \"0.1.0\"\n"
			+ "\t},\n"
			+ "\t\"discord\": {\n"
			+ "\t\t\"enabled\": false,\n"
			+ "\t\t\"clientId\": \"\"\n"
			+ "\t}\n"
			+ "}\n";
	}
}
