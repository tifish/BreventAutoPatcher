@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 3f

cd /d "%~dp0"
set "path=%~dp0Binary;%~dp0jre\bin;!path!"

title 黑域补丁自动制作 4.6 by Tinyfish
echo =================================================
echo   此脚本一键制作黑域内核补丁，功能包括：
echo   * 自动上传下载手机中的内核文件。
echo   * 不需要额外安装Python，提示下载JRE库。
echo   * 自动安装adb驱动。
echo   * 检测adb root权限。
echo   * 智能区分处理jar和odex的情况。
echo   * 支持Android 4.x~7.x。
echo   * 安装黑域app。
echo   * 清理临时文件。
echo   * 支持手工制作补丁。
echo   * 自动生成刷机补丁包和恢复包。

set "UseAdb=1"
if /i "%~1"=="NoAdb" (
	set "UseAdb=0"
	echo.
	echo =================================================
	echo   手工补丁制作模式，请：
	echo.
	echo   * 拷贝services.jar到framework\下，请自行创建framework目录。
	echo.
	echo   * 如果存在services.odex，拷贝/system/framework/所有内容到framework\目录。
	echo.
	pause
)

echo.
echo =================================================
echo   检查环境。。。
echo.

:CHECK_ENV

if "!UseAdb!"=="1" (
	for /f "tokens=*" %%t in ('adb get-state') do set "adbState=%%t"
	echo.
	echo   Adb状态: !adbState!
	if not "!adbState!"=="device" (
		echo.
		echo   尝试安装adb驱动。。。
		call "InstallUsbDriver.cmd"

		echo.
		echo   尝试添加adb vendor id。。。
		call "AddAndroidVendorID.cmd"

		adb kill-server
		ping -n 2 127.0.0.1 >nul
		
		for /f "tokens=*" %%t in ('adb get-state') do set "adbState=%%t"
		echo.
		echo   Adb状态: !adbState!
		if not "!adbState!"=="device" (
			echo.
			echo   无法连接adb，请确保：
			echo.
			echo   * 把手机接上USB。
			echo.
			echo   * 手机允许ADB调试和root（http://www.shuame.com/faq/usb-connect/9-usb.html）。
			echo.
			pause
			goto :CHECK_ENV
		)
	)

	for /f "tokens=1 delims=." %%t in ('adb shell getprop ro.build.version.release') do set "androidVersion=%%t"
) else (
	echo.
	echo 请输入文件所属的安卓版本（4/5/6/7）：
	set /p androidVersion=
)

echo.
echo   Android版本：!androidVersion!

echo.
echo =================================================
echo   清理文件。。。
echo.

FastCopy /cmd=delete /no_ui "apk" "services" "classes.dex" "services.jar"

if "!UseAdb!"=="1" (
	FastCopy /cmd=delete /no_ui "framework"
)

if "!UseAdb!"=="1" (
	echo.
	echo =================================================
	echo   获取services.jar。。。
	echo.

	adb shell ls -lR "/system/framework"|find "services.odex"
	if errorlevel 1 (
		if not exist "framework" md "framework"
		cd "framework"
		adb pull "/system/framework/services.jar"
		if errorlevel 1 echo   下载services.jar失败。 & pause & exit /b
		cd "%~dp0"
	) else (
		adb pull "/system/framework"
		if errorlevel 1 echo   下载framework/失败。 & pause & exit /b
	)
)

if not exist "framework\services.jar" (
	echo.
	echo   找不到services.jar，无法继续。
	echo.
	echo   请按任意键退出。。。
	pause >nul
	exit /b
)

echo.
echo =================================================
echo   检测services.odex。。。
echo.

if "!androidVersion!"=="4" echo   Android 4.x不需要处理services.odex。 & goto :SKIP_SERVICES_ODEX

cd "framework"
for /f "tokens=*" %%a in ('dir /b /s services.odex 2^>nul') do set "servicesOdexPath=%%a"
cd "%~dp0"
if not exist "!servicesOdexPath!" echo   不存在services.odex & goto :SKIP_SERVICES_ODEX
for %%a in ("!servicesOdexPath!") do set "servicesOdexDir=%%~dpa"
set "servicesOdexDir=!servicesOdexDir:~0,-1!"

cd "framework"
for /f "tokens=*" %%a in ('dir /b /s boot.oat') do set "bootOatPath=%%a"
cd "%~dp0"
if not exist "!bootOatPath!" (
	echo.
	echo   存在services.odex，但找不到boot.oat，无法继续。
	echo.
	echo   请按任意键退出。。。
	pause >nul
	exit /b
)
for %%a in ("!bootOatPath!") do set "bootOatDir=%%~dpa"
set "bootOatDir=!bootOatDir:~0,-1!"

