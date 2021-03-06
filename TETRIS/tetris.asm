;//////////////////////////////////////////////////////////////////////////////////
;feito por:  // made by:
;17182 guilherme rojas ribeiro
;17176 francisco luiz maian
;17189 lucas alvim romani
;para o prof Sergio na matéria 'linguagem de montagem'
;for professor Sergio on the class 'assembler language'
;todos direitos reservados -- 2019  ©
;all rights reserved -- 2019  ©
;//////////////////////////////////////////////////////////////////////////////////
      .386
      .model flat, stdcall
      option casemap :none

; #########################################################################

      include \masm32\include\windows.inc
      include \masm32\macros\macros.asm

      include \masm32\include\masm32.inc
      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc
      include \masm32\include\gdi32.inc
      include \masm32\include\msimg32.inc

      includelib \masm32\lib\masm32.lib
      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib
      includelib \masm32\lib\gdi32.lib
      includelib \masm32\lib\msimg32.lib

; #########################################################################

; MACROS:

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM
;
      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM
;
      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

; METODOS  // methods

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD

        Paint_Proc    PROTO :DWORD, :DWORD

; #########################################################################

;CONSTANTES  // constants
        sheet     equ  102

        CREF_TRANSPARENT  EQU 0FF00FFh
        CREF_TRANSPARENT2 EQU 0FF0000h

        ID_TIMER  EQU 1
        TIMER_MAX EQU 100

    .data
        displayPont   db " Pontuacao: %d", 0 ;score display
        buffer        db 255
        szDisplayName db "TETRIS",0
        CommandLine   dd 0
        hWnd          dd 0
        hInstance     dd 0
        hBmpDesenho1  dd 0

        ;variaveis para controle de peça
        ;variables for piece control
        posicaoPeca   db 0 ;sentido de rotação da peça (1-4) // piece orientarion
        tipoPeca      db 0 ;tipo de peça (1-7) // piece type
        ultimaRot     db 0 ;auxiliar para rotações // auxiliar for rotation

        ;variaveis para controle de exibição na tela
        ;variables for screen exhibition
        timerDesce    dd 0        

        ;matriz responsavel por armazenar peças já colocadas
        ;bidimensional array responsible for storing inserted pieces
        matrix        dd 10*20   dup(0)  
        matx          dd 0 ;indice X da matriz
        maty          dd 0 ;indice Y da matriz
        matval        db 1 dup (?) ;valor inserido/obtido da matriz // stored value

        ;auxiliares para conversão de posição da peça para coordenadas gráficas absolutas
        ;auxiliar for converting piece position to graphical coordinates
        aux32X dd 0
        aux32Y dd 0
        
        ;variavel para exibir a cor correta para cada peça na tela
        ;variable for showing correct color
        cor    dd 0 ;color

        ;variaveis de posição para cada peça que o usuario está controlando
        ;toda peça tetris (tetrimo) possui sempre 4 blocos
        ;poderia ser um vetor, caso quisessemos otimizar mais, porém teriamos que re-trabalhar a lógica
        ;///
        ;variables for the position of each controlled piece
        ;every tetrimo has 4 blocks always
        ;this could be an array, in the case of further optimization, but it'd be a huge re-work
        posX     dd 0
        posY     dd 0
        posX1    dd 0
        posY1    dd 0
        posX2    dd 0
        posY2    dd 0
        posX3    dd 0
        posY3    dd 0

        ;variavel de pontuacao
        ;scoring variables
        pont     dd 0
        qtdL     db 0

        ;flags de movimentação
        ;movimentation flags
        movendo  db 0 ;moving
        virando  db 0 ;rotating
        descendo db 0 ;descending
        timeOutIns db 0
        invalido db 0

        gameover db 0 ;  :(

    .data?
        ;timer
        iTimer  dd ?


; #########################################################################

    .code

start:

    invoke GetModuleHandle, NULL ; provides the instance handle
    mov hInstance, eax

    invoke LoadBitmap, hInstance, sheet
    mov hBmpDesenho1, eax


    invoke GetCommandLine        ; provides the command line address
    mov CommandLine, eax

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    
    invoke ExitProcess,eax       ; cleanup & return to operating system

; #########################################################################
;obtem um numero aleatorio de 1-7
;como nesse programa é usado para gerar o tipo da peça, o 'retorno' vai direto no tipoPeca
;///////
;get a random number between 1 and 7
;as we only use it to generate new pieces, its "return" is on the PieceType variable
getrandom proc uses eax 
  gerar:
    invoke  GetTickCount
    invoke  nseed, eax
    invoke  nrandom, 8 ;gera um numero random de 0 a 8  // generates random number between 0 and 8
    ;geramos de 0 a 8 para que os numeros que nós queremos (1-7) se tornam equiprováveis
    ;we generate between 0 and 8 so the desired values (1-7) are equally probable
    cmp eax,0
    je gerar
    cmp eax,8
    je gerar
    mov tipoPeca, al
    ret
getrandom endp

;move todos os 4 blocos para as coordenadas do bloco principal
;usado na hora de rotacionar as peças
;///////
;move all blocks to the position of the main block
;used when rotation the piece
igualaBlocos proc uses eax
  mov eax, posX
  mov posX1, eax
  mov posX2, eax
  mov posX3, eax
  mov eax, posY
  mov posY1, eax
  mov posY2, eax
  mov posY3, eax

  ret  
igualaBlocos endp

;insere a peça atual na matriz
;insert current piece on the array
insereMat proc uses eax
  ;bloco1
  mov eax, posX
  mov matx,eax
  mov eax,posY
  mov maty,eax
  call getMatriz
  .if matval != 0
    mov gameover, 1
  .endif
  mov al,tipoPeca
  mov matval,al
  call setMatriz
  ;bloco2
  mov eax, posX1
  mov matx,eax
  mov eax,posY1
  mov maty,eax
  mov al,tipoPeca
  mov matval,al
  call setMatriz
  ;bloco3
  mov eax, posX2
  mov matx,eax
  mov eax,posY2
  mov maty,eax
  mov al,tipoPeca
  mov matval,al
  call setMatriz
  ;bloco4
  mov eax, posX3
  mov matx,eax
  mov eax,posY3
  mov maty,eax
  mov al,tipoPeca
  mov matval,al
  call setMatriz
  ;verifica se completou alguma linha
  ;verify if any line should be cleared
  .if gameover==0
    call verifLinha
  .endif
  ret
insereMat endp

;loopa por todas as linhas da matriz procurando peça
;loop through each line searching for pieces
verifLinha proc
  mov qtdL, 0
  ;verifica de baixo pra cima
  ;search from bottom to top
  mov matx,0
  mov maty,20
  ;verifica linha
  ;verify line
  vfLinha:
  call getMatriz
  .if matval == 0 ;a linha n está cheia // line is not full 
    jmp mudaLinha
  .endif
  jmp mudaColuna
  ;muda indice Y 
  ;change Y index
  mudaLinha:
  .if maty == 1 ;se chegar na ultima linha // when it arrives on the last line
    jmp vfFim
  .endif
  dec maty
  mov matx,0 ;muda a linha // change line
  jmp vfLinha
  ;muda indice X
  ;change X index
  mudaColuna:
  .if matx == 9 ;se chegou no final, é pq n achou uma coluna vazia, logo, está cheia
                ;if it arrives at the end, it is because there is no empty collumn, therefore is a full line
    inc qtdL
    jmp limpaLinha
  .endif
  inc matx
  jmp vfLinha

  limpaLinha: ;clear line
  mov matx,0
  push eax
  xor eax,eax
  mov al, qtdL
  add pont, eax
  pop eax
  ;move todas as linhas acima uma para baixo
  ;move all lines bottom to top
  moveBlocoBaixo:  
  .if matx == 10
    .if maty == 1
      ;reinicia verificação
      ;restarts verification
      mov maty,20
      mov matx,0
      jmp vfLinha
    .endif
    mov matx,0
    dec maty    
    jmp moveBlocoBaixo
  .endif

  dec maty
  call getMatriz
  inc maty
  call setMatriz

  inc matx
  jmp moveBlocoBaixo

  vfFim:
  ret
verifLinha endp
;////////// tutorial matriz /////////////////////////////////////////////////
;a matriz tem tamanho 10 no X e 20 no Y     /// the array has X size 10 and Y size 20
;para usar os procedimentos, basta pensar:  /// to use the procedures, imagine:
;matriz(x,y)  --->                          
;mov matx, X    +   mov maty, Y             
;valores usam a var matval                  /// values usam the variable 'matval'
;exemplos de uso:                           /// usage:
;SET                   GET                  <--------------------------------
;mov matx,2            mov matx,2
;mov maty,4            mov maty,4
;mov matval, 80        call getMatriz
;call setMatriz        mov al, matval
;matriz[2,4]=80        matval=matriz[2,4]
;/////////////////////////////////////////////////////////////////////////////
getMatriz proc uses eax ecx
    xor eax, eax              ;limpa registrador                                          //clear eax
    mov eax, maty             ;move valor Y                                               //move Y value
    mov ecx, 10               ;move tamanho da linha                                      //move line size
    mul ecx                   ;multiplica os valores (anda pela maior dimensão do vetor)  //multiply values
    mov ecx, matx             ;move valor X                                               //move X value
    add eax, ecx              ;soma à posição final                                       //add to final position
    mov edi, OFFSET matrix    ;move pro EDI a posição da memória da matriz                //move position to EDI
    add edi, eax              ;soma pra posição da matriz a posição desejada              //add desired position
    mov al, byte ptr[edi]     ;coloca o valor da posição no al                            //insert value
    mov matval, al            ;move al pra variavel desejada                              //get from array
    ret                       ;fim
getMatriz endp
setMatriz proc uses eax ecx
    xor eax, eax              ;limpa registrador                                          //same as above
    mov eax, maty             ;move valor Y
    mov ecx, 10               ;move tamanho da linha
    mul ecx                   ;multiplica os valores (anda pela maior dimensão do vetor)
    xor ecx, ecx              ;limpa cx
    mov ecx, matx             ;move valor X
    add eax, ecx              ;soma à posição final
    mov edi, OFFSET matrix    ;move pro EDI a posição da memória da matriz
    add edi, eax              ;soma pra posição da matriz a posição desejada
    ;coloca o valor da matriz no edi                                                      //but instead, moves 'matval' to the array
    mov al, matval
    mov byte ptr[edi], al
    ret      
setMatriz endp

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

        LOCAL wc   :WNDCLASSEX
        LOCAL msg  :MSG

        LOCAL Wwd  :DWORD
        LOCAL Wht  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"Primeiro_Class"

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                               or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
        mov wc.cbClsExtra,     NULL
        mov wc.cbWndExtra,     NULL
        m2m wc.hInstance,      hInst               ; instance handle
        mov wc.hbrBackground,  COLOR_BTNFACE+1     ; system color
        mov wc.lpszMenuName,   NULL
        mov wc.lpszClassName,  offset szClassName  ; window class name
          invoke LoadIcon,hInst,400    ; icon ID   ; resource icon
        mov wc.hIcon,          eax
          invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc     ; register the window class

        ;================================
        ; Centre window at following size
        ;================================

        ;tamanho da tela
        mov Wwd, 330
        mov Wht, 608 

        invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
        invoke TopXY,Wwd,eax
        mov Wtx, eax

        invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
        invoke TopXY,Wht,eax
        mov Wty, eax

        ; ==================================
        ; Create the main application window
        ; ==================================
        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                              ADDR szClassName,
                              ADDR szDisplayName,
                              WS_SYSMENU,
                              Wtx,Wty,Wwd,Wht,
                              NULL,NULL,
                              hInst,NULL

        mov   hWnd,eax  ; copy return value into handle DWORD

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
        invoke UpdateWindow,hWnd                  ; update the display

      ;===================================
      ; Loop until PostQuitMessage is sent
      ;===================================

    StartLoop:
      invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
      cmp eax, 0                                  ; exit if GetMessage()
      je ExitLoop                                 ; returns zero
      invoke TranslateMessage, ADDR msg           ; translate it
      invoke DispatchMessage,  ADDR msg           ; send it to message proc
      jmp StartLoop
    ExitLoop:

      return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

        LOCAL Ps  :PAINTSTRUCT
        LOCAL hDC :DWORD   ;handle do dispositivo

; ########################################################################

    .if uMsg == WM_PAINT

      invoke  BeginPaint, hWin, ADDR Ps
      mov     hDC, eax
      invoke  Paint_Proc, hWin, hDC
      invoke  EndPaint, hWin, ADDR Ps

; ########################################################################

    .elseif uMsg == WM_CREATE

      invoke  SetTimer, hWin, ID_TIMER, TIMER_MAX, NULL
      mov     iTimer, eax

      ;começa com uma peça aleatoria
      ;starts with random piece
      call  getrandom

      mov   posY, 1
      mov   posX, 4

      mov timeOutIns,0

      mov descendo, 3
; ########################################################################

    .elseif uMsg == WM_KEYUP

      .if wParam == VK_UP
        mov virando,0

      .elseif wParam == VK_DOWN
        mov virando,0
        
      .elseif wParam == VK_RIGHT
        mov movendo,0      
        
        
      .elseif wParam == VK_LEFT
        mov movendo,0      

      .elseif wParam == VK_SPACE
        mov descendo, 3
        
      .endif

  ;////////////////////////////////////////
  .elseif uMsg == WM_KEYDOWN

      .if wParam == VK_DOWN
        .if virando==0
          ;rotaciona a peça
          mov   al,posicaoPeca
          mov   ultimaRot,al
          dec   posicaoPeca

          .if posicaoPeca == -1
            mov posicaoPeca, 3
          .endif
          dec timerDesce
          mov virando,1
        .endif

      .elseif wParam == VK_SPACE
        mov descendo, 1

      .elseif wParam == VK_UP      
        .if virando==0
          ;rotaciona a peça
          mov   al,posicaoPeca
          mov   ultimaRot,al
          inc   posicaoPeca

          .if posicaoPeca == 4
            mov posicaoPeca, 0
          .endif
          dec timerDesce
          mov virando,1
        .endif        
      .elseif wParam == VK_RIGHT
        .if movendo==0

          ;se o bloco está dentro da tela
          ;verify if block is on screen
          .if posX < 9 && posX1 < 9 && posX2 < 9 && posX3 < 9

            ;verifica se n tem bloco no caminho
            ;verify if there is no block on the way
            ;bloco 1
            mov eax,posX
            mov matx,eax
            inc matx
            mov eax,posY
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_right
            .endif
            ;bloco 2
            mov eax,posX1
            mov matx,eax
            inc matx
            mov eax,posY1
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_right
            .endif
            ;bloco 3
            mov eax,posX2
            mov matx,eax
            inc matx
            mov eax,posY2
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_right
            .endif
            ;bloco 4
            mov eax,posX3
            mov matx,eax
            inc matx
            mov eax,posY3
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_right
            .endif
            inc posX
            n_anda_right:
            mov movendo,1
          .endif         
        .endif        
      .elseif wParam == VK_ESCAPE
        invoke PostQuitMessage,NULL
        return 0  
      .elseif wParam == VK_LEFT
        .if movendo==0

          ;se o bloco está dentro da tela
          ;verify if block is on screen
          .if posX > 0 && posX1 > 0 && posX2 > 0 && posX3 > 0

            ;verifica se n tem bloco no caminho
            ;verify if there is no block on the way
            ;bloco 1
            mov eax,posX
            mov matx,eax
            dec matx
            mov eax,posY
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_left
            .endif
            ;bloco 2
            mov eax,posX1
            mov matx,eax
            dec matx
            mov eax,posY1
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_left
            .endif
            ;bloco 3
            mov eax,posX2
            mov matx,eax
            dec matx
            mov eax,posY2
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_left
            .endif
            ;bloco 4
            mov eax,posX3
            mov matx,eax
            dec matx
            mov eax,posY3
            mov maty,eax
            call getMatriz
            .if matval !=0
              jmp n_anda_left
            .endif
            sub posX, 1
            n_anda_left:
            mov movendo,1
          .endif           
        .endif 

      .endif

; ########################################################################

    .elseif uMsg == WM_TIMER ;TIMER
      
      invoke  KillTimer, hWin, iTimer
      inc timerDesce
      
      invoke  BeginPaint, hWin, ADDR Ps
      mov     hDC, eax
      invoke  EndPaint, hWin, ADDR Ps


      .if gameover == 1
        szText TheText,"Voce perdeu. . ."
        invoke MessageBox,hWin,ADDR TheText,ADDR szDisplayName,MB_OK
        invoke PostQuitMessage,NULL
        return 0
      .endif      

      xor eax,eax
      mov al, descendo
      cmp eax, timerDesce
      jg n_desce
      mov timerDesce, 0
      .if timeOutIns==0
        inc posY
      .endif
      n_desce:
      
      invoke  SetTimer, hWin, ID_TIMER, TIMER_MAX, NULL
      mov     iTimer, eax
      invoke  InvalidateRect, hWin, NULL, TRUE

; ########################################################################

    .elseif uMsg == WM_CLOSE

        invoke  KillTimer, hWin, iTimer

; ########################################################################

    .elseif uMsg == WM_DESTROY

        invoke PostQuitMessage,NULL
        return 0 
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam

    ret

WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD

  ; ----------------------------------------------------
  ; This procedure calculates the top X & Y co-ordinates
  ; for the CreateWindowEx call in the WinMain procedure
  ; ----------------------------------------------------

  shr sDim, 1      ; divide screen dimension by 2
  shr wDim, 1      ; divide window dimension by 2
  mov eax, wDim    ; copy window dimension into eax
  sub sDim, eax    ; sub half win dimension from half screen dimension

  return sDim

TopXY endp

; ########################################################################

Paint_Proc proc hWin:DWORD, hDC:DWORD

  LOCAL hOld:DWORD
  LOCAL memDC:DWORD

  invoke  CreateCompatibleDC, hDC
  mov     memDC, eax

  invoke SelectObject, memDC, hBmpDesenho1
  mov     hOld, eax

  invoke wsprintfA, ADDR buffer, ADDR displayPont, pont
  invoke ExtTextOutA, hDC,0, 0, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL
  
  mov invalido, 1

dnv:  ;hardcode da posição das peças
  .if posicaoPeca == 0
    jmp direita

  .elseif posicaoPeca == 1
    jmp cima

  .elseif posicaoPeca == 2
    jmp esquerda

  .elseif posicaoPeca == 3
    jmp baixo

  .endif
  
esquerda:
  call igualaBlocos
  .if tipoPeca == 1     ;J
    dec posY1
    inc posY2
    inc posY3
    dec posX3
  .elseif tipoPeca == 2 ;L
    inc posY1
    dec posY2
    dec posY3
    dec posX3
  .elseif tipoPeca == 3 ;S
    inc posY1
    dec posX2
    dec posX3
    dec posY3
  .elseif tipoPeca == 4 ;Z
    dec posY1
    dec posX2
    dec posX3
    inc posY3
  .elseif tipoPeca == 5 ;O
    inc posX1
    inc posX2
    inc posY2
    inc posY3
  .elseif tipoPeca == 6 ;T   
    dec posY1
    inc posX2
    inc posY3
  .elseif tipoPeca == 7 ;I
    inc posY1
    dec posY2
    dec posY3
    dec posY3
  .endif
 
    
  jmp fimA

baixo:
  call igualaBlocos
  .if tipoPeca == 1     ;J
   dec posX1
    inc posX2
    dec posX3
    dec posY3
  .elseif tipoPeca == 2 ;L
    dec posX1
    inc posX2
    inc posX3
    dec posY3
  .elseif tipoPeca == 3 ;S
    inc posX1
    inc posY2
    inc posY3
    dec posX3
  .elseif tipoPeca == 4 ;Z
    dec posX1
    inc posY2
    inc posY3
    inc posX3
  .elseif tipoPeca == 5 ;O
    inc posX1
    inc posX2
    inc posY2
    inc posY3
  .elseif tipoPeca == 6 ;T 
    dec posX1
    inc posX2
    inc posY3  
  .elseif tipoPeca == 7 ;I
    inc posX1
    dec posX2
    dec posX3
    dec posX3
  .endif

  jmp fimA

cima:
  call igualaBlocos
  .if tipoPeca == 1     ;J
    dec posX1
    inc posX2
    inc posX3
    inc posY3
  .elseif tipoPeca == 2 ;L
    inc posX1
    dec posX2
    dec posX3
    inc posY3
  .elseif tipoPeca == 3 ;S
    dec posX1
    dec posY2
    dec posY3
    inc posX3
  .elseif tipoPeca == 4 ;Z
    inc posX1
    dec posY2
    dec posY3
    dec posX3
  .elseif tipoPeca == 5 ;O
    inc posX1
    inc posX2
    inc posY2
    inc posY3
  .elseif tipoPeca == 6 ;T  
    dec posX1
    dec posY2
    inc posX3 
  .elseif tipoPeca == 7 ;I
    dec posX1
    inc posX2
    inc posX3
    inc posX3
  .endif

  jmp fimA

direita:
  call igualaBlocos
  .if tipoPeca == 1     ;J
    dec posY1
    inc posY2
    dec posY3
    inc posX3
  .elseif tipoPeca == 2 ;L
    dec posY1
    inc posY2
    inc posY3
    inc posX3
  .elseif tipoPeca == 3 ;S
    dec posY1
    inc posX2
    inc posX3
    inc posY3
  .elseif tipoPeca == 4 ;Z
    inc posY1
    inc posX2
    inc posX3
    dec posY3
  .elseif tipoPeca == 5 ;O
    inc posX1
    inc posX2
    inc posY2
    inc posY3
  .elseif tipoPeca == 6 ;T 
    dec posY1
    dec posX2
    inc posY3
  .elseif tipoPeca == 7 ;I
    dec posY1
    inc posY2
    inc posY3
    inc posY3
  .endif
  
fimA: 

  ;verifica se o bloco saiu da tela
  ;verify if block is off screen
  ;          VVV se está nessas condições, é pq a peça está nos negativos  (-1, -2,...) VVV
  ;          VVV if it is in these conditions, it is on negative positions (-1, -2,...) VVV
  .if posX >= 1989210000 || posX1 >= 1989210000 || posX2 >= 1989210000 || posX3 >= 1989210000
    inc posX
    jmp dnv
  .endif
  .if posX > 9 || posX1 > 9 || posX2 > 9 || posX3 > 9
    dec posX
    jmp dnv
  .endif
  ;verifica se entrou em um bloco da matriz
  ;verify if it entered a inserted piece
  mov eax,posX
  mov matx,eax
  mov eax,posY
  mov maty,eax
  call getMatriz
  .if matval !=0
    .if invalido == 1
      dec posY
      mov invalido, 0
      jmp dnv
    .else     
      mov al,ultimaRot
      mov posicaoPeca,al
      mov invalido, 1
      jmp dnv
    .endif
  .endif
  ;bloco 2
  mov eax,posX1
  mov matx,eax
  mov eax,posY1
  mov maty,eax
  call getMatriz
  .if matval !=0
    .if invalido == 1
      dec posY
      mov invalido, 0
      jmp dnv
    .else     
      mov al,ultimaRot
      mov posicaoPeca,al
      mov invalido, 1
      jmp dnv
    .endif
  .endif
  ;bloco 3
  mov eax,posX2
  mov matx,eax
  mov eax,posY2
  mov maty,eax
  call getMatriz
  .if matval !=0
    .if invalido == 1
      dec posY
      mov invalido, 0
      jmp dnv
    .else     
      mov al,ultimaRot
      mov posicaoPeca,al
      mov invalido, 1
      jmp dnv
    .endif
  .endif
  ;bloco 4
  mov eax,posX3
  mov matx,eax
  mov eax,posY3
  mov maty,eax
  call getMatriz
  .if matval !=0
    .if invalido == 1
      dec posY
      mov invalido, 0
      jmp dnv
    .else     
      mov al,ultimaRot
      mov posicaoPeca,al
      mov invalido, 1
      jmp dnv
    .endif
  .endif
  
  ;desenha todos os blocos que estão na matriz
  ;draw all inserted pieces from array
  mov matx,0
  mov maty,0
  desenhaMat:
  call getMatriz
  .if matval != 0     
    ;desenha bloco
    mov ecx, 32
    mov eax, matx
    mul ecx
    mov aux32X, eax
    mov eax, maty
    mul ecx
    mov aux32Y, eax       

    push eax
    push ebx
    push ecx
    push edx
    xor eax,eax
    mov al, matval
    dec eax
    mul ecx
    mov cor, eax
    invoke TransparentBlt, hDC, aux32X, aux32Y, 32, 32, memDC, 0, cor, 32, 32, TRUE
    pop edx
    pop ecx
    pop ebx
    pop eax
  .endif

  .if maty==17
    .if matx==9
      jmp dpsDesenhaMat
    .endif
    mov maty, 0
    inc matx
    jmp desenhaMat
  .endif
  inc maty
  jmp desenhaMat  
  dpsDesenhaMat:
  
  ;desenha os blocos da peça atual
  ;draw current piece's blocks
  ;bloco 1
  mov ecx, 32
  xor eax,eax
  mov al, tipoPeca
  dec eax
  mul ecx
  mov cor, eax
  mov eax, posX
  mul ecx
  mov aux32X, eax
  mov eax, posY
  mul ecx
  mov aux32Y, eax
  invoke TransparentBlt, hDC, aux32X, aux32Y, 32, 32, memDC, 0, cor, 32, 32, TRUE
  ;bloco 2
  mov ecx, 32
  mov eax, posX1
  mul ecx
  mov aux32X, eax
  mov eax, posY1
  mul ecx
  mov aux32Y, eax
  invoke TransparentBlt, hDC, aux32X, aux32Y, 32, 32, memDC, 0, cor, 32, 32, TRUE
  ;bloco 3
  mov ecx, 32
  mov eax, posX2
  mul ecx
  mov aux32X, eax
  mov eax, posY2
  mul ecx
  mov aux32Y, eax
  invoke TransparentBlt, hDC, aux32X, aux32Y, 32, 32, memDC, 0, cor, 32, 32, TRUE
  ;bloco 4
  mov ecx, 32
  mov eax, posX3
  mul ecx
  mov aux32X, eax
  mov eax, posY3
  mul ecx
  mov aux32Y, eax
  invoke TransparentBlt, hDC, aux32X, aux32Y, 32, 32, memDC, 0, cor, 32, 32, TRUE
  ;////////

  ;verifica se tem algo na matriz
  ;verify if there is something on the array
    ;bloco1
    mov eax,posX
    mov matx,eax
    mov eax,posY
    mov maty,eax
    call getMatriz
    .if matval!=0
      mov gameover,1
      jmp dpsInsere
    .endif
    inc maty
    call getMatriz
    .if matval!=0
      jmp insere
    .endif
    ;bloco2
    mov eax,posX1
    mov matx,eax
    mov eax,posY1
    mov maty,eax
    call getMatriz
    .if matval!=0
      mov gameover,1
      jmp dpsInsere
    .endif
    inc maty
    call getMatriz
    .if matval!=0
      jmp insere
    .endif
    ;bloco3
    mov eax,posX2
    mov matx,eax
    mov eax,posY2
    mov maty,eax
    call getMatriz
    .if matval!=0
      mov gameover,1
      jmp dpsInsere
    .endif
    inc maty
    call getMatriz
    .if matval!=0
      jmp insere
    .endif
    ;bloco4
    mov eax,posX3
    mov matx,eax
    mov eax,posY3
    mov maty,eax
    call getMatriz
    .if matval!=0
      mov gameover,1
      jmp dpsInsere
    .endif
    inc maty
    call getMatriz
    .if matval!=0
      jmp insere
    .endif

    ;verifica se chegou no final da tela
    ;verify if it is at the bottom of the screen
    .if posY >= 17 || posY1 >= 17 || posY2 >= 17 || posY3 >=17
      jmp insere
    .endif

    mov timeOutIns,0
    jmp dpsInsere

    ;insere na matriz
    ;insert on array
    insere:
      inc timeOutIns

      .if timeOutIns == 3
        ;verifica se há blocos muito acima
        ;if there are blocks way up high
        call  insereMat

        .if posY < 4 ||  posY1 < 4 ||  posY2 < 4 ||  posY3 < 4
          ;perde // loses
          mov gameover,1
        .else      
          mov   posY, 1     
          mov   posX, 4
          call  getrandom
        .endif
      .endif    

    dpsInsere:


  invoke SelectObject, hDC, hOld

  invoke DeleteDC, memDC

  return 0

Paint_Proc endp

end start