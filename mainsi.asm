;---------------------------------------;
;SPACE INVADERS ASSEMBLY PROJECT        ;
;Author : Oren Kessler                  ;
;Date of Submition : 11/05/20           ;
;---------------------------------------;
IDEAL
MODEL small
STACK 100h

DATASEG
;-------------------------------------------------------------------------------------------------------------------------------;
;                                                                                                                               ;
;Space_Invader_Variables                                                                                                        ;
	xVal_Ship dw 140 ; ship value x / Changes according to player's input.
	yVal_Ship dw 130; ship value y / Currently constant.

	xVal_Pointer dw 78 ; pointer x position
	yVal_Pointer dw 112 ; pointer y position
	menu_ptr db 1 ; Which button in the menu is currently "focused", for keyboard use.

	alien_array dw 2*16 dup (0) ; currently 16 aliens on the screen each alien contains 2 attributes : x and y
	alien_loop_save dw 0 ; used to store cx value because it is being modified in other functions.
	aliens_count dw 16 ; amount of aliens in total / used in the draw function and other related functions.
	alien_offset_counter dw 0 ; used to store si because of si, di and bx being modified in OpenIMG.
	alien_proj_array dw 2*16 dup (0) ; x,y values for each alien projectile.
	allow_draw db 0 ; are the projectiles allowed to be drawn?
	save_proj_si dw 0 ; because of the function OpenIMG si value gets changed.
	save_proj_cx dw 0

	xVal_projectile dw 0 ; projectile x position
	yVal_projectile dw 0 ; projectile y position
	allow_shoot db 1 ; user allowed to fire a projectile
	allow_move db 0 ; is the projectile allowed to move?

	filehandle dw ? ; Holds the file reference.
	Header db 54 dup (0) ; Holds the header of the image.
	Palette db 256*4 dup (0) ; Holds the content of the bmp color palette.
	ScrLine db 320 dup (0) ; Holds the content of a bmp image line.
	ErrorMsg db 'Error, image non existent!', 13, 10 ,'$'

	menubmp db 'image/screen/menu/menu.bmp',0 ; File directory of the main menu image.
	pointerbmp db 'image/misc/point.bmp',0 ; File directory of the pointer image.
	losescreenbmp db 'image/screen/cond/lose.bmp',0 ; File directory of the lose screen image.
	winscreenbmp db 'image/screen/cond/win.bmp',0 ; File directory of the win screen image.
	shipbmp db 'image/main/ship/shipR1.bmp',0 ; File directory of the rocket ship image.
	resetbmp db 'image/main/screen/reset.bmp',0 ; File directory of the black screen image.
	alienbmp db 'image/main/alien/alien.bmp',0 ; File directory of the alien image.
	projectilebmp db 'image/main/laser/laserR.bmp',0 ; File directory of the projectile image.
	alienprojectilebmp db 'image/main/laser/laserG.bmp',0 ; File directory of the alien projectile image.
	helpmenubmp db 'image/screen/menu/help.bmp',0 ; File directory of the help menu image.
	optionsmenubmp db 'image/screen/menu/options.bmp',0 ; File directory of the options menu image.

	ship_offset_withdir dw 20 ; <<-CHANGE IN CASE OF DIRECTORY NAME CHANGE.
	;highscore_menu_dir db 'score.dat',0

	ScrLine_txt db 10 dup (0),'$' ; Holds the content of a txt line. [ 10 characters per line max ! ]
	ErrorMsg_Txt db 'Error, file non existent!', 13, 10 ,'$'

	user_win db 1 ; if stays in 1 this means the player won.
	user_lose db 0 ;  if stays in 1 this means the player lost.

	saveSeconds db 0 ; saves the value from dh to a variable to prevent the function from calling multiple times in a second.
	saveKey db 0 ; Saves the last key that was pressed and its state                                                                                                     ;
;                                                                                                             				    ;
;-------------------------------------------------------------------------------------------------------------------------------;
CODESEG

;---------------------------------------------;
; Space Invaders Procedures                   ;
;---------------------------------------------;

;-------------------;
; MainMenu Section: ;
;-------------------;