:TRY_MOVE_FRAMEWORK
md "\BreventAutoPatchTemp"
move "framework" "\BreventAutoPatchTemp\\"
if errorlevel 1 echo   检测到framework目录被锁定，请不要打开framework目录或其中的文件。& pause & goto :TRY_MOVE_FRAMEWORK

cd "/BreventAutoPatchTemp/framework"
for /f "tokens=*" %%a in ('dir /b /s services.odex 2^>nul') do set "servicesOdexFrameworkPath=%%a"
cd "%~dp0"

move "\BreventAutoPatchTemp\framework" ".\\"
rd "\BreventAutoPatchTemp"

set "servicesOdexFrameworkPath=!servicesOdexFrameworkPath:~24!"
set "servicesOdexFrameworkDir=!servicesOdexFrameworkPath:~0,-14!"

set "servicesOdexMobilePath=/system/!servicesOdexFrameworkPath!"
set "servicesOdexMobilePath=!servicesOdexMobilePath:\=/!"

echo.
echo   services.odex电脑路径：!servicesOdexFrameworkPath!
echo   services.odex手机路径：!servicesOdexMobilePath!
echo.

:SKIP_SERVICES_ODEX

echo.
echo =================================================
echo   生成刷机恢复包BreventRestore.zip。。。
echo.

copy /y "Package\Update.zip" "BreventRestoreRaw.zip"
FastCopy /cmd=delete /no_ui "system"
md "system\framework"

copy /y "framework\services.jar" "system\framework\\"
if exist "!servicesOdexPath!" (
	md "system\!servicesOdexFrameworkDir!" 2>nul
	copy /y "!servicesOdexPath!" "system\!servicesOdexFrameworkDir!\\"
)

zip -r "BreventRestoreRaw.zip" "system\\"
if errorlevel 1 echo   无法生成刷机恢复包。& pause & exit /b
java -jar "%~dp0Binary\signapk.jar" "Binary\testkey.x509.pem" "Binary\testkey.pk8" "BreventRestoreRaw.zip" "BreventRestore.zip"
if errorlevel 1 echo   无法签名刷机补丁包。& pause & exit /b

del /q "BreventRestoreRaw.zip"
FastCopy /cmd=delete /no_ui "system"

if exist "!servicesOdexPath!" (
	echo.
	echo =================================================
	echo   正在把services.odex转成smali。。。
	echo.
	if "!androidVersion!"=="5" (
		java -jar "%~dp0Binary\oat2dex.jar" boot "!bootOatPath!"
		if errorlevel 1 echo   转换boot.oat出错。& pause & exit /b
		java -jar "%~dp0Binary\oat2dex.jar" "!servicesOdexPath!" "!bootOatDir!\dex"
		if errorlevel 1 echo   转换services.odex出错。& pause & exit /b
		java -jar "%~dp0Binary\baksmali-2.2b4.jar" d "!servicesOdexDir!\services.dex" -o "services"
		if errorlevel 1 echo   转换services.dex出错。& pause & exit /b
	) else (
		java -jar "%~dp0Binary\baksmali-2.2b4.jar" x -d "!bootOatDir!" "!servicesOdexPath!" -o "services"
		if errorlevel 1 echo   转换odex出错。& pause & exit /b
	)
) else (
	echo.
	echo =================================================
	echo   正在把services.jar转成smali。。。
	echo.
	java -jar "%~dp0Binary\baksmali-2.2b4.jar" d "framework\services.jar" -o "services"
	if errorlevel 1 echo   转换services.jar出错。& pause & exit /b
)

echo.
echo =================================================
echo   正在把apk转成smali。。。
echo.
java -jar "%~dp0Binary\baksmali-2.2b4.jar" d "Package\Brevent.apk" -o "apk"

echo.
echo =================================================
echo   正在打补丁。。。
echo.
patch -a "apk" -s "services"
if errorlevel 1 (
	echo.
	echo   打补丁出错，这会导致手机无法启动！骚年，不能再继续了，要出事的。
	echo.
	echo   请按任意键退出。。。
	pause >nul
	exit /b
)

