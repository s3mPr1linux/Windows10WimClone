cls
@echo *********************************************************************
@echo.
@echo 	###### PETRORIO SA ######
@echo.
@echo	Script de clone de imagens .wim para Windows 10 2H21.
@echo	Por Carlos Eduardo Barbosa - Julho/21 v1.0
@echo.
@echo *********************************************************************
@echo.
@if not exist X:\Windows\System32 echo ERROR: This script is built to run in Windows PE.
@if not exist X:\Windows\System32 goto END
@if %1.==. echo ERROR: To run this script, add a path to a Windows image file.
@if %1.==. echo Example: ApplyImage E:\Imagens\Contoso.wim
@if %1.==. goto END
@echo *********************************************************************
@echo  == Setting high-performance power scheme to speed deployment ==
@call powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
@echo *********************************************************************
@echo Checking to see the type of image being deployed
@if "%~x1" == "E:\Imagens\PRIOLatitude3410.wim" (GOTO WIM)
@if "%~x1" == ".ffu" (GOTO FFU)
@echo *********************************************************************
@if not "%~x1" == ".ffu". if not "%~x1" == ".wim" echo Please use this script with a WIM or FFU image.
@if not "%~x1" == ".ffu". if not "%~x1" == ".wim" GOTO END
:WIM
@echo Starting WIM Deployment
@echo *********************************************************************
@echo Checking to see if the PC is booted in BIOS or UEFI mode.
wpeutil UpdateBootInfo
for /f "tokens=2* delims=	 " %%A in ('reg query HKLM\System\CurrentControlSet\Control /v PEFirmwareType') DO SET Firmware=%%B
@echo            Note: delims is a TAB followed by a space.
@if x%Firmware%==x echo ERROR: Can't figure out which firmware we're on.
@if x%Firmware%==x echo        Common fix: In the command above:
@if x%Firmware%==x echo             for /f "tokens=2* delims=	"
@if x%Firmware%==x echo        ...replace the spaces with a TAB character followed by a space.
@if x%Firmware%==x goto END
@if %Firmware%==0x1 echo The PC is booted in BIOS mode. 
@if %Firmware%==0x2 echo The PC is booted in UEFI mode. 
@echo *********************************************************************
@echo Do you want to create a Recovery partition?
@echo    (If you're going to be working with FFUs, and need 
@echo     to expand the Windows partition after applying the FFU, type N). 
@SET /P RECOVERY=(Y or N):
@if %RECOVERY%.==y. set RECOVERY=Y
@echo Formatting the primary disk...
@if %Firmware%==0x1 echo    ...using BIOS (MBR) format and partitions.
@if %Firmware%==0x2 echo    ...using UEFI (GPT) format and partitions. 
@echo CAUTION: All the data on the disk will be DELETED.
@SET /P READY=Erase all data and continue? (Y or N):
@if %READY%.==y. set READY=Y
@if not %READY%.==Y. goto END
@if %Firmware%.==0x1. if %RECOVERY%.==Y. diskpart /s CreatePartitions-BIOS.txt
@if %Firmware%.==0x1. if not %RECOVERY%.==Y. diskpart /s CreatePartitions-BIOS-FFU.txt
@if %Firmware%.==0x2. if %RECOVERY%.==Y. diskpart /s CreatePartitions-UEFI.txt
@if %Firmware%.==0x2. if not %RECOVERY%.==Y. diskpart /s CreatePartitions-UEFI-FFU.txt
@echo *********************************************************************
@echo  == Apply the image to the Windows partition ==
@SET /P COMPACTOS=Deploy as Compact OS? (Y or N):
@if %COMPACTOS%.==y. set COMPACTOS=Y
@echo Does this image include Extended Attributes?
@echo    (If you're not sure, type N).
@SET /P EA=(Y or N):
@if %EA%.==y. set EA=Y
@if %COMPACTOS%.==Y.     if %EA%.==Y.     dism /Apply-Image /ImageFile:%1 /Index:1 /ApplyDir:W:\ /Compact /EA
@if not %COMPACTOS%.==Y. if %EA%.==Y.     dism /Apply-Image /ImageFile:%1 /Index:1 /ApplyDir:W:\ /EA
@if %COMPACTOS%.==Y.     if not %EA%.==Y. dism /Apply-Image /ImageFile:%1 /Index:1 /ApplyDir:W:\ /Compact
@if not %COMPACTOS%.==Y. if not %EA%.==Y. dism /Apply-Image /ImageFile:%1 /Index:1 /ApplyDir:W:\
@echo *********************************************************************
@echo == Copy boot files to the System partition ==
W:\Windows\System32\bcdboot W:\Windows /s S:
@echo *********************************************************************
@echo   Next steps:
@echo   * Add Windows Classic apps (optional):
@echo       DISM /Apply-SiloedPackage /ImagePath:W:\ 
@echo            /PackagePath:"D:\App1.spp" /PackagePath:"D:\App2.spp"  ...
@echo.
@echo   * Configure the recovery partition with ApplyRecovery.bat
@echo.      
@echo   * Reboot:
@echo       exit
@GOTO END
:FFU
@echo Starting FFU Deployment
@echo list disk > x:\listdisks.txt
@echo exit >> x:\listdisks.txt
@diskpart /s x:\listdisks.txt
@del x:\listdisks.txt
@echo Enter the disk number of the drive where you're going to deploy your FFU (usually 0).
@SET /P DISKNUMBER=(Enter the Disk Number from above):
@echo This will remove all data from disk %DISKNUMBER%. Continue?
@SET /P ERASEALL=(Y or N):
@if %ERASEALL%.==y. set ERASEALL=Y
@if %ERASEALL%==Y DISM /apply-ffu /ImageFile=%1 /ApplyDrive:\\.\PhysicalDrive%DISKNUMBER%
@if not %ERASEALL%==Y GOTO END
@echo FFU applied. Would you like to configure the recovery partition?
@SET /P CONFIGRECOVERY=(Y or N):
@if %CONFIGRECOVERY%.==y. SET CONFIGRECOVERY=Y
@if %CONFIGRECOVERY%==Y ApplyRecovery.bat
@if not %CONFIGRECOVERY%==Y GOTO END
:END