;----------------------;
; Image Handling:      ;
;----------------------;
	proc OpenIMG
		;Recieves 5 parameters [filename,x,y,width,height]
		;Copies image data from a file to a specific location in the vga segment
		; Open file / using file handling
		push bp
		mov bp,sp
		filename equ [bp + 12]
		mov dx,filename
		mov ah, 3Dh
		xor al, al
		int 21h
		jc openerror
		mov [filehandle], ax
		jmp fileheader
 
		openerror :
			mov dx, offset ErrorMsg
			mov ah, 9h
			int 21h
			ret 10
	
		; Read BMP file header, 54 bytes
		Fileheader:
		mov ah,3fh
		mov bx, [filehandle]
		mov cx,54
		mov dx,offset Header
		int 21h

		; Read BMP file color palette, 256 colors * 4 bytes (400h)
		mov ah,3fh
		mov cx,400h
		mov dx,offset Palette
		int 21h

		; Copy the colors palette to the video memory
		; The number of the first color should be sent to port 3C8h
		; The palette is sent to port 3C9h
		mov si,offset Palette
		mov cx,256
		mov dx,3C8h
		mov al,0
		; Copy starting color to port 3C8h
		out dx,al
		; Copy palette itself to port 3C9h
		inc dx
		PalLoop1:
			; Note: Colors in a BMP file are saved as BGR values rather than RGB .
			mov al,[si+2] ; Get red value .
			shr al,1
			shr al,1; Max. is 255, but video palette maximal
			; value is 63. Therefore dividing by 4.
			out dx,al ; Send it .
			mov al,[si+1] ; Get green value .
			shr al,1
			shr al,1
			out dx,al ; Send it .
			mov al,[si] ; Get blue value .
			shr al,1
			shr al,1
			out dx,al ; Send it .
			add si,4 ; Point to next color .
			; (There is a null chr. after every color.)

			loop PalLoop1
	
		; recieves 4 parameters  - > x pos , y pos, width,height
		; BMP graphics are saved upside-down .
		; Read the graphic line by line (200 lines in VGA format),
		; displaying the lines from bottom to top.
		mov ax, 0A000h
		mov es, ax

		yVal equ [bp + 4]
		xVal equ [bp + 6]
		yPos equ [bp + 8]
		xPos equ [bp + 10]

		mov cx,yVal
		PrintBMPLoop1:
			;combine result of mul with ax and cx to get the correct position on the screen
			
			push cx
			mov ax,320
			mul cx

			mov di,ax

			;Calculation of X position:
			add di,xPos

			; Calculation of Y position:
			mov ax,320
			
			mul yPos
			add di,ax

			; Read one line
			mov ah,3fh
			mov cx,xVal ;The amount of width of the image in the file handling
			mov dx,offset ScrLine
			int 21h
			; Copy one line into video memory
			cld ; Clear direction flag, for movsb
			mov cx,xVal
			mov si,offset ScrLine

			rep movsb ; Copy line to the screen
			 ;rep movsb is same as the following code :
			 ;mov es:di, ds:si
			 ;inc si
			 ;inc di
			 ;dec cx
			 ;loop until cx=0
			pop cx
			loop PrintBMPLoop1
			pop bp
	
		mov ah,3Eh
		mov bx, [filehandle]
		int 21h
		ret 12
		endp OpenIMG
;-------------------------------------;
; Open Dynamic Text File And read it: ;
;-------------------------------------;
	;proc OpenTxtFile 
		; a Function which opens a file and changes the value of filehandletxt
		;Recieves 1 parameter [filename]
		;Copies txt data from a file to txt buffer
		; Open file / using file handling
		; push bp
		; mov bp,sp
		; filename_txt equ [bp + 4]
		; mov dx,filename_txt
		; mov ah, 3Dh
		; xor al, al
		; int 21h
		; jc openerror2
		; mov [filehandle], ax
 	 	;jmp exit_func_file
		
		; openerror2 :
		; 	mov dx, offset ErrorMsg_Txt
		; 	mov ah, 9h
		; 	int 21h
		; 	ret 2
		
		; Exit_func_file:
		; pop bp
		; ret 2
		; endp OpenTxtFile

	;proc ReadText_HighScore 
		; A function that reads the highscore from the .dat file.
		; Read_file:
		; mov cx,10 ; amount of characters to store in the buffer.
		; mov ah,3Fh
		; mov bx,[filehandle]
		; mov dx,offset ScrLine_txt
		; int 21h
		
		; ret
		; endp ReadText_HighScore

	;proc CloseFile
		;	mov ah,3Eh
		;	mov bx, [filehandle]
		;	int 21h
		;	ret
		;	endp CloseFile