echo.
echo =================================================
echo   正在输出打过补丁的services.jar。。。
echo.
java -jar "%~dp0Binary\smali-2.2b4.jar" a -o "classes.dex" "services"
if errorlevel 1 echo   输出classes.dex出错。& pause & exit /b
copy /y "framework\services.jar" ".\\"
zip "services.jar" "classes.dex"
if errorlevel 1 echo   打包classes.dex出错。& pause & exit /b

echo.
echo =================================================
echo   生成刷机补丁包BreventPatch.zip。。。
echo.

copy /y "Package\Update.zip" "BreventPatchRaw.zip"
FastCopy /cmd=delete /no_ui "system"
md "system\framework"
copy /y "services.jar" "system\framework\\"

zip -r "BreventPatchRaw.zip" "system\\"
if errorlevel 1 echo   无法生成刷机补丁包。& pause & exit /b
java -jar "%~dp0Binary\signapk.jar" "Binary\testkey.x509.pem" "Binary\testkey.pk8" "BreventPatchRaw.zip" "BreventPatch.zip"
if errorlevel 1 echo   无法签名刷机补丁包。& pause & exit /b

del /q "BreventPatchRaw.zip"
FastCopy /cmd=delete /no_ui "system"

if "!UseAdb!"=="1" (
	echo.
	echo =================================================
	echo   检查黑域是否已安装。。。
	echo.

	adb shell pm list packages|find "me.piebridge.prevent"
	if errorlevel 1 (
		echo   安装黑域。。。
		echo.
		adb install "Package\Brevent.apk"
	)

	echo.
	echo =================================================
	echo 上传生成的services.jar到/system/framework中。
	echo.

	adb push "services.jar" "/sdcard/"
	if errorlevel 1 echo 上传services.jar到/sdcard/失败。& call :PushError

	adb push "BreventRestore.zip" "/sdcard/"
	if errorlevel 1 echo 上传BreventRestore.zip到/sdcard/失败。& call :PushError

	adb push "BreventPatch.zip" "/sdcard/"
	if errorlevel 1 echo 上传BreventPatch.zip到/sdcard/失败。& call :PushError

	:CHECK_ROOT
	adb shell su -c 'chmod 666 "/data/data/com.android.providers.contacts/databases/contacts2.db"'
	if errorlevel 1 (
		echo.
		echo   adb没有root权限，请确保：
		echo.
		echo   * 手机已经root。
		echo.
		echo   * adb已获得root权限。可能是手机屏幕上提示需要确认，CM系统可能需要在开发者选项中允许adb root，SuperSU可能需要关闭“分类挂载命名空间。
		echo.
		echo   如果adb无法获得root权限，你也可以手工拷贝services.jar到/system/framework/中，或者使用刷机包BrenventPatch.zip。
		echo.
		pause
		goto :CHECK_ROOT
	) else (
		adb shell su -c 'chmod 660 "/data/data/com.android.providers.contacts/databases/contacts2.db"'
	)

	adb shell su -c 'mount -o rw,remount "/system"'
	if errorlevel 1 echo   加载system分区失败。& call :PushError
	adb shell su -c 'cp -f "/sdcard/services.jar" "/system/framework/"'
	if errorlevel 1 echo   拷贝services.jar失败。& call :PushError
	adb shell su -c 'chmod 644 "/system/framework/services.jar"'
	if errorlevel 1 echo   修改services.jar权限失败。& call :PushError

	if exist "!servicesOdexPath!" (
		adb shell su -c 'rm -f "!servicesOdexMobilePath!"'
		if errorlevel 1 echo   删除services.odex失败。& call :PushError
	)
)

echo.
echo =================================================
echo   清理临时文件。。。
echo.

FastCopy /cmd=delete /no_ui "apk" "services" "classes.dex"

if "!UseAdb!"=="1" (
	FastCopy /cmd=delete /no_ui "framework"
)

if "!UseAdb!"=="1" (
	echo.
	echo =================================================
	echo   完成！记得重启手机。
	echo.
	echo   如果无法正常启动可以刷BreventRestore.zip恢复。
	echo.
	pause
) else (
	echo.
	echo =================================================
	echo   完成！请自行刷BreventPatch.zip或拷贝services.jar，可能还需要删除services.odex。
	echo.
	echo   如果无法正常启动可以刷BreventRestore.zip恢复。
	echo.
	pause
)

goto :EOF
:PushError
setlocal
echo.
echo   因为rom的限制，无法自动上传services.jar。请使用刷机包BrenventPatch.zip，或者手动拷贝services.jar到/system/framework/，可能还需要删除services.odex。
echo.
pause
exit /b
(endlocal)
goto :EOF

endlocal
