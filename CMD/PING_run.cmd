@ECHO OFF

SET PING_PATH=%~dp0
SET PING_FILE=PING_test.cmd
REM GOOGLE, ROUTER
SET PING_LIST=8.8.8.8, 192.168.0.1

FOR %%X IN (%PING_LIST%) DO (
	START %PING_PATH%%PING_FILE% %%X
)