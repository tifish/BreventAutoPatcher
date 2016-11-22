@setlocal

@powershell "gwmi Win32_USBControllerDevice | %%{[wmi]($_.Dependent)} | ?{$_.CompatibleID -like \"USB\Class_ff^&SubClass_42^&Prot_0?\"} | %%{write \"0x$([regex]::match($_.deviceid.tolower(), 'vid_(\w+)').groups[1].value)\"} | sort -u">VendorID.txt
@set /p vendorID=<VendorID.txt
@echo   VendorID: %vendorID%
@del /q VendorID.txt
@if "%vendorID%"=="" exit /b 1

@set adbUsbIni=%ANDROID_SDK_HOME%\.android\adb_usb.ini
@if not exist "%adbUsbIni%" set adbUsbIni=%USERPROFILE%\.android\adb_usb.ini
@echo   adb_usb.ini: %adbUsbIni%
@if exist "%adbUsbIni%" (
	type "%adbUsbIni%"|find "%vendorID%"
	if errorlevel 1 (
		echo %vendorID%>>"%adbUsbIni%"
	)
) else (
	if not exist %USERPROFILE%\.android md %USERPROFILE%\.android
	echo %vendorID%>"%adbUsbIni%"
)

@endlocal