;------------------------;
; General Menus Pointer: ;
;------------------------;
	proc init_pointer
		;A function to reset pointer location every time a menu redirection occurs.
		mov [menu_ptr],1
		ret
		endp init_pointer
	
	proc pointermov_mainmenu 
			; procedure for moving the pointer img in the main menu
 			; Calculates where the pointer should be on the screen in the menu section.
			; -------------------------------------------------------------------------;
			; Pointer Movement Section / code taken from generic procedure imgmovement ;
			; -------------------------------------------------------------------------;
			in al, 64h ; Read keyboard status port
			cmp al, 10b ; Data in buffer ?
			je Button_pos_main_mainmenu

			in al,60h

				cmp al,[saveKey] ; check if the key pressed is the current key.
				je Move_up_mainmenu; go to the movement section, else there is a new key.
				mov [saveKey],al ; save the new key
				
				;and al,80h
				;jz move_up_menu
				;jmp button_pos_main ; no need to change values since the button is not pressed.

				Move_up_mainmenu:
					cmp al,48h
					je mvup_exec_mainmenu
					cmp al,11h
					jne move_down_mainmenu

				Mvup_exec_mainmenu:
					dec [menu_ptr]
					jmp button_pos_main_mainmenu
					
				Move_down_mainmenu:
					cmp al,50h
					je mvdown_exec_mainmenu
					cmp al,1Fh
					je mvdown_exec_mainmenu
					jmp button_pos_main_mainmenu

				Mvdown_exec_mainmenu:
					inc [menu_ptr]
					jmp button_pos_main_mainmenu

			;--------------------------------------;
			; Calculating Pointer Position Section ;
			;--------------------------------------;
			Button_pos_main_mainmenu:
			cmp [menu_ptr],4 ; Check if the pointer is out of bound
			jae calculate_pos_1_mainmenu ; pointer is out of bound, reset it.

			cmp [menu_ptr],0 ; Check if the pointer is out of bound
			je calculate_pos_3_mainmenu ; pointer is out of bound, move it to the last location.

			cmp [menu_ptr],1  
			jz calculate_pos_1_mainmenu

			cmp [menu_ptr],2  
			jz calculate_pos_2_mainmenu

			cmp [menu_ptr],3  
			jz calculate_pos_3_mainmenu

			;cmp [menu_ptr],4  
			;jz calculate_pos_4_mainmenu



			Calculate_pos_1_mainmenu:
			mov [menu_ptr],1 ; out of bounds fix

			;Change relative X:
			mov [xVal_Pointer],65
			;Change relative Y:
			mov [yVal_Pointer],112
			jmp exit_func2 ; finished calculating, draw the pointer.

			Calculate_pos_2_mainmenu:
			;Change relative X:
			mov [xVal_Pointer],96
			;Change relative Y:
			mov [yVal_Pointer],140
			jmp exit_func2 ; finished calculating, draw the pointer.
			Calculate_pos_3_mainmenu: ; changed from highscore to help x value.
			mov [menu_ptr],3 ; out of bounds fix
			;Change relative X:
			mov [xVal_Pointer],112
			;Change relative Y:
			mov [yVal_Pointer],156
			jmp exit_func2 ; finished calculating, draw the pointer.
			; Calculate_pos_4_mainmenu:
			; mov [menu_ptr],4 ; out of bounds fix
			; ;Change relative X:
			; mov [xVal_Pointer],122
			; ;Change relative Y:
			; mov [yVal_Pointer],174

            Exit_func2:
            ret
            endp pointermov_mainmenu

    proc pointermov_optionsmenu 
    	; procedure for moving the pointer img in the main menu
		; Calculates where the pointer should be on the screen in the menu section.
		; -------------------------------------------------------------------------;
		; Pointer Movement Section / code taken from generic procedure imgmovement ;
		; -------------------------------------------------------------------------;
		in al, 64h ; Read keyboard status port
		cmp al, 10b ; Data in buffer ?
		je Button_pos_main_optionsmenu
		in al,60h
		cmp al,[saveKey] ; check if the key pressed is the current key.
		je Move_up_optionsmenu; go to the movement section, else there is a new key.
		mov [saveKey],al ; save the new key
		
		;and al,80h
		;jz move_up_menu
		;jmp button_pos_main ; no need to change values since the button is not pressed.

		Move_up_optionsmenu:
			cmp al,48h
			je mvup_exec_optionsmenu
			cmp al,11h
			jne move_down_optionsmenu

		Mvup_exec_optionsmenu:
			dec [menu_ptr]
			jmp button_pos_main_optionsmenu
			
		Move_down_optionsmenu:
			cmp al,50h
			je mvdown_exec_optionsmenu
			cmp al,1Fh
			je mvdown_exec_optionsmenu
			jmp Move_left_optionsmenu

		Mvdown_exec_optionsmenu:
			inc [menu_ptr]
			jmp button_pos_main_optionsmenu
		
		Move_left_optionsmenu:
			cmp [menu_ptr],5
			jb Move_right_optionsmenu
			cmp [menu_ptr],8
			ja Move_right_optionsmenu

				cmp al,1Eh
				je Mvleft_exec_optionsmenu
				cmp al,4Bh
				jne Move_right_optionsmenu

		Mvleft_exec_optionsmenu:
			sub [menu_ptr],4
			jmp button_pos_main_optionsmenu
			
		Move_right_optionsmenu:
			cmp [menu_ptr],4
			ja button_pos_main_optionsmenu
			cmp [menu_ptr],1
			jb button_pos_main_optionsmenu

				cmp al,20h
				je mvright_exec_optionsmenu
				cmp al,4Dh
				jne button_pos_main_optionsmenu 

		Mvright_exec_optionsmenu:
			add [menu_ptr],4
			jmp button_pos_main_optionsmenu


		;--------------------------------------;
		; Calculating Pointer Position Section ;
		;--------------------------------------;
		button_pos_main_optionsmenu:
		cmp [menu_ptr],9 ; Check if the pointer is out of bound
		jae First_Column ; pointer is out of bound, reset it.

		cmp [menu_ptr],0 ; Check if the pointer is out of bound
		je Second_Column ; pointer is out of bound, move it to the last location in the columns.


		First_Column: ; defines x values for each of its contents.
		mov [xVal_Pointer],60
		Calculate_pos_1_optionsmenu:
		cmp [menu_ptr],9
		jae pos_1_calculation_optionsmenu
		cmp [menu_ptr],1
		jne Calculate_pos_2_optionsmenu
		
		pos_1_calculation_optionsmenu:
		mov [menu_ptr],1 ; out of bounds fix
		;Change relative Y:
		mov [yVal_Pointer],76
		jmp exit_func5 ; finished calculating, draw the pointer.

		Calculate_pos_2_optionsmenu:
		cmp [menu_ptr],2
		jne Calculate_pos_3_optionsmenu
		;Change relative Y:
		mov [yVal_Pointer],91
		jmp exit_func5 ; finished calculating, draw the pointer.
		Calculate_pos_3_optionsmenu:
		cmp [menu_ptr],3
		jne Calculate_pos_4_optionsmenu
		;Change relative Y:
		mov [yVal_Pointer],104
		jmp exit_func5 ; finished calculating, draw the pointer.
		
		Calculate_pos_4_optionsmenu:
		cmp [menu_ptr],4
		jne Second_Column
		;Change relative Y:
		mov [yVal_Pointer],119
		jmp exit_func5 ; finished calculating, draw the pointer.

		Second_Column: ; defines x values for each of its contents.
		mov [xVal_Pointer],177
		Calculate_pos_5_optionsmenu:
		cmp [menu_ptr],5
		jne Calculate_pos_6_optionsmenu
		;Change relative Y:
		mov [yVal_Pointer],76
		jmp exit_func5 ; finished calculating, draw the pointer.

		Calculate_pos_6_optionsmenu:
		cmp [menu_ptr],6
		jne Calculate_pos_7_optionsmenu
		;Change relative Y:
		mov [yVal_Pointer],91
		jmp exit_func5 ; finished calculating, draw the pointer.
		
		Calculate_pos_7_optionsmenu:
		cmp [menu_ptr],7
		jne Calculate_pos_8_optionsmenu
		;Change relative Y:
		mov [yVal_Pointer],104
		jmp exit_func5 ; finished calculating, draw the pointer.
		
		Calculate_pos_8_optionsmenu:
		cmp [menu_ptr],0
		je pos_8_calculation_optionsmenu
		cmp [menu_ptr],8
		jne exit_func5

		pos_8_calculation_optionsmenu:
		mov [menu_ptr],8 ; out of bounds fix
		;Change relative Y:
		mov [yVal_Pointer],119
		jmp exit_func5 ; finished calculating, draw the pointer.
        
        Exit_func5:
    		ret
		endp pointermov_optionsmenu
