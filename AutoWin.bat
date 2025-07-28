@echo off
setlocal EnableDelayedExpansion

:: ============================
:: Windows 10/11 자동 설치 프로그램
:: Hijiwho 제작
:: ============================

:: ====== 사용자 입력 ======
echo ==============================
echo Windows 윈도우 계정 설정을 시작합니다!
set /p USERNAME=1. 계정 이름이 무엇인가요? (Admin, Minsu 등..) :
set /p PASSWORD=2. 계정 비밀번호는 무엇인가요? (없으면 엔터, 설치 이후 암호 생성을 권장합니다!):
set /p COMPUTERNAME=3. 컴퓨터 이름은 무엇인가요? (Minsu-pc 등..):
set /p PRODUCTKEY=4. 제품키를 입력해주세요! (없으면 엔터):

:: ====== 비밀번호 공백 검사 ======
set PASSWORD_TMP=%PASSWORD%
set PASSWORD_TMP=%PASSWORD_TMP: =%
if "%PASSWORD_TMP%"=="" (
    set PASSWORD_FLAG=false
) else (
    set PASSWORD_FLAG=true
)

:: ====== USB 드라이브 선택 ======
:SelectUSB
echo.
echo 연결된 USB 입니다.
for /f "skip=1 tokens=1" %%D in ('wmic logicaldisk where "drivetype=2" get deviceid') do (
    set DRIVE=%%D
    if not "!DRIVE!"=="" echo !DRIVE!
)
echo.
set /p USBDRIVE=5. 윈도우 설치 USB의 문자를 입력해주세요! (예: E:) :
if not "%USBDRIVE:~-1%"==":" set USBDRIVE=%USBDRIVE%:
if not exist %USBDRIVE%\setup.exe (
    echo [%USBDRIVE%] 에 setup.exe 가 없습니다. USB를 다시 선택해주세요!
    goto SelectUSB
)
if not exist %USBDRIVE%\sources\install.wim if not exist %USBDRIVE%\sources\install.esd (
    echo install.wim 또는 install.esd 파일이 없습니다. USB를 다시 선택해주세요!
    goto SelectUSB
)

:: ====== 인덱스 조회 ======
echo ==========================================
echo 설치 가능한 Windows 종류 (인덱스 확인)
set WIMPATH=%USBDRIVE%\sources\install.wim
if not exist "%WIMPATH%" set WIMPATH=%USBDRIVE%\sources\install.esd
dism /Get-WimInfo /WimFile:"%WIMPATH%"
echo ==========================================
set /p IMAGEINDEX=6. 설치할 인덱스 번호 입력 :

:: ====== 설치 방식 선택 ======
echo ==========================================
echo 설치 방식 선택:
echo 1번을 입력하면 자동으로 디스크를 초기화 하고 설치합니다 (SSD가 1개인 경우에 추천)
echo 2번을 입력하면 직접 디스크를 초기화 해야합니다. (SSD가 여러개 OR 듀얼부팅시 추천)
set /p INSTALLMODE=선택 (1 또는 2):
if "%INSTALLMODE%"=="1" (
    set DISKMODE=auto
) else (
    set DISKMODE=manual
)

:: ====== 우회 옵션 선택 ======
echo ==========================================
echo TPM / SecureBoot / CPU / RAM 우회 옵션:
echo 1번은 우회 하기 (윈도우 11이라면 2018년도 이전 OR 저렴한 노트북에 추천합니다.)
echo 2번은 적용 안함 (요구사항이 충족되면)
set /p BYPASSMODE=선택 (1 또는 2):

:: ====== 경로 설정 ======
set USBROOT=%USBDRIVE%\
set OEMDIR=%USBROOT%sources\$OEM$\$$\Setup\Scripts\
if not exist "%OEMDIR%" mkdir "%OEMDIR%"

:: ====== bypass.reg 생성 (선택적) ======
if "%BYPASSMODE%"=="1" (
    (
    echo Windows Registry Editor Version 5.00
    echo.
    echo [HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig]
    echo "BypassTPMCheck"=dword:00000001
    echo "BypassSecureBootCheck"=dword:00000001
    echo "BypassCPUCheck"=dword:00000001
    echo "BypassRAMCheck"=dword:00000001
    ) > "%USBROOT%bypass.reg"
)

:: ====== setupcomplete.cmd 생성 ======
(
    echo @echo off
    if exist "%%SystemDrive%%\bypass.reg" reg import "%%SystemDrive%%\bypass.reg"
    echo if exist "%%SystemDrive%%\Setup\Scripts\CrSet.exe" (
    echo     start /wait "" "%%SystemDrive%%\Setup\Scripts\CrSet.exe" /silent /install
    echo     echo 크롬 설치 완료!
    echo )
) > "%OEMDIR%setupcomplete.cmd"

