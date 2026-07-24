@echo off
setlocal

if "%~1"=="" goto :menu

if /I "%~1"=="build" (
	if "%~2"=="" (
		echo Usage: lime.bat build [windows^|android^|html5^|linux^|mac]
		exit /b 1
	)
	haxelib run lime build %~2 -final
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
	exit /b %errorlevel%
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

echo Unknown command: %~1
echo.
goto :menu

:menu
echo.
echo Shark - Lime build helper
echo ==========================
echo   lime.bat setup               Install hmm, dependencies, and set up Lime
echo   lime.bat build ^<target^>      Build for a target (windows / android / html5 / linux / mac)
echo   lime.bat test ^<target^>       Build and run for a target
echo   lime.bat clean [target]      Remove the export folder (all, or just one target)
echo   lime.bat doctor              Print Haxe version and installed haxelibs
echo.
exit /b 0