;------------------------------;
; Main Game Functions Section: ;
;------------------------------;
	proc ship_texutre
		; a simple function which checks if the player pressed enter in the options menu and changes the texture according-
		; to the pointer position on screen.
		mov si,[ship_offset_withdir]
		First_Column_Textures:
		cmp [menu_ptr],5
		jae Second_Column_Textures

		Blue_Ship_Texture:
		cmp [menu_ptr],1
		jne Brown_Ship_Texture
		mov [shipbmp + si],"B"
		mov [shipbmp + si + 1],"1"

		jmp exit_func6
		Brown_Ship_Texture:
		cmp [menu_ptr],2
		jne Gray_Ship_Texture
		mov [shipbmp + si],"B"
		mov [shipbmp + si + 1],"2"

		jmp exit_func6
		Gray_Ship_Texture:
		cmp [menu_ptr],3
		jne Green_Ship_Texture
		mov [shipbmp + si],"G"
		mov [shipbmp + si + 1],"2"

		jmp exit_func6
		Green_Ship_Texture:
		cmp [menu_ptr],4
		jne Second_Column_Textures
		mov [shipbmp + si],"G"
		mov [shipbmp + si + 1],"1"

		jmp exit_func6
		Second_Column_Textures:
		Orange_Ship_Texture:
		cmp [menu_ptr],5
		jne Purple_Ship_Texture
		mov [shipbmp + si],"O"
		mov [shipbmp + si + 1],"1"

		jmp exit_func6
		Purple_Ship_Texture:
		cmp [menu_ptr],6
		jne Red_Ship_Texture
		mov [shipbmp + si],"P"
		mov [shipbmp + si + 1],"1"

		jmp exit_func6
		Red_Ship_Texture:
		cmp [menu_ptr],7
		jne Yellow_Ship_Texture
		mov [shipbmp + si],"R"
		mov [shipbmp + si + 1],"1"

		jmp exit_func6
		Yellow_Ship_Texture:
		cmp [menu_ptr],8
		jne exit_func6
		mov [shipbmp + si],"Y"
		mov [shipbmp + si + 1],"1"
		jmp exit_func6
		exit_func6:

		ret
		endp ship_texutre

	proc imgmovement 
	    ; a general dynamic procedure that changes img position depending on user input and parameters inserted. / is not used with the pointer [menu]
		; Recieves 7 parameters : x value to change, Y value to change, width, height, restrict Y movement [for rocket_ship], restrict Y movement [for aliens],is alien
		Input_Listener:
		 ;check if there is a a new key in buffer
		 ;check if there is a a new key in buffer
		push bp
		mov bp,sp
		; make it so upon finishing the stack won't clear the variables with bp and ip. then we can pop these variables afterwards.

		xVal equ [bp + 16]
		yVal equ [bp + 14]
		img_width equ [bp + 12]
		img_height equ [bp + 10]
		restricty equ [bp + 8] ; not used
		restrictx equ [bp + 6] ; not used 
		isalien equ [bp + 4] ; not used

		in al, 64h
		cmp al, 10b
		jne fixrelative1
		jmp exit_func

		fixrelative1:
		in al, 60h
		
		cmp al, [saveKey] ;check if the key is same as already pressed
		je KeysSection
		 ;new key- store it
		mov [saveKey], al
		 ;check if the key was pressed or released
		and al, 80h
		jz KeysSection
		jmp exit_func
		
		KeysSection:
		;--------------------;
		;X handling section: ;
		;--------------------;
		Xsection:
			mov bx,xVal ; uses bx like with di to access the memory.
		inc_right: ; If the button matches the presets of move right.
			cmp  al, 20h
			je mover
			cmp al,4Dh
			jne dec_left

			mover:
			mov ax,[bx] ; left top point of reference
			cmp ax,240 ; this means border = 260px | Note: BORDERS WERE KINDA GLITCHED SO THE LIMIT IS 260px INSTEAD OF 320px
			je exit_func
			add [byte ptr bx],4
			jmp exit_func
		
		dec_left: ; If the button matches the presets of move left.
			cmp al, 1Eh
			je movel
			cmp al,4Bh
			jne exit_func

			movel:
			mov ax,[bx]
			cmp ax,0
			je exit_func
			sub [byte ptr bx],4 ; 2 for cycles = max / 4 for cycles = 3000
			jmp exit_func
		;--------------------;
		;Y handling section: ;
		;--------------------;
		; Ysection:
		; 	mov di,yVal ; uses di like with bx to access the memory.
		; dec_up: ; If the button matches the presets of move up.
		; 	cmp  al,1Fh
		; 	je moveu
		; 	cmp al,50h
		; 	jne inc_down

		; 	moveu:
		; 	mov ax,[di]
		; 	sub ax,9
		; 	cmp ax,0
		; 	jbe exit_func
		; 	inc [byte ptr di]
		; 	jmp exit_func
		
		; inc_down: ; If the button matches the presets of move down.
		; 	cmp al, 11h
		; 	je moved
		; 	cmp al,48h
		; 	jne exit_func

		; 	moved:
		; 	mov ax,[di]
		; 	add ax,9
		; 	cmp ax,200
		; 	jae exit_func
		; 	dec [byte ptr di]
		; 	jmp exit_func
		
		exit_func:
		pop bp

		ret 14

		endp imgmovement

	proc shoot_proj
		; A function which shoots a projectile from the ship + checks if collided with alien array.
		in al, 64h ; Read keyboard status port
		cmp al, 10b ; Data in buffer ?
		je Collision_Section

		in al,60h ; get the key that was pressed to al.

		cmp al,[saveKey] ; check if the key pressed is the current key.
		je check_pressed_space; go to the movement section, else there is a new key.
		mov [saveKey],al ; save the new key
		
		Check_pressed_space:
		cmp al,39h
		jne Collision_Section
		cmp [allow_shoot],0
		je Collision_Section
		mov [allow_shoot],0
		mov [allow_move],1
		mov ax,[xVal_Ship]
		add ax,8
		mov [xVal_projectile],ax
		mov ax,[yVal_Ship]
		mov [yVal_projectile],ax


		Collision_Section:
		mov cx,[aliens_count]
		mov si,0
		Check_collision:
		;Collision of x values :
		cmp [yVal_projectile],0 ; check if the projectile is out of bounds.
		je proj_out_of_bounds
		mov ax,[alien_array + si]
		cmp [xVal_projectile],ax
		jb end_of_check
		add ax,15
		cmp [xVal_projectile],ax
		ja end_of_check
		;Collision of y values :
		mov ax,[alien_array + si + 2]
		cmp [yVal_projectile],ax ; check if the y value is above the one of the alien.
		jb end_of_check
		add ax,15
		cmp [yVal_projectile],ax ; check if the y value is below the one of the alien.
		ja end_of_check ; the projectile did not hit.
		; if passed all of these checks -> "remove" alien. NOTE: IN FUTURE MAKE SO ALIEN CANT MOVE.
		Relocate_alien: ; the alien was hit therefore a new projectile can be shot. + relocate alien pos.
		mov [alien_array + si],0
		mov [alien_array + si + 2],0
		mov dx,[xVal_Ship]
		mov [xVal_projectile],dx
		mov dx,[yVal_Ship]
		mov [yVal_projectile],dx
		mov [allow_move],0
		mov [allow_shoot],1
		jmp end_of_check
		Proj_out_of_bounds: ; the projectile is out of bounds a new one can be shot.
		mov [allow_move],0
		mov [allow_shoot],1
		End_of_check:
		add si,4
		loop check_collision

		Exit_func3:
		ret
		endp shoot_proj

	proc init_aliens
		; recieves 1 parameter : aliens_count      
		; function resets x and y values of an alien array.
		mov cx,[aliens_count]
		xor dx,dx
		mov bh,1
		mov si,0
		mov dh,0
		Reset_alien:

		cmp dh,8
 		jne not_out_of_bounds
 		mov dh,1
 		inc bh
 		jmp continue_loop
 		Not_out_of_bounds:
 		inc dh

 		Continue_loop:
 		mov ax,30
 		mul dh
		mov [alien_array + si],ax ; xpos
		mov [alien_proj_array + si],ax
		mov ax,20
 		mul bh
		mov [alien_array + si + 2],ax ; ypos
 		mov [alien_proj_array + si + 2],ax
		add si,4

		loop reset_alien

		ret
		endp init_aliens

	proc init_time
		; a function that resets the system's seconds to 0.
		mov ah,2Ch
		int 21h

		mov dh,0
		mov ah,2Dh
		int 21h

		;mov [current_score],12800
		ret
		endp init_time

	proc init_ship_shot
		; Resets projectile values
		mov ax,[xVal_Ship]
		mov [xVal_projectile],ax
		mov ax,[yVal_Ship]
		mov [yVal_projectile],ax

		mov [allow_shoot],1
		mov [allow_move],0
		ret
		endp init_ship_shot

	proc control_aliens
		; A function which goes over an array of aliens and changes them according to the control array.
		; this function changes the control values according to position on screen of aliens.
		mov si,0 ; index of alien array.
		mov cx,[aliens_count] ; 16 by default
		define_movement_loop:
		mov di,[alien_array + si] ; x pos of alien.
		mov bx,[alien_array + si + 2] ; y pos of alien.

		Move_Right_Condition: ; checks if the aliens should move right.
		cmp bx,20
		je check_move_right_edge
		cmp bx,60
		jne Move_Left_Condition
		jmp check_move_right_edge

		check_move_right_edge: ; this checks and moves the alien right or down if on the edge.
		cmp di,240
		jne allowed_move_right; if not then alien allowed to move right
		add [alien_array + si + 2],20
		jmp continue_check_loop
		allowed_move_right:
		add [alien_array + si],30
		jmp continue_check_loop

		Move_Left_Condition:
		cmp bx,40
		je check_move_left_edge
		cmp bx,80
		jne continue_check_loop
		check_move_left_edge: ; this checks and moves the alien left or down if on the edge.
		cmp di,30
		jne allowed_move_left; if not then alien allowed to move right
		add [alien_array + si + 2],20
		jmp continue_check_loop
		allowed_move_left:
		sub [alien_array + si],30
		jmp continue_check_loop


		continue_check_loop:
		add si,4
		loop define_movement_loop


		ret
		endp control_aliens

	proc shoot_alien
		; A simple function which shoots projectile from alien. checks if alien is dead [(0,0) -> x,y]
		mov si,0 ; offset for alien_array + alien_proj_array.
		mov cx,[aliens_count]
		mov [allow_draw],1
		Alien_Shoot_Loop:
		mov ax,[alien_array + si] ; alien x value.
		mov bx,[alien_array + si + 2] ; alien y value.

		mov [alien_proj_array + si],ax ; proj x value.
		mov [alien_proj_array + si + 2 ],bx ; proj y value.
		add [alien_proj_array + si],6
		add si,4
		loop Alien_Shoot_Loop
		ret
		endp shoot_alien

