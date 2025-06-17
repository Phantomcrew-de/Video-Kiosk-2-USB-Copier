@echo on
:loop
(
    for %%f in (*.mp4 *.mov *.mkv) do echo %%~nxf
) > videos.txt
timeout /t 5 /nobreak >nul
goto loop
