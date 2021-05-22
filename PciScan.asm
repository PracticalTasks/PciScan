;PciRecScan.asm
;Created by Alexandr Kail
;Fasm, cp1251

;СКАНИРУИМ ШИНУ PCI
;0-7 ИНДЕКС РИГИСТРА
;8-10 ФУНКЦИЯ
;11-15 УСТРОЙСТВА
;16-23 ШИНА
;24-30 РИЗЕРВ 0
;31 C - ФЛАГ ДОСТУПА К УСТРОЙСТВУ 1 

;КОНСТАНТЫ	
CONF_ADDR			EQU 0CF8H						;ПОРТ CONFIG_ADDRESS
CONF_DATA			EQU	0CFCH						;ПОРТ CONFIG_DATA
CLASS_CODE 			EQU 08H							;Class code/Subclass/ProgIF/Revision ID
SECONDARY_BUS		EQU	18H							;Secondary Bus Number/Primary Bus Number
PCI_BRIDGE			EQU	0604H						;Class Code 06, Subclass 04
SIZE_STR_SCREEN		EQU 160							;РАЗМЕР ОДНОЙ СТРОКИ ЭКРАНА 80*2
SIZE_SCREEN			EQU 0FA0H						;РАЗМЕР ЭКРАНА В БАЙТАХ 80х25
WHITE_BLACK			EQU 7							;БЕЛЫЙ СИМВОЛ НА ЧЁРНАМ ФОНЕ
RED_BLACK			EQU 4								
SECOND_COLUMN		EQU 32
THIRD_COLUMN		EQU 64
FOURTH_COLUMN		EQU 96
FIFTH_COLUMN		EQU 128	

Start:
		MOV		AX,CS
		MOV		DS,AX
			CLI
		MOV		SS,AX
		MOV		SP,Start
			STI
;УСТАНАВЛЕВАЕМ ВИДИО РЕЖИМ
		MOV		AL,3						;AH=0 80x25
	INT		10H
		MOV		AH,1
		MOV		CX,2000H					;5 БИТ CH ПОДАВИТЬ КУРСОР
	INT		10H								;УБИРАЕМ КУРСОР
		MOV		AX,0B800H               	;АДРЕС ВИДИО ПАМЯТИ ТЕКСТОВОГО РЕЖИМА
		MOV		ES,AX						;УСТОНАВЛЕВАЕМ СЕГМЕНТ НА ВИДЕО ПАМЯТЬ
		XOR		DI,DI						;УКАЗАТЕЛЬ В ВИДЕОПАМЯТИ
;РАЗМЕЧАЕМ ПОЛЯ	
	CALL	FieldMarkup
		XOR		CL,CL