;----------------;
;End Conditions: ;
;----------------;
	proc win_condition
		; A simple function that goes over the alien array and checks if every alien is in 0,0 (dead).
		; Function redirects to win screen and score.
		mov cx,[aliens_count]
		mov si,0
		mov [user_win],1
		check_win:
		mov dx,[alien_array + si] ; x position of alien.
		mov ax,[alien_array + si + 2] ; y position of alien.

		cmp dx,0
		jne still_alive
		cmp ax,0
		jne still_alive

		jmp still_dead
		still_alive:
		mov [user_win],0
		jmp exit_func4

		still_dead:
		add si,4

		loop check_win

		exit_func4:
		ret
		endp win_condition
	
	proc lose_condition
		; a function which checks if the aliens reached their last stop or if their projectile hit the player.
		mov si,0 ; will serve both alien array and both the projectile array since they are the same size.
		mov cx,[aliens_count]
		mov [user_lose],0
		Check_lose_loop:
		mov ax,[xVal_Ship] ; rocket_ship x value.
		mov bx,[yVal_Ship] ; rocket_ship y value.
		check_proj_hit:
		;X section:
		cmp [alien_proj_array + si],ax
		jb check_alien_arrive
		add ax,20
		cmp [alien_proj_array + si],ax
		ja check_alien_arrive
		;Y section:
		cmp [alien_proj_array + si + 2],bx
		jb check_alien_arrive
		add bx,20
		cmp [alien_proj_array + si + 2],bx
		ja check_alien_arrive

		mov [user_lose],1 
		jmp End_lose_cond_func ; not necessary but conserves resources. 
		check_alien_arrive:
		cmp [alien_array + si],30
		jne end_loop_iteration_lose_cond
		cmp [alien_array + si + 2],100
		jne end_loop_iteration_lose_cond
		mov [user_lose],1
		jmp End_lose_cond_func ; not necessary but conserves resources.

		end_loop_iteration_lose_cond:
		add si,4
		loop Check_lose_loop
		End_lose_cond_func:
		ret
		endp lose_condition