:: ====== autounattend.xml 생성 ======
set UNATTEND=%USBROOT%autounattend.xml
(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<unattend xmlns="urn:schemas-microsoft-com:unattend"^>
echo   ^<settings pass="windowsPE"^>
echo     ^<component name="Microsoft-Windows-International-Core-WinPE" ... ^>
echo       ^<SetupUILanguage^> ^<UILanguage^>ko-KR^</UILanguage^> ^</SetupUILanguage^>
echo       ^<InputLocale^>0412:00000412^</InputLocale^>
echo       ^<SystemLocale^>ko-KR^</SystemLocale^>
echo       ^<UILanguage^>ko-KR^</UILanguage^>
echo     ^</component^>
echo     ^<component name="Microsoft-Windows-Setup" ...^>
echo       ^<ImageInstall^>
echo         ^<OSImage^>
echo           ^<InstallFrom^>
echo             ^<ImageIndex^>%IMAGEINDEX%^</ImageIndex^>
echo           ^</InstallFrom^>
echo           ^<WillShowUI^>OnError^</WillShowUI^>
if "%DISKMODE%"=="auto" (
    echo           ^<InstallTo^> ^<DiskID^>0^</DiskID^> ^<PartitionID^>1^</PartitionID^> ^</InstallTo^>
)
echo         ^</OSImage^>
echo       ^</ImageInstall^>
echo       ^<UserData^>
echo         ^<AcceptEula^>true^</AcceptEula^>
echo         ^<FullName^>%USERNAME%^</FullName^>
echo         ^<Organization^>None^</Organization^>
echo         ^<ProductKey^> ^<Key^>%PRODUCTKEY%^</Key^> ^</ProductKey^>
echo       ^</UserData^>
echo     ^</component^>
echo   ^</settings^>
echo   ^<settings pass="oobeSystem"^>
echo     ^<component name="Microsoft-Windows-Shell-Setup" ...^>
echo       ^<OOBE^>
echo         ^<HideEULAPage^>true^</HideEULAPage^>
echo         ^<HideWirelessSetupInOOBE^>true^</HideWirelessSetupInOOBE^>
echo         ^<HideOnlineAccountScreens^>true^</HideOnlineAccountScreens^>
echo         ^<NetworkLocation^>Work^</NetworkLocation^>
echo         ^<ProtectYourPC^>3^</ProtectYourPC^>
echo       ^</OOBE^>
echo       ^<AutoLogon^>
echo         ^<Username^>%USERNAME%^</Username^>
if "%PASSWORD_FLAG%"=="true" (
    echo         ^<Password^> ^<Value^>%PASSWORD%^</Value^> ^<PlainText^>true^</PlainText^> ^</Password^>
)
echo         ^<Enabled^>true^</Enabled^>
echo       ^</AutoLogon^>
echo       ^<UserAccounts^>
echo         ^<LocalAccounts^>
echo           ^<LocalAccount^> ^<Name^>%USERNAME%^</Name^> ^<Group^>Administrators^</Group^>
if "%PASSWORD_FLAG%"=="true" (
    echo             ^<Password^> ^<Value^>%PASSWORD%^</Value^> ^<PlainText^>true^</PlainText^> ^</Password^>
)
echo           ^</LocalAccount^>
echo         ^</LocalAccounts^>
echo       ^</UserAccounts^>
echo       ^<RegisteredOwner^>%USERNAME%^</RegisteredOwner^>
echo       ^<ComputerName^>%COMPUTERNAME%^</ComputerName^>
echo     ^</component^>
echo   ^</settings^>
echo ^</unattend^>
) > "%UNATTEND%"

:: ====== 크롬 설치 파일 다운로드 (CrSet.exe) ======
echo 크롬 설치파일을 다운로드 합니다.
bitsadmin /transfer CrSetDownloadJob /priority normal https://dl.google.com/chrome/install/standalonesetup64.exe "%TEMP%\CrSet.exe"
if exist "%TEMP%\CrSet.exe" (
    copy /y "%TEMP%\CrSet.exe" "%OEMDIR%CrSet.exe"
    echo 완료되었습니다! *(자동으로 설치됨)
) else (
    echo 실패했습니다. 설치 후 Chrome.com 에 접속하여 직접 다운받아주세요!
)

echo ==============================
echo 설치 USB 생성 완료!
echo 다시 BIOS에 들어가서 윈도우를 우선순위로 해주세요!
pause
exit