;ЦИКЛ СКАНИРОВАНИЯ УСТРОЙСТВ				
ScanDevices:
;ПАЛУЧАЕМ ДАННЫЕ ИЗ ПАРТОВ	I/O		
			
		MOV		EAX,[confAddr]				;НАЧАЛЬНЫЙ АДРЕС(BUS_0,DEV_0,FUN_0,_REG_0),СТАРШИЙ БИТ ЗАРЕЗЕРВИРОВАН
		MOV		DX,CONF_ADDR                    
		OUT		DX,EAX						;ВЫСТОВЛЯИМ АДРЕС В ПОРТ PCI CONFIG_ADDRESS	
		MOV		DX,CONF_DATA	                
		IN		EAX,DX						;ЧИТАЕМ РЕГИСТР КОНФ. ПРОСТРАНСТВА PCI ИЗ CONFIG_DATA
		CMP		AX,0FFFFH					;ЕСЛИ VenID = 0FFFFH, УСТРОЙСТВО ОТСУТСТВУЕТ.
	JE	.End								;ВЫБИРАЕМ СЛЕДУЮЩЕЕ УСТРОЙСТВО
		MOV		[regVenID],EAX				;СОХРОНЯЕМ РЕГИСТР В СТЭК
		
		MOV		EAX,[confAddr]				
		ADD		EAX,CLASS_CODE				;Class code/Subclass/ProgIF/Revision ID
		MOV		DX,CONF_ADDR
		OUT		DX,EAX						
		MOV		DX,CONF_DATA
		IN		EAX,DX	
		MOV		[regClCode],EAX	
	CALL	PrintScreen
	
		SHR		EAX,16						;ОСТАВЛЯЕМ ДВА СТАРШИХ БАЙТА
		CMP		AX,PCI_BRIDGE				
	JNE	.End
	
		MOV		EAX,[confAddr]	
		ADD		EAX,SECONDARY_BUS			;Secondary Bus Number/Primary Bus Number УЗНАЁМ НОМЕР ВТОРИЧНОЙ ШИНЫ
		MOV		DX,CONF_ADDR	
		OUT		DX,EAX							
		MOV		DX,CONF_DATA	
		IN		EAX,DX	
		
		MOV		EBX,[confAddr]					;СОХРОНЯЕМ ТЕКУЩУЮ ШИНУ, УСТРОЙСТВО И ФУНКЦИЮ 
		PUSH	EBX
			
		MOV		BYTE[confAddr+2],AH				;ВЫСТАВЛЯЕМ Secondary Bus Number
		MOV		BYTE[confAddr+1],0				;ОБНУЛЯЕМ D:F	
	CALL	ScanDevices	
	
		POP		EBX
		MOV		[confAddr],EBX					;ВОЗВРАЩАЕМ B.D:F
		
;ВЫБИРАЕМ СЛЕДУЮЩЕЕ УСТРОЙСТВО
.End:	
		CMP	 	WORD[confAddr],0FF00H			;СКАНИРУЕМ ОДНУ ШИНУ ;8-10 ФУНКЦИЯ, 11-15 УСТРОЙСТВА
	JE	_End
		ADD		[confAddr],100H					;СЛЕДУЮЩЕЕ ФУНКЦИЯ, УСТРОЙСТВО, ШИНА
	JMP	ScanDevices
	
_End:
		CMP		BYTE[confAddr+3],0
	JE	@F
	RET
@@:
	JMP	$
	
PrintScreen:
		PUSH	EAX
	;ВЫВОДИМ ДАННЫЕ НА ЭКРАН					
		MOV		BL,BYTE[confAddr+2]			;ВЫЯСНЯЕМ НОМЕР ШИНЫ
		ADD		[addrBdf],SIZE_STR_SCREEN	;СЛЕДУЮЩАЯ СТРОКА ВЫВОДА В ВИДЕОПАМЯТИ(80 * (НА СИМВ. + АТРИБ.))	
		MOV		DI,[addrBdf]	
		CMP		DI,0F00H					;ПОСЛЕДНЯЯ ЛИ СТРОКА? 24*160(КОЛ. БАЙТ В ОДНОЙ СТРОКЕ)	
	JE	NextPage							;УСТАНАВЛИВАЕМ ВЫВОД НА НОВЫЙ ЭКРАН