;------------------------------------------------------------------------------------------------------------------------------;
; Space Invaders Main:                                                                                                         ;
	start:
		mov ax, @data
		mov ds,ax
		; Graphic mode
		mov ax, 13h
		int 10h
		;--------------------------;
		;Main Menu Screen Section: ;
		;--------------------------;
		Menu_screen_exec:
				call init_pointer
				menu_loop:
				;-------------------------------------;
				;Drawage of the main menu background: ;
				;-------------------------------------;
				push offset menubmp
				push 0
				push 0
				push 320
				push 200
				call OpenIMG
				;-----------------------------------------------;
				;Drawage + Movement of the pointer in the menu: ;
				;-----------------------------------------------;
				call pointermov_mainmenu
				push offset pointerbmp
				push [xVal_Pointer]
				push [yVal_Pointer]
				push 16
				push 9
				call OpenIMG

				jmp StateInput
				fixrelative2_checkpoint:
				jmp menu_loop
				;-------------------------------------------------------;
				;Check what screen the player wants to move to section: ;
				;-------------------------------------------------------;
				StateInput:
					in al, 64h ; Read keyboard status port
					cmp al, 10b ; Data in buffer ?
					je menu_loop ; Wait until data available
					in al, 60h ; Get keyboard data
					cmp al, 10h ; Is it the Q key ?
					jne redirect_from_pointer_mainmenu
					jmp exit
				
				Redirect_from_pointer_mainmenu: ; Checks if the player pressed enter and where was the pointer at that point.
					cmp al,1Ch
					jne menu_loop
					General_check_1:
					cmp [menu_ptr],1 ; redirect to main game screen. 
					jne general_check_2 ; relative fix
					jmp game_screen_exec
					;General_check_2:
					;cmp [menu_ptr],2 ; redirect to highscore screen.
					;jne general_check_3 ; relative fix
					;jmp highscore_screen_exec
					General_check_2:
					cmp [menu_ptr],2 ; redirect to options screen.
					jne general_check_3; relative fix
					jmp options_screen_exec
					General_check_3:
					cmp [menu_ptr],3 ; redirect to help screen.
					jne fixrelative2_checkpoint ; relative fix
					jmp help_screen_exec

				jmp menu_loop

		;-------------------------------;
		;Highscore Menu Screen Section: ;
		;-------------------------------;
		;Highscore_screen_exec:
				 ; push offset resetbmp ;Redraw the black screen everytime.
				 ; push 0
				 ; push 0
				 ; push 320
				 ; push 200
				 ; call OpenIMG ; open the image

				 ; push offset highscore_menu_dir
				 ; call OpenTxtFile ; Open the highscore data file.
				 ; call ReadText_HighScore ; Copy the line to a buffer.
				 ; call CloseFile ; Closes the file.

				 ; mov dx, offset ScrLine_txt ; copy the second line
				 ; mov ah, 9h
				 ; int 21h


				 ; StateInput3:
				 ; in al, 64h ; Read keyboard status port
				 ; cmp al, 10b ; Data in buffer ?
				 ; jne si_3
				 ; jmp highscore_screen_exec ; Wait until data available
				 ; Si_3:
				 ; in al, 60h ; Get keyboard data
				 ; cmp al, 1h ; Is it the ESC key ?
			 	 ;  jne StateInput3
				 ; jmp menu_screen_exec


				 ; jmp highscore_screen_exec

		;-----------------------------;
		;Options Menu Screen Section: ;
		;-----------------------------;
		Options_screen_exec:
				call init_pointer
				options_menu_loop:
				push offset optionsmenubmp
				push 0
				push 0
				push 320
				push 200
				call OpenIMG

				call pointermov_optionsmenu
				
				push offset pointerbmp
				push [xVal_Pointer]
				push [yVal_Pointer]
				push 16
				push 9
				call OpenIMG

				StateInput4:
				in al, 64h ; Read keyboard status port
				cmp al, 10b ; Data in buffer ?
				je jump_checkpoint3 ; Wait until data available
				in al, 60h ; Get keyboard data
				cmp al,1Ch ; Is it the Enter key ?
				je change_ship_texture
				cmp al, 1h ; Is it the ESC key ?
				jne jump_checkpoint3
				jmp menu_screen_exec

				change_ship_texture:
					call ship_texutre
					jmp Jump_checkpoint3

				Jump_checkpoint3:    
					jmp options_menu_loop
		;--------------------------;
		;Help Menu Screen Section: ;
		;--------------------------;
		Help_screen_exec:

				push offset helpmenubmp
				push 0
				push 0
				push 320
				push 200
				call OpenIMG
				StateInput5:
				in al, 64h ; Read keyboard status port
				cmp al, 10b ; Data in buffer ?
				je help_screen_exec ; Wait until data available
				in al, 60h ; Get keyboard data
				cmp al, 1h ; Is it the ESC key ?
				jne jump_checkpoint4 
				jmp menu_screen_exec

				Jump_checkpoint4:
		
				jmp help_screen_exec
		
		;---------------------;
		;Game Screen Section: ;
		;---------------------;
		Game_screen_exec:
			call init_aliens ; resets aliens position.
			call init_time ; resets the systems seconds to 0.
			call init_ship_shot ; resets ship projectile value [done because if you exit the game and go back it saves the shot's last pos.]
			Game_screen:

			WIN_LOSE_CONDITIONS_SECTION:
			
			win_condition_section:
			call win_condition
			cmp [user_win],1
			jne lose_condition_section
			jmp win_screen
			
			lose_condition_section:
			call lose_condition
			cmp [user_lose],1
			jne BACKGROUND_SCREEN_SECTION
			jmp lose_screen

			
			BACKGROUND_SCREEN_SECTION:
			;---------------------------------------------;
			;Redraw the screen behind / animation effect. ;
			;---------------------------------------------;
			push offset resetbmp ;Redraw the black screen everytime.
			push 0
			push 0
			push 320
			push 200
			call OpenIMG ; open the image
			
			ALIEN_SECTION:
			;-----------------------------------------------------------;
			;Movement of Aliens | Note: currently move every 4 seconds and shoot every 8 seconds. ;
			;-----------------------------------------------------------;
			
			mov ah,2Ch ; get system time.
			int 21h 
			
			cmp dh,0 ; cannot divide by 0.
			je Exit_Timer

			cmp dh,[saveSeconds] ; if equal this means the seconds value didnt change [prevent from spam]
			je Exit_Timer
			;cmp [current_score],0
			;je Alien_Move_Delay
			;sub [current_score],100

			Alien_Move_Delay:
			xor ax,ax
			mov al,dh ; check if 4 seconds have passed.
			mov bl,4
			div bl ; seconds passed from int 21h.
			cmp ah,0
			jne Exit_Timer ; if equal 4 seconds have passed.

			call control_aliens

			Alien_Shoot_Delay:
			xor ax,ax
			mov al,dh
			mov bl,8
			div bl
			cmp ah,0 
			jne Exit_Timer ; if equal shoot a projectile from the alien array.
			cmp dh,0
			call shoot_alien

			Exit_Timer:
			mov [saveSeconds],dh
			;------------------------------------------------------------;
			;Alien Projectiles | Note: currently shoots every 6 seconds. ;
			;------------------------------------------------------------;

			mov si,0
			mov cx,[aliens_count]
			Alien_Draw_Projectiles:
				dec cx
				mov [save_proj_si],si
				mov [save_proj_cx],cx
				
				cmp [alien_proj_array + si + 2],10
				jbe end_of_loop_ADP
				cmp [alien_proj_array + si + 2],180 ; if out of bounds then dont draw and move it.
				jae end_of_loop_ADP
				cmp [alien_array + si],0 ;checks if the alien is dead. by x value.
				jne move_n_draw_proj_alien
				cmp [alien_array + si + 2],0 ;checks if the alien is dead. by y value.
				je end_of_loop_ADP

				move_n_draw_proj_alien:
				cmp [alien_proj_array + si],0
				jne allow_draw_proj
				cmp [alien_proj_array + si + 2],0
				je reset_proj_with_alien_death
				allow_draw_proj:
				add [alien_proj_array + si + 2],5 ; the projectile will move 5 pixels per loop.
				push offset alienprojectilebmp
				push [alien_proj_array + si]
				push [alien_proj_array + si + 2]
				push 4
				push 8
				call OpenIMG
				jmp end_of_loop_ADP
				reset_proj_with_alien_death:
				mov si,[save_proj_si]
				mov cx,[save_proj_cx]
				mov [alien_proj_array + si ],0
				mov [alien_proj_array + si + 2],0

				end_of_loop_ADP:
				mov si,[save_proj_si]
				mov cx,[save_proj_cx]
				add si,4
				cmp cx,0
				je Alien_Drawing_Section
				jmp Alien_Draw_Projectiles

			Alien_Drawing_Section:
			;--------------------------------------------------------------------------------;
			;Drawing of aliens / note: for some reason couldn't have been done in a function ; 
			;--------------------------------------------------------------------------------;
			mov cx, [aliens_count]
			mov si,0
			mov [alien_offset_counter],0
			Draw_alien_loop:
			mov [alien_loop_save],cx

			mov si,[alien_offset_counter]
			mov dx,[alien_array + si] ; x position of an alien.

			mov ax,[alien_array + si + 2] ; ; y position of an alien.

			cmp dx,0 ; check if alien is in dead defined x.
			jne Proceed_draw
			cmp ax,0 ; check if alien is in dead defined y.
			jne Proceed_draw

			mov [alien_proj_array + si],0
			mov [alien_proj_array + si + 2],0
			jmp Continue_draw_loop
			Proceed_draw:
			push offset alienbmp ; alien image dir
			push dx
			push ax
			push 16
			push 15
			call OpenIMG ; open the image
			
			Continue_draw_loop:
			add [alien_offset_counter],4
			
			mov cx,[alien_loop_save]

			loop draw_alien_loop
			
			SPACE_SHIP_SECTION:
			;---------------------------;
			;Movement of the spaceship: ;
			;---------------------------;
			push offset xVal_Ship ; xvalue of the ship
			push offset yVal_Ship ; yvalue of the ship
			push 21
			push 20
			push 0
			push 0
			push 0
			call imgmovement
			;--------------------------;
			;Drawage of the spaceship: ;
			;--------------------------;

			drawing_ship:
			push offset shipbmp
			push [xVal_Ship]
			push [yVal_Ship]
			push 20
			push 20
			call OpenIMG

			;-------------------------------------------------;
			;Projectile Shooting Functions for the spaceship: ;
			;-------------------------------------------------;

			call shoot_proj ; Calculate projectile location and state + collision with aliens.
			MoveNdraw_proj:
			cmp [allow_move],1 ; check if the projectile is allowed to exist and move .
			jne movndraw_exit ; if not exit from the function.
			sub [yVal_projectile],5 ; move the projectile upwards. [1 - for cycles = max]
			
			push offset projectilebmp ; Draw the projectile
			push [xVal_projectile]
			push [yVal_projectile]
			push 4
			push 8
			call OpenIMG
			movndraw_exit:

			StateInput2:
				in al, 64h ; Read keyboard status port
				cmp al, 10b ; Data in buffer ?
				je jump_checkpoint ; Wait until data available
				in al, 60h ; Get keyboard data
				cmp al, 1h ; Is it the ESC key ?
				jne jump_checkpoint
				jmp menu_screen_exec

			Jump_checkpoint:
			jmp game_screen

		win_screen:
			push offset winscreenbmp
			push 0
			push 0
			push 320
			push 200
			call OpenIMG
			
			; mov cx,4
			; mov si,0
			; mov [score_divisor],10000
			; mov bx,[current_score]
			; mov [score_temp],bx

			; score_to_str_loop:
			; 	mov ax,[score_temp]
			; 	div [score_divisor]
			; 	mov [score_str + si],al
			; 	cmp [score_divisor],10
			; 	jne loop_score_to_str
			; 	remainder_last_digit_check:

			; 	mov [score_str + si + 1],ah
			; 	loop_score_to_str:
			; 	mov ax,[score_divisor]
			; 	mov dl,10
			; 	div dl
				
			; 	mov [score_divisor],al
			; 	inc si
			; 	loop score_to_str_loop
			
			; mov dx, offset high_score ; copy the second line
			; mov ah, 9h
			; int 21h


				 StateInput6:
				 in al, 64h ; Read keyboard status port
				 cmp al, 10b ; Data in buffer ?
				 jne si_6
				 jmp win_screen ; Wait until data available
				 Si_6:
				 in al, 60h ; Get keyboard data
				 cmp al, 1h ; Is it the ESC key ?
			 	 jne StateInput6
				 jmp menu_screen_exec


				 jmp win_screen

			Jump_checkpoint7:
			jmp win_screen
			
		lose_screen:
			push offset losescreenbmp
			push 0
			push 0
			push 320
			push 200
			call OpenIMG

			StateInput7:
				in al, 64h ; Read keyboard status port
				cmp al, 10b ; Data in buffer ?
				je Jump_checkpoint6 ; Wait until data available
				in al, 60h ; Get keyboard data
				cmp al, 1h ; Is it the ESC key ?
				jne Jump_checkpoint6
				jmp menu_screen_exec

			Jump_checkpoint6:
			jmp lose_screen

	exit:
		; Back to text mode
		mov ah, 0
		mov al, 2
		int 10h

		mov ax, 4c00h
		int 21h
	                                                                                                                           ;
;------------------------------------------------------------------------------------------------------------------------------;

END start

