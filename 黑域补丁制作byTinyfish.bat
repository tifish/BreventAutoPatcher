@setlocal EnableDelayedExpansion

@color 3f
@title 黑域补丁自动制作 2.4 by Tinyfish
@echo =================================================
@echo   此脚本一键制作黑域内核补丁，功能包括：
@echo   * 自动上传下载手机中的内核文件。
@echo   * 检测并提示需要安装的基础库。
@echo   * 检测adb root权限。
@echo   * 区分处理jar和odex的情况。
@echo   * 支持Android 4.x~7.x。
@echo   * 安装黑域app。
@echo   * 清理临时文件。

@echo.
@echo =================================================
@echo   检查环境。。。
@echo.

:CHECK_ENV

@for /f "tokens=*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Python\PythonCore"') do @set pythonVersionReg=%%a
@for /f "tokens=2*" %%a in ('reg query "%pythonVersionReg%\InstallPath" /ve') do @set pythonPath=%%b
@echo Python路径: %pythonPath%
@if exist "%pythonPath%python.exe" set path=%pythonPath%;%path%

@where python >nul 2>nul
@if "%errorlevel%"=="1" (
	echo.
	echo   未安装Python，请自行下载安装（https://www.python.org/ftp/python/2.7.12/python-2.7.12.msi）
	echo.
	pause
	exit /b
)

@for /f "tokens=*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit"') do @set jdkVersionReg=%%a
@for /f "tokens=2*" %%a in ('reg query "%jdkVersionReg%" /v JavaHome') do @set jdkPath=%%b
@echo JDK路径：%jdkPath%
@if exist "%jdkPath%\bin\jar.exe" set path=%jdkPath%\bin;%path%

@where jar >nul 2>nul
@if "%errorlevel%"=="1" (
	echo.
	echo   未安装JDK，请自行下载安装（http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-windows-i586.exe）
	echo.
	pause
	exit /b
)

@for /f "tokens=*" %%t in ('adb get-state') do @set adbState=%%t
@if not "%adbState%"=="device" (
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

@for /f "tokens=1 delims=." %%t in ('adb shell getprop ro.build.version.release') do @set androidVersion=%%t
@echo.
@echo   Android版本：%androidVersion%
@echo.

@echo.
@echo =================================================
@echo   清理文件。。。
@echo.

@if exist services rd /s/q services
@if exist odex rd /s/q odex
@if exist classes.dex del /q classes.dex
@if exist services.jar del /q services.jar

@echo.
@echo =================================================
@echo   获取services.jar。。。
@echo.

adb pull /system/framework/services.jar

@adb shell ls -lR /system/framework|find "services.odex">ls.tmp
@for /f "tokens=7" %%a in (ls.tmp) do set file=%%a
@del /q ls.tmp >nul
@if "%file%"=="services.odex" (
	if not exist odex md odex
	pushd .
	cd odex
	..\adb pull /system/framework
	popd
	
	for /f "tokens=*" %%a in ('dir /b /s services.odex') do set servicesOdexPath=%%a
	for %%a in ("!servicesOdexPath!") do set servicesOdexDir=%%~dpa
	
	for /f "tokens=*" %%a in ('dir /b /s boot.oat') do set bootOatPath=%%a
	if not exist "!bootOatPath!" (
		echo.
		echo   存在services.odex，但找不到boot.oat，无法继续。
		echo.
		pause
		exit /b
	)
	for %%a in ("!bootOatPath!") do set bootOatDir=%%~dpa
)

@if not exist bak md bak
@if exist services.jar copy /y services.jar bak\services.jar

@if not "%servicesOdexPath%"=="" (
	if exist odex\services.odex copy /y "%servicesOdexPath%" bak\services.odex
	
	echo.
	echo =================================================
	echo   正在把services.odex转成smali。。。
	echo.
	if "%androidVersion%"=="5" (
		java -Xms1g -jar oat2dex.jar boot "%bootOatPath%"
		if errorlevel 1 echo 转换boot.oat出错。& pause & exit /b
		java -Xms1g -jar oat2dex.jar "%servicesOdexPath%" %bootOatDir%dex
		if errorlevel 1 echo 转换services.odex出错。& pause & exit /b
		java -Xms1g -jar baksmali-2.2b4.jar d "%servicesOdexDir%\services.dex" -o services		
		if errorlevel 1 echo 转换services.dex出错。& pause & exit /b
	) else (
		java -Xms1g -jar baksmali-2.2b4.jar x -d odex "%servicesOdexPath%" -o services
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

@echo.
@echo =================================================
@echo   正在把apk转成smali。。。
@echo.
@if not exist apk java -Xms1g -jar baksmali-2.2b4.jar d Brevent.apk -o apk

@echo.
@echo =================================================
@echo   正在打补丁。。。
@echo.
python patch.py -a apk -s services
@if errorlevel 1 echo 打补丁出错。& pause & exit /b
@echo.
@echo   请确认打补丁是否成功，如果成功请按任意键继续，否则请检查错误并直接关闭本工具。
@pause >nul

@echo.
@echo =================================================
@echo   正在输出打过补丁的services.jar。。。
@echo.
java -Xms1g -jar smali-2.2b4.jar a -o classes.dex services
@if errorlevel 1 echo 输出classes.dex出错。& pause & exit /b
jar -cvf services.jar classes.dex
@if errorlevel 1 echo 打包classes.dex出错。& pause & exit /b

@echo.
@echo =================================================
@echo   清理临时文件。。。
@echo.

@if exist services rd /s/q services
@if exist odex rd /s/q odex
@if exist classes.dex del /q classes.dex

@echo.
@echo =================================================
@echo   检查黑域是否已安装。。。
@echo.

@adb shell pm list packages|find "me.piebridge.prevent"
@if "%errorlevel%"=="1" (
	echo   安装黑域。。。
	echo.
	adb install Brevent.apk
)

@echo.
@echo =================================================
@echo 上传生成的services.jar到/system/framework中。
@echo.

adb push services.jar /sdcard/

:CHECK_ROOT
@adb shell su -c "chmod 666 /data/data/com.android.providers.contacts/databases/contacts2.db"
@for /f "tokens=1" %%a in ('adb shell ls -l /data/data/com.android.providers.contacts/databases/contacts2.db') do @set mod=%%a
@adb shell su -c "chmod 660 /data/data/com.android.providers.contacts/databases/contacts2.db"
@if not "%mod%"=="-rw-rw-rw-" (
	echo.
	echo   adb没有root权限，请确保：
	echo.
	echo   * 手机已经root。
	echo.
	echo   * adb已获得root权限。可能是手机屏幕上提示需要确认，CM系统可能需要在开发者选项中允许adb root。
	echo.
	echo   如果adb无法获得root权限，你也可以手工拷贝services.jar到/system/framework/中。
	echo.
	pause
	goto :CHECK_ROOT
)

adb shell su -c "mount -o rw,remount /system"
adb shell su -c "cp -f /sdcard/services.jar /system/framework/"
adb shell su -c "chmod 644 /system/framework/services.jar"

@echo.
@echo =================================================
@echo   完成！记得重启手机。
@echo.
@pause

@endlocal
