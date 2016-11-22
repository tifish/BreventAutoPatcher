@echo off
@setlocal EnableDelayedExpansion
@echo off

color 3f

title 黑域补丁自动制作 2.8 by Tinyfish
echo =================================================
echo   此脚本一键制作黑域内核补丁，功能包括：
echo   * 自动上传下载手机中的内核文件。
echo   * 检测并提示需要安装的基础库。
echo   * 检测adb root权限。
echo   * 区分处理jar和odex的情况。
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
	echo   * 拷贝services.jar到当前目录。
	echo.
	echo   * 如果存在services.odex，拷贝/system/framework/内容到odex目录。
	echo.
	pause
)

echo.
echo =================================================
echo   检查环境。。。
echo.

:CHECK_ENV

reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Python\PythonCore"
if not errorlevel 1 (
	for /f "tokens=*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Python\PythonCore"') do (
		set pythonVersionReg=%%a
		for /f "tokens=2*" %%a in ('reg query "!pythonVersionReg!\InstallPath" /ve 2^>nul') do (
			if exist "%%bpython.exe" set pythonPath=%%b
		)
	)
)

if "!pythonPath!"=="" (
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Python\PythonCore"
	if not errorlevel 1 (
		for /f "tokens=*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Python\PythonCore"') do (
			set pythonVersionReg=%%a
			for /f "tokens=2*" %%a in ('reg query "!pythonVersionReg!\InstallPath" /ve 2^>nul') do (
				if exist "%%bpython.exe" set pythonPath=%%b
			)
		)
	)
)

echo.
echo   Python路径: !pythonPath!
if exist "!pythonPath!python.exe" set path=!pythonPath!;!path!

where python
if errorlevel 1 (
	echo.
	echo   未安装Python，请自行下载安装（https://www.python.org/ftp/python/2.7.12/python-2.7.12.msi）
	echo.
	pause
	exit /b
)

reg query "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit"
if not errorlevel 1 (
	for /f "tokens=*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit"') do (
		set jdkVersionReg=%%a
		for /f "tokens=2*" %%a in ('reg query "!jdkVersionReg!" /v JavaHome 2^>nul') do (
			if exist "%%b\bin\jar.exe" set jdkPath=%%b
		)
	)
)

if "!jdkPath!"=="" (
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\JavaSoft\Java Development Kit"
	if not errorlevel 1 (
		for /f "tokens=*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\JavaSoft\Java Development Kit"') do (
			set jdkVersionReg=%%a
			for /f "tokens=2*" %%a in ('reg query "!jdkVersionReg!" /v JavaHome 2^>nul') do (
				if exist "%%b\bin\jar.exe" set jdkPath=%%b
			)
		)
	)
)

echo.
echo   JDK路径：!jdkPath!
if exist "!jdkPath!\bin\jar.exe" set path=!jdkPath!\bin;!path!

where jar
if errorlevel 1 (
	echo.
	echo   未安装JDK，请自行下载安装（http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-windows-i586.exe）
	echo.
	pause
	exit /b
)

