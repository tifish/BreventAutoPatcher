@echo off
setlocal EnableDelayedExpansion
color 3f

cd /d "%~dp0"
set path=%~dp0Binary;!path!

title 黑域补丁自动制作 3.5 by Tinyfish
echo =================================================
echo   此脚本一键制作黑域内核补丁，功能包括：
echo   * 自动上传下载手机中的内核文件。
echo   * 不需要额外安装Python和JDK库。
echo   * 自动安装adb驱动。
echo   * 检测adb root权限。
echo   * 智能区分处理jar和odex的情况。
echo   * 支持Android 4.x~7.x。
echo   * 安装黑域app。
echo   * 清理临时文件。
echo   * 支持手工制作补丁。

set UseAdb=1
if /i "%~1"=="NoAdb" (
	set UseAdb=0
	echo.
	echo =================================================
	echo   手工补丁制作模式，请：
	echo.
	echo   * 拷贝services.jar到./framework/下，请自行创建framework目录。
	echo.
	echo   * 如果存在services.odex，拷贝/system/framework/所有内容到./framework/目录。
	echo.
	pause
)

echo.
echo =================================================
echo   检查环境。。。
echo.

:CHECK_ENV

if "!UseAdb!"=="1" (
	for /f "tokens=*" %%t in ('adb get-state') do set adbState=%%t
	echo.
	echo   Adb状态: !adbState!
	if not "!adbState!"=="device" (
		echo.
		echo   尝试安装adb驱动。。。
		call InstallUsbDriver.cmd

		echo.
		echo   尝试添加adb vendor id。。。
		call AddAndroidVendorID.cmd

		adb kill-server
		ping -n 2 127.0.0.1 >nul
		
		for /f "tokens=*" %%t in ('adb get-state') do set adbState=%%t
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

	for /f "tokens=1 delims=." %%t in ('adb shell getprop ro.build.version.release') do set androidVersion=%%t
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

if exist apk rd /s/q apk
if exist services rd /s/q services
if exist classes.dex del /q classes.dex
if exist services.jar del /q services.jar

if "!UseAdb!"=="1" (
	if exist framework rd /s/q framework
)

if "!UseAdb!"=="1" (
	echo.
	echo =================================================
	echo   获取services.jar。。。
	echo.

	if not exist framework md framework
	pushd .
	cd framework
	
	for /f "tokens=*" %%a in ('adb shell ls -lR /system/framework^|find "services.odex"') do set odexFile=%%a
	if "!odexFile!"=="" (
		adb pull /system/framework/services.jar
	) else (
		adb pull /system/framework
	)

	popd
)

if not exist framework\services.jar (
	echo.
	echo   找不到services.jar，无法继续。
	echo.
	echo   请按任意键退出。。。
	pause >nul
	exit /b
)

pushd .
cd framework
for /f "tokens=*" %%a in ('dir /b /s services.odex') do set servicesOdexPath=%%a
if exist "!servicesOdexPath!" (
	for %%a in ("!servicesOdexPath!") do set servicesOdexDir=%%~dpa
	set servicesOdexDir=!servicesOdexDir:~0,-1!
	
	for /f "tokens=*" %%a in ('dir /b /s boot.oat') do set bootOatPath=%%a
	if not exist "!bootOatPath!" (
		echo.
		echo   存在services.odex，但找不到boot.oat，无法继续。
		echo.
		echo   请按任意键退出。。。
		pause >nul
		exit /b
	)
	for %%a in ("!bootOatPath!") do set bootOatDir=%%~dpa
	set bootOatDir=!bootOatDir:~0,-1!
)
popd

copy /y framework\services.jar .\

if exist "!servicesOdexPath!" (
	echo.
	echo =================================================
	echo   正在把services.odex转成smali。。。
	echo.
	if "!androidVersion!"=="5" (
		oat2dex.exe boot "!bootOatPath!"
		if errorlevel 1 echo 转换boot.oat出错。& pause & exit /b
		oat2dex.exe "!servicesOdexPath!" !bootOatDir!\dex
		if errorlevel 1 echo 转换services.odex出错。& pause & exit /b
		baksmali-2.2b4.exe d "!servicesOdexDir!\services.dex" -o services		
		if errorlevel 1 echo 转换services.dex出错。& pause & exit /b
	) else (
		baksmali-2.2b4.exe x -d "!bootOatDir!" "!servicesOdexPath!" -o services
		if errorlevel 1 echo 转换odex出错。& pause & exit /b
	)
) else (
	echo.
	echo =================================================
	echo   正在把services.jar转成smali。。。
	echo.
	baksmali-2.2b4.exe d framework\services.jar -o services
	if errorlevel 1 echo 转换services.jar出错。& pause & exit /b
)

echo.
echo =================================================
echo   正在把apk转成smali。。。
echo.
if not exist apk baksmali-2.2b4.exe d Brevent.apk -o apk

echo.
echo =================================================
echo   正在打补丁。。。
echo.
patch.exe -a apk -s services
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
smali-2.2b4.exe a -o classes.dex services
if errorlevel 1 echo 输出classes.dex出错。& pause & exit /b
zip.exe services.jar classes.dex
if errorlevel 1 echo 打包classes.dex出错。& pause & exit /b

echo.
echo =================================================
echo   清理临时文件。。。
echo.

if exist apk rd /s/q apk
if exist services rd /s/q services
if exist classes.dex del /q classes.dex

if "!UseAdb!"=="1" (
	if exist framework rd /s/q framework
)

if "!UseAdb!"=="1" (
	echo.
	echo =================================================
	echo   检查黑域是否已安装。。。
	echo.

	adb shell pm list packages|find "me.piebridge.prevent"
	if errorlevel 1 (
		echo   安装黑域。。。
		echo.
		adb install Brevent.apk
	)

	echo.
	echo =================================================
	echo 上传生成的services.jar到/system/framework中。
	echo.

	adb push services.jar /sdcard/

	:CHECK_ROOT
	adb shell su -c "chmod 666 /data/data/com.android.providers.contacts/databases/contacts2.db"
	for /f "tokens=1" %%a in ('adb shell su -c "ls -l /data/data/com.android.providers.contacts/databases/contacts2.db"') do set mod=%%a
	adb shell su -c "chmod 660 /data/data/com.android.providers.contacts/databases/contacts2.db"
	if not "!mod!"=="-rw-rw-rw-" (
		echo.
		echo   adb没有root权限，请确保：
		echo.
		echo   * 手机已经root。
		echo.
		echo   * adb已获得root权限。可能是手机屏幕上提示需要确认，CM系统可能需要在开发者选项中允许adb root，SuperSU可能需要关闭“分类挂载命名空间。
		echo.
		echo   如果adb无法获得root权限，你也可以手工拷贝services.jar到/system/framework/中。
		echo.
		pause
		goto :CHECK_ROOT
	)

	adb shell su -c "mount -o rw,remount /system"
	adb shell su -c "cp -f /sdcard/services.jar /system/framework/"
	adb shell su -c "chmod 644 /system/framework/services.jar"

	echo.
	echo =================================================
	echo   完成！记得重启手机。
	echo.
	pause
) else (
	echo.
	echo =================================================
	echo   完成！请自行食用services.jar。
	echo.
	pause
)

endlocal