.L1:
	CALL	ConvNumOfStr1					;ВЫВОДЕМ НОМЕР ШИНЫ
		MOV		AL,'.'				           
		STOSW								;ВЫВОДЕМ НИЖНИЙ СЛЭШ
		MOV		BL,BYTE[confAddr+1]			   		
		SHR		BL,3						;НОМЕР УСТРОЙСТВА СТАРШИЕ 5 БИТ
	CALL	ConvNumOfStr1
		MOV		AL,':'
		STOSW
		MOV		BL,BYTE[confAddr+1]
		AND		BL,7									;МАСКИРУЕМ СТАРШИЕ 5 БИТ; НОМЕР ФУНКЦИИ 	
	CALL	ConvNumOfStr1	                
		MOV		EBX,[regVenID]							;В EBX РЕГИСТР КОНФ. ПРОСТРАНСТВА PCI
		ADD		[addrVen],SIZE_STR_SCREEN				;ПОКАЗЫВАЕТ НА МЕСТО ДЛЯ ВЫВОДА VenID
		MOV		DI,[addrVen]
	CALL	ConvNumOfStr2
		SHR		EBX,16
		ADD		[addrDev],SIZE_STR_SCREEN				;ПОКАЗЫВАЕТ НА МЕСТО ДЛЯ ВЫВОДА DevID
		MOV		DI,[addrDev]				
	CALL	ConvNumOfStr2		
		MOV		BX,WORD[regClCode+2]
		ADD		[addrRegPci],SIZE_STR_SCREEN			;УВЕЛИЧИВАЕМ НА ОДНУ СТРОКУ
		MOV		DI,[addrRegPci]
	CALL	ConvNumOfStr2
		MOV		BL,BYTE[regClCode+1]
	CALL	ConvNumOfStr1
		POP		EAX
	RET
	
;ФУНКЦИЯ ПОДГАТОВКИ СЛЕДУЮЩЕЙ СТРАНИЦЫ	
NextPage:
		MOV		SI,msg
		MOV		AH,WHITE_BLACK	;БЕЛЫЙ СИМВОЛ НА ЧЁРНАМ ФОНЕ			
	CALL	LineOut				;ВЫВОДЕМ СООБЩЕНИЕ
		MOV		AH,10H          
	INT	16H						;СЧИТЫВАНИЯ СИМВОЛА С ОЖИДАНИЕМ
		XOR		EAX,EAX
		XOR		DI,DI
		MOV		CX,SIZE_SCREEN
	REP	STOSD
		MOV		[addrBdf],SIZE_STR_SCREEN
		MOV		[addrVen],SECOND_COLUMN
		MOV		[addrDev],THIRD_COLUMN
		MOV		[addrRegPci],FOURTH_COLUMN
		MOV		[addrHeadType],FIFTH_COLUMN
		XOR		DI,DI
;РАЗМИЧАИМ ПАЛЯ	
	CALL	FieldMarkup
		MOV		DI,SIZE_STR_SCREEN
	JMP	PrintScreen.L1

;РАЗМЕТКА ПОЛЯ	
FieldMarkup:
		MOV		SI,msgBdf				;ВЫВОДИМАЯ СТРОКА
;ЗАМЕНИТЬ НА КОНСТАНТУ
		MOV		AH,RED_BLACK			;КРАСНЫЙ СИМВОЛ НА ЧЁРНОМ ФОНЕ		
	CALL	LineOut                       
		MOV		DI,[addrVen]			;НАДПИСЬ VenID
		MOV		SI,msgVen               
		MOV		AH,RED_BLACK			;КРАСНЫЙ СИМВОЛ НА ЧЁРНОМ ФОНЕ		
	CALL	LineOut				        
		MOV		DI,[addrDev]			;НАДПИСЬ DevID
		MOV		SI,msgDev               
		MOV		AH,RED_BLACK			;КРАСНЫЙ СИМВОЛ НА ЧЁРНОМ ФОНЕ		
	CALL	LineOut
		MOV		DI,[addrRegPci]
		MOV		SI,msgClassCode
		MOV		AH,RED_BLACK
	CALL	LineOut
		MOV		DI,[addrHeadType]
		MOV		SI,msgHeadType	
		MOV		AH,RED_BLACK
	CALL	LineOut
	
	RET	
		
;ПРЕОБРАЗУЕМ ДВА БАЙТА В ASCII СИМВОЛ
;В BX ВЫВОДИМОЕ HEX ЗНАЧЕНИЕ
;В ES:DI АДРЕС ВИДЕОПАМЯТИ
ConvNumOfStr2:		
		MOV		AH,RED_BLACK	
		MOV		AL,BH			;СТАРШИЙ БАЙТ