if "!UseAdb!"=="1" (
	for /f "tokens=*" %%t in ('adb get-state') do set adbState=%%t
	echo.
	echo   Adb状态: !adbState!
	if not "!adbState!"=="device" (
		echo.
		echo   尝试添加adb vendor id。。。
		call "%~dp0AddAndroidVendorID.cmd"
		adb kill-server
		ping -n 2 127.0.0.1 >nul
		
		for /f "tokens=*" %%t in ('adb get-state') do set adbState=%%t
		echo.
		echo   Adb状态: !adbState!
		if not "!adbState!"=="device" (
			echo.
			echo   无法连接adb，请确保：
			echo.
			echo   * 电脑已安装adb驱动（http://download.clockworkmod.com/test/UniversalAdbDriverSetup.msi）。
			echo.
			echo   * 手机允许ADB调试和root（http://www.shuame.com/faq/usb-connect/9-usb.html）。
			echo.
			echo   * 把手机接上USB。
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

if exist services rd /s/q services
if exist classes.dex del /q classes.dex

if "!UseAdb!"=="1" (
	if exist services.jar del /q services.jar
	if exist odex rd /s/q odex
)

if "!UseAdb!"=="1" (
	echo.
	echo =================================================
	echo   获取services.jar。。。
	echo.

	adb pull /system/framework/services.jar

	adb shell ls -lR /system/framework|find "services.odex">ls.tmp
	for /f "tokens=7" %%a in (ls.tmp) do set file=%%a
	del /q ls.tmp >nul
	if "!file!"=="services.odex" (
		if not exist odex md odex
		pushd .
		cd odex
		..\adb pull /system/framework
		popd
	)
)

if exist odex (
	for /f "tokens=*" %%a in ('dir /b /s services.odex') do set servicesOdexPath=%%a
	for %%a in ("!servicesOdexPath!") do set servicesOdexDir=%%~dpa
	set servicesOdexDir=!servicesOdexDir:~0,-1!
	
	for /f "tokens=*" %%a in ('dir /b /s boot.oat') do set bootOatPath=%%a
	if not exist "!bootOatPath!" (
		echo.
		echo   存在services.odex，但找不到boot.oat，无法继续。
		echo.
		pause
		exit /b
	)
	for %%a in ("!bootOatPath!") do set bootOatDir=%%~dpa
	set bootOatDir=!bootOatDir:~0,-1!
)

if not exist bak md bak
if exist services.jar copy /y services.jar bak\services.jar

if not "!servicesOdexPath!"=="" (
	if exist odex\services.odex copy /y "!servicesOdexPath!" bak\services.odex
	
	echo.
	echo =================================================
	echo   正在把services.odex转成smali。。。
	echo.
	if "!androidVersion!"=="5" (
		java -Xms1g -jar oat2dex.jar boot "!bootOatPath!"
		if errorlevel 1 echo 转换boot.oat出错。& pause & exit /b
		java -Xms1g -jar oat2dex.jar "!servicesOdexPath!" !bootOatDir!\dex
		if errorlevel 1 echo 转换services.odex出错。& pause & exit /b
		java -Xms1g -jar baksmali-2.2b4.jar d "!servicesOdexDir!\services.dex" -o services		
		if errorlevel 1 echo 转换services.dex出错。& pause & exit /b
	) else (
		java -Xms1g -jar baksmali-2.2b4.jar x -d "!bootOatDir!" "!servicesOdexPath!" -o services
		if errorlevel 1 echo 转换odex出错。& pause & exit /b
	)
) else (
	echo.
	echo =================================================
	echo   正在把services.jar转成smali。。。
	echo.
	if exist services.jar (
		java -Xms1g -jar baksmali-2.2b4.jar d services.jar -o services
		if errorlevel 1 echo 转换services.jar出错。& pause & exit /b
	) else (
		echo.
		echo =================================================
		echo   无法下载services.jar/odex，请检查手机是否正常连接。
		echo.
		pause
		exit /b
	)
)

echo.
echo =================================================
echo   正在把apk转成smali。。。
echo.
if not exist apk java -Xms1g -jar baksmali-2.2b4.jar d Brevent.apk -o apk

echo.
echo =================================================
echo   正在打补丁。。。
echo.
python patch.py -a apk -s services
if errorlevel 1 echo 打补丁出错。& pause & exit /b
echo.
echo   请确认打补丁是否成功：
echo.
echo   * 注意！！！少打了补丁可能会导致手机无法启动！除非你很清楚这没问题，或者是刷机高手无所谓，否则请点右上角的X直接关闭本工具。
echo.
echo   * 如果成功请按任意键继续。
pause >nul

echo.
echo =================================================
echo   正在输出打过补丁的services.jar。。。
echo.
java -Xms1g -jar smali-2.2b4.jar a -o classes.dex services
if errorlevel 1 echo 输出classes.dex出错。& pause & exit /b
jar -cvf services.jar classes.dex
if errorlevel 1 echo 打包classes.dex出错。& pause & exit /b

echo.
echo =================================================
echo   清理临时文件。。。
echo.

if exist services rd /s/q services
if exist classes.dex del /q classes.dex

if "!UseAdb!"=="1" (
	if exist odex rd /s/q odex
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
