@echo off
setlocal

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
		exit /b 1
	)
	haxelib run lime build Build.hxp %~2 -final
	exit /b %errorlevel%
)

if /I "%~1"=="test" (
	if "%~2"=="" (
		echo Usage: lime.bat test [windows^|android^|html5^|linux^|mac]
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
	echo Checking Haxe version...
	haxe -version
	echo Checking installed haxelibs...
	haxelib list
	exit /b 0
)

if /I "%~1"=="mods" (
	if not exist mods (
		echo Mods folder does not exist. Run "lime.bat setup" first.
		exit /b 1
	)
	echo Opening mods folder...
	start "" "mods"
	exit /b 0
)

if /I "%~1"=="version" (
	if "%~2"=="" (
		if exist VERSION (
			type VERSION
		) else (
			echo VERSION file not found. Run "lime.bat setup" first.
		)
		exit /b 0
	)
	echo %~2> VERSION
	echo VERSION set to %~2
	exit /b 0
)

echo Unknown command: %~1
echo.

:menu
echo.
echo Shark - Lime Build Helper
echo ==========================
echo   lime.bat setup               
echo   lime.bat build ^<target^>      
echo   lime.bat release ^<target^>    
echo   lime.bat test ^<target^>       
echo   lime.bat clean [target]      
echo   lime.bat doctor              
echo   lime.bat mods                
echo   lime.bat version [x.y.z]     
echo.
exit /b 0
