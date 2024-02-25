.386
.model flat, stdcall
option casemap :none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32rt.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib

WinMain PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :dword
WndProc PROTO :HWND, :UINT, :WPARAM, :LPARAM

CTEXT MACRO y:VARARG
      LOCAL sym, dummy
      dummy EQU $   ;; MASM error fix
      CONST SEGMENT
        IFIDNI <y>,<>
          sym db 0
        ELSE
          sym db y,0
        ENDIF
      CONST ends
      EXITM <OFFSET sym>
    ENDM

.data
    ; <------------------- KOMUNIKATY B£ÊDÓW ------------------->
    window_register_fail db  "B³¹d rejestracji okna",0
    tit_error            db  "B³¹d",0
    
    open_error           db  "Nie mo¿na otworzyæ pliku",0
    size_error           db  "Nieprawid³owy rozmiar pliku",0
    mem_error            db  "Za ma³o pamiêci",0
    read_error           db  "B³¹d czytania z pliku",0
    write_error          db  "B³¹d zapisu do pliku",0

    ; <------------------------ OBIEKTY ------------------------>
    NazwaKlasy db "Klasa Okienka",0
    tit db "Notatnik",0
    
    button db "BUTTON",0
    
    button_open_text db "Otwórz",0
    ID_BUTTON_OPEN BYTE 101
    
    button_save_text db "Zapisz",0
    ID_BUTTON_SAVE BYTE 102
    
    button_close_text db "Zamknij",0
    ID_BUTTON_CLOSE BYTE 103

    area_text db "EDIT",0
    ID_AREA_TEXT BYTE 104
    
    hInstancee dd ?
    lpCmdLinee dd ?
    
    path BYTE "A:\masm32"
    hwnd_text HWND 0
    ; <--------------------------------------------------------->

.code

