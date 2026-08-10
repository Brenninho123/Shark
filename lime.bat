@echo off
setlocal enabledelayedexpansion

where haxe >nul 2>&1
if errorlevel 1 (
	echo [ERROR] "haxe" was not found in PATH. Install Haxe first: https://haxe.org/download/
	exit /b 1
)

where haxelib >nul 2>&1
if errorlevel 1 (
	echo [ERROR] "haxelib" was not found in PATH. It should ship with your Haxe install.
	exit /b 1
)

set BRANCH=unknown
where git >nul 2>&1
if not errorlevel 1 (
	for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set BRANCH=%%b
)

if "%~1"=="" goto :menu

if /I "%~1"=="build" (
	if "%~2"=="" (
		echo Usage: lime.bat build [windows^|android^|html5^|linux^|mac]
		exit /b 1
	)
	haxelib run lime build %~2 -final
	exit /b %errorlevel%
)

if /I "%~1"=="release" (
	if "%~2"=="" (
		echo Usage: lime.bat release [windows^|android^|html5^|linux^|mac]
		echo   Builds using Build.hxp instead of project.hxp - a stricter, CI-style profile.
		exit /b 1
	)
	haxelib run lime build Build.hxp %~2 -final
	exit /b %errorlevel%
)

if /I "%~1"=="publish" (
	if "%~2"=="" (
		echo Usage: lime.bat publish [windows^|android^|html5^|linux^|mac]
		echo   Same as "release", but only allowed on the main branch.
		exit /b 1
	)
	if /I not "!BRANCH!"=="main" (
		echo [ERROR] "publish" only runs on the main branch. Current branch: "!BRANCH!"
		echo   git checkout main
		exit /b 1
	)
	echo Publishing from main branch...
	haxelib run lime build Build.hxp %~2 -final
	exit /b %errorlevel%
)

if /I "%~1"=="test" (
	if "%~2"=="" (
		echo Usage: lime.bat test [windows^|android^|html5]
		exit /b 1
	)
	haxelib run lime test %~2
	exit /b %errorlevel%
)

if /I "%~1"=="setup" (
	echo Installing hmm...
	haxelib install hmm
	echo Installing dependencies from hmm.json...
	haxelib run hmm install
	echo Setting up Lime...
	haxelib run lime setup -y
	echo Running project bootstrap (Setup.hx)...
	haxe --run setup/application/Setup.hx
	exit /b %errorlevel%
)

if /I "%~1"=="dev" (
	echo Switching to dev branch...
	git checkout dev
	if errorlevel 1 exit /b 1
	haxe --run setup/application/Setup.hx
	exit /b %errorlevel%
)

if /I "%~1"=="status" (
	echo.
	echo Shark status
	echo ==========================
	echo   Branch:        !BRANCH!
	if exist VERSION (
		set /p FILEVERSION=<VERSION
		echo   Version:       !FILEVERSION!
	) else (
		echo   Version:       ^(no VERSION file - run "lime.bat setup"^)
	)
	if exist .build_number (
		set /p BUILDNUM=<.build_number
		echo   Build number:  !BUILDNUM!
	) else (
		echo   Build number:  0 ^(none yet^)
	)
	if exist assets\data\config.json (
		echo   Config:        OK
	) else (
		echo   Config:        MISSING - run "lime.bat setup"
	)
	if exist mods (
		echo   Mods folder:   present
	) else (
		echo   Mods folder:   missing - run "lime.bat setup"
	)
	echo.
	exit /b 0
)

if /I "%~1"=="check" (
	echo Running pre-flight checks ^(branch: !BRANCH!^)...
	set CHECK_FAILED=0

	if not exist assets\data\config.json (
		echo   [FAIL] assets\data\config.json missing
		set CHECK_FAILED=1
	) else (
		echo   [OK]   config.json present
	)

	if not exist VERSION (
		echo   [WARN] no VERSION file
	) else (
		echo   [OK]   VERSION present
	)

	if /I "!BRANCH!"=="main" (
		if not exist Certificates\android.keystore (
			echo   [WARN] Certificates\android.keystore missing - Android release build will fail
		) else (
			echo   [OK]   Android keystore present
		)
	)

	if "!CHECK_FAILED!"=="1" (
		echo.
		echo Pre-flight checks FAILED.
		exit /b 1
	)

	echo.
	echo Pre-flight checks passed.
	exit /b 0
)

if /I "%~1"=="clean" (
	if "%~2"=="" (
		if exist export (
			echo Removing entire export folder...
			rmdir /s /q export
		)
	) else (
		if exist export\%~2 (
			echo Removing export\%~2...
			rmdir /s /q export\%~2
		)
	)
	exit /b 0
)

if /I "%~1"=="doctor" (
	echo Checking Haxe...
	haxe -version
	echo Checking installed haxelibs...
	haxelib list
	exit /b 0
)

if /I "%~1"=="mods" (
	if not exist mods (
		echo No mods folder yet - run "lime.bat setup" first.
		exit /b 1
	)
	echo Opening mods folder...
	start "" "mods"
	exit /b 0
)

if /I "%~1"=="astc" (
	if not exist assets\images (
		echo No assets\images folder found.
		exit /b 1
	)
	echo Compressing assets\images to assets\images\astc ...
	haxelib run astc-compressor compress -i assets\images -blocksize 6x6 -quality medium -colorprofile cl -o assets\images\astc
	exit /b %errorlevel%
)

if /I "%~1"=="version" (
	if "%~2"=="" (
		if exist VERSION (
			type VERSION
		) else (
			echo No VERSION file yet - run "lime.bat setup" first.
		)
		exit /b 0
	)
	echo %~2> VERSION
	echo VERSION set to %~2
	exit /b 0
)

echo Unknown command: %~1
echo.
goto :menu

:menu
echo.
echo Shark - Lime build helper  ^(branch: !BRANCH!^)
echo ==========================
echo   lime.bat setup               Install hmm, dependencies, set up Lime, run project bootstrap
echo   lime.bat dev                 Switch to the dev branch and run project bootstrap
echo   lime.bat status              Show branch, version, build number, config status
echo   lime.bat check               Run pre-flight validation without building
echo   lime.bat build ^<target^>      Build for a target using project.hxp
echo   lime.bat release ^<target^>    Build using Build.hxp ^(stricter CI-style profile^)
echo   lime.bat publish ^<target^>    Same as release, but only allowed on the main branch
echo   lime.bat test ^<target^>       Build and run for a target
echo   lime.bat clean [target]      Remove the export folder ^(all, or just one target^)
echo   lime.bat doctor              Print Haxe version and installed haxelibs
echo   lime.bat mods                Open the mods folder
echo   lime.bat astc                Compress assets\images to ASTC textures (assets\images\astc)
echo   lime.bat version [x.y.z]     Show or set the VERSION file
echo.
exit /b 0
