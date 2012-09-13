if %1!==!  goto Usage

REM First load the attributes before we go to the classes
ldifde /j . /k /i /f OpenDirectory.ldf /v /c "dc=X" %1

goto end

:Usage
@echo.
@echo This batch file loads all Apple attributes, except things like
@echo uidNumber, gidNumber, apple-homeurl.  Aside from stuff that is
@echo naturally in AD.
@echo.
@echo Usage:  Load_Apple ["Domain Path"]
@echo.
@echo For example:
@echo.
@echo Load_Apple "DC=MyDomain,DC=Com"
@echo.
@echo.
:end