;!!!!!!!!!!!!!! Придумать название
	CALL	Fun					;ВЫВОДИМ БАЙТ
		MOV		AL,BL			;МЛАДШИЙ БАЙТ
	CALL	Fun                

	RET                         
Fun:	                        
		PUSH	AX				;СОХРАНЯЕМ AL
		SHR		AL,4			;СТАРШИЙ РАЗРЯД БАЙТА
	CALL 	CharOut				;ВЫВОД СИМВОЛА
		POP		AX				;ВОСТАНАВЛЕВАЕМ
		AND		AL,00001111B	;МЛАДШИЙ РАЗРЯД БАЙТА		
	CALL	CharOut			    

	RET                         

CharOut:						
		CMP		AL,0AH			;ЦИФРЫ ИЛИ БУКВЫ
		JAE	L1	                
		ADD		AL,30H			;ПРЕАБРАЗУИМ В ASCII
@@:			                    
		STOSW                   
	RET                         

L1:                             
		ADD		AL,37H			;ПРЕАБРАЗУИМ В ASCII
	JMP	@b	

;ПРЕОБРАЗУЕМ 1 БАЙТ В ASCII СИМВОЛ
;В BL ВЫВОДИМОЕ HEX ЗНАЧЕНИЕ
;В ES:DI АДРЕС ВИДЕОПАМЯТИ
ConvNumOfStr1:
		MOV		AH,RED_BLACK	
		MOV		AL,BL			;ВЫВОДИМЫЙ БАЙТ	
		PUSH	AX				;СОХРАНЯЕМ AL
		SHR		AL,4			;СТАРШИЙ РАЗРЯД БАЙТА
	CALL 	CharOut				;ВЫВОД СИМВОЛА
		POP		AX				;ВОСТАНАВЛЕВАЕМ
		AND		AL,00001111B	;МЛАДШИЙ РАЗРЯД БАЙТА
	CALL	CharOut							
	RET                         
	
;ВЫВОДЕМ СТРОКУ СИМВОЛОВ ЗАКАНЧИВАЮЩУЮСЯ 0
;В DS:SI СТРОКА СИМВОЛОВ	
;В ES:DI СМЕЩЕНИЕ В ВИДЕОПАМЯТИ
;В AH АТРИБУТ СИМВОЛА		
LineOut:						
		MOV		AL,[SI]
		CMP		AL,0
	JE	.End
			STOSW	
		INC		SI
	JMP	LineOut
	
.End:	
	RET	
	
;==========================ДАННЫИ==================================
;ПЕРЕМЕННЫЕ
msgBdf				DB	'B.D:F',0					;ШИНА.УСТР:ФУН
msgVen				DB	'VenID',0
msgDev				DB	'DevID',0
msgClassCode		DB	'ClCode/SubCl',0
msgHeadType			DB	'HeaderType',0
msg					DB	"Press any button to continue...",0
;0-2 ФУНКЦИЯ(3 БИТА),3-7 УСТРОЙСТВО(5 БИТ),8-15 ШИНА(8 БИТ)
confAddr			DD	80000000H					;НАЧАЛЬНЫЙ АДРЕС
regClCode			DD  0	
regVenID			DD  0
regHeadType			DD	0							;ПЕРЕМЕННАЯ ДЛЯ ХРАНЕНИЯ РЕГ. PCI	
addrBdf				DW	0							;МЕСТО ВЫВОДА "B.D:F"
secondaryBus		DB	0							;НОМЕР ВТОРИЧНОЙ ШИНЫ
addrVen				DW	SECOND_COLUMN				;МЕСТО ВЫВОДА VenID	
addrDev				DW	THIRD_COLUMN				;МЕСТО ВЫВОДА DevID		
addrRegPci			DW	FOURTH_COLUMN				;МЕСТО ВЫВОДА РЕГ. PCI
addrHeadType		DW	FIFTH_COLUMN



	