@ECHO OFF

IF "%1" EQU "" GOTO USAGE
IF "%2" NEQ "" (
				IF "%2" NEQ "--no-copyright" GOTO USAGE
			)
GOTO BUILD

 :USAGE
ECHO USAGE: build.js ^<release_version^> [--no-copyright]
GOTO END

:BUILD
node build.js %1 %2
GOTO END

:END