start:
    
    invoke GetModuleHandle, NULL
    mov hInstancee, eax
    invoke GetCommandLine
    mov lpCmdLinee, eax
    invoke WinMain, hInstancee, NULL, lpCmdLinee, SW_SHOWDEFAULT
    invoke ExitProcess, eax
    
    ;___________________________________ G£ÓWNA PROCEDURA ____________________________________

    WinMain proc hInst :HINSTANCE, hPrevInstance :HINSTANCE, lpCmdLine :LPSTR, nCmdShow :dword

        local hwnd          :HWND
        local button_open   :HWND
        local button_save   :HWND
        local button_close  :HWND
        local Komunikat     :MSG
        local hFont         :HFONT
        local wc            :WNDCLASSEX
        
        ;==================================== WYPE£NIANIE KLASY OKNA ====================================
        mov wc.cbSize, sizeof WNDCLASSEX
        mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc, WndProc
        mov wc.cbClsExtra, NULL
        mov wc.cbWndExtra, NULL
        push hInst
        pop wc.hInstance
        invoke LoadIcon, hInst, IDI_APPLICATION
        mov wc.hIcon, eax
        mov wc.hIconSm, eax
        invoke LoadCursor, hInst, IDC_ARROW
        mov wc.hCursor, eax
        mov wc.hbrBackground, COLOR_BTNFACE + 1
        mov wc.lpszMenuName, NULL
        mov wc.lpszClassName, offset NazwaKlasy

        ;==================================== REJESTROWANIE KLASY OKNA ====================================
        invoke RegisterClassEx, addr wc
        .IF EAX==FALSE
            invoke MessageBox, NULL, window_register_fail, tit_error, MB_ICONEXCLAMATION or MB_OK
            mov eax, 1
            ret
        .ENDIF

        ;========================================= TWORZENIE OKNA =========================================
        invoke CreateWindowEx, WS_EX_APPWINDOW, addr NazwaKlasy, addr tit, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 650, 350, NULL, NULL, hInst, NULL
        mov hwnd, eax

        .IF EAX==NULL
            invoke MessageBox, NULL, window_register_fail, tit_error, MB_ICONEXCLAMATION or MB_OK
            mov eax, 1
            ret
        .ENDIF

        invoke CreateWindowEx, WS_EX_APPWINDOW, addr button, addr button_open_text,  WS_CHILD or WS_VISIBLE, 20, 20, 180, 30, hwnd, ID_BUTTON_OPEN, hInst, NULL
        mov button_open, eax
        invoke CreateWindowEx, WS_EX_APPWINDOW, addr button, addr button_save_text,  WS_CHILD or WS_VISIBLE, 230, 20, 180, 30, hwnd, ID_BUTTON_SAVE, hInst, NULL
        mov button_save, eax
        invoke CreateWindowEx, WS_EX_APPWINDOW, addr button, addr button_close_text, WS_CHILD or WS_VISIBLE, 440, 20, 180, 30, hwnd, ID_BUTTON_CLOSE, hInst, NULL
        mov button_close, eax
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr area_text, NULL, WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or ES_MULTILINE or ES_AUTOVSCROLL, 20, 80, 600, 200, hwnd, ID_AREA_TEXT, hInst, NULL
        mov hwnd_text, eax
        
        ;============================================ POKAZ OKNO =========================================
        invoke ShowWindow, hwnd, nCmdShow
        invoke UpdateWindow, hwnd

        ;========================================= PÊTLA KOMUNIKATÓW =====================================

        MessageLoop:
        
            invoke GetMessage, addr Komunikat, 0, 0, 0
      
            .IF EAX==TRUE
                invoke TranslateMessage, addr Komunikat
                invoke DispatchMessage, addr Komunikat
                jmp MessageLoop
            .ENDIF
            
         mov eax, Komunikat.wParam
         ret

    WinMain endp
    
    ;_______________________________ OBS£UGA ZDARZEÑ _______________________________
    
    WndProc proc hwnd :HWND, msg :UINT, wParam :WPARAM, lParam :LPARAM
    
        local ofn                 :OPENFILENAME
        local filePath[MAX_PATH]  :BYTE
        local hFile               :HANDLE
        local Bufor               :LPSTR
        local dwRozmiar           :DWORD
        local dwPrzeczyt          :DWORD
        local dwZapisane          :DWORD
        local hPlik               :HANDLE

        ;==================================== WYPE£NIANIE STRUKTURY ====================================
        
        invoke RtlZeroMemory, addr ofn, sizeof OPENFILENAME
        invoke RtlZeroMemory, addr filePath, MAX_PATH
        mov ofn.lStructSize, sizeof OPENFILENAME
        m2m ofn.hwndOwner,hwnd
        mov ofn.lpstrFilter, CTEXT("All Files (*.txt*)",0,"*txt",0,0)
        mov ofn.nFilterIndex, 1
        lea eax, [filePath]
        mov ofn.lpstrFile, eax
        mov ofn.nMaxFile, MAX_PATH
        mov ofn.Flags, OFN_EXPLORER or OFN_PATHMUSTEXIST or OFN_FILEMUSTEXIST
        ;===============================================================================================
        
        .IF msg==WM_CLOSE
            invoke DestroyWindow, hwnd
            mov eax, 0
            ret
            
        .ELSEIF msg==WM_DESTROY
            invoke PostQuitMessage, 0
            mov eax, 0
            ret

        ;==================================== ODCZYT Z PLIKU ====================================   
        .ELSEIF wParam==101
            invoke GetOpenFileName, addr ofn
            
            invoke CreateFile, ofn.lpstrFile, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL
            mov hPlik, eax
            .IF hPlik==INVALID_HANDLE_VALUE
                invoke MessageBox, 0, addr open_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke GetFileSize, hPlik, NULL
            mov dwRozmiar, eax
            
            .IF dwRozmiar==INVALID_FILE_SIZE
                invoke MessageBox, 0, addr size_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke GlobalAlloc, GPTR, dwRozmiar
            mov Bufor, eax
            .IF Bufor==NULL
                invoke MessageBox, 0, addr mem_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke ReadFile, hPlik, Bufor, dwRozmiar, addr dwPrzeczyt, NULL
            .IF EAX==FALSE
                invoke MessageBox, 0, addr read_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke SetWindowText, hwnd_text, Bufor
            invoke GlobalFree, Bufor
            invoke CloseHandle, hPlik
            ret

        ;==================================== ZAPIS DO PLIKU ====================================    
        .ELSEIF wParam==102
            invoke GetOpenFileName, addr ofn

            invoke CreateFile, ofn.lpstrFile, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL
            mov hPlik, eax
            .IF hPlik==INVALID_HANDLE_VALUE
                invoke MessageBox, 0, addr open_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke GetWindowTextLength, hwnd_text
            mov dwRozmiar, eax
            add dwRozmiar, 1
            .IF dwRozmiar==0
                invoke MessageBox, 0, addr size_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke GlobalAlloc, GPTR, dwRozmiar
            mov Bufor, eax
            .IF Bufor==NULL
                invoke MessageBox, 0, addr mem_error, addr tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke GetWindowText, hwnd_text, Bufor, dwRozmiar
        
            invoke WriteFile, hPlik, Bufor, dwRozmiar, addr dwZapisane, NULL
            .IF EAX==FALSE
                invoke MessageBox, 0, write_error, tit_error, MB_ICONWARNING
                invoke CloseHandle, hPlik
                ret
            .ENDIF
            
            invoke GlobalFree, Bufor
            invoke CloseHandle, hPlik
            ret
        ;===============================================================================================
            
        .ELSEIF wParam==103
            invoke DestroyWindow, hwnd
            mov eax, 0
            ret
            
        .ELSE
            invoke DefWindowProc, hwnd, msg, wParam, lParam
            ret
            
        .ENDIF

        invoke DefWindowProc, hwnd, msg, wParam, lParam

    WndProc endp
        
end start