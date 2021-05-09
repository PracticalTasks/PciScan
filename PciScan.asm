;PciRecScan.asm
;Created by Alexandr Kail
;Fasm, cp1251

;яйюмхпсхл ьхмс PCI
;0-7 хмдейя пхцхярпю
;8-10 тсмйжхъ
;11-15 сярпниярбю
;16-23 ьхмю
;24-30 пхгепб 0
;31 C - ткюц днярсою й сярпниярбс 1 	
Start:
		MOV		AX,CS
		MOV		DS,AX
			CLI
		MOV		SS,AX
		MOV		SP,Start
			STI
		MOV		AH,1
		MOV		CX,2000H
	INT		10H								;сахпюел йспянп
		MOV		AX,0B800H               	
		MOV		ES,AX						;сярнмюбкебюел яецлемр мю бхден оюлърэ
		XOR		DI,DI						;сйюгюрекэ б бхденоюлърх
;пюглевюел онкъ	
	CALL	FieldMarkup
		XOR		CL,CL

;жхйк яйюмхпнбюмхъ сярпниярб				
ScanDevices:
;оюксвюел дюммше хг оюпрнб	I/O		
			
		MOV		EAX,[confAddr]				;мювюкэмши юдпея(BUS_0,DEV_0,FUN_0,_REG_0),ярюпьхи ахр гюпегепбхпнбюм
		MOV		DX,0CF8H                    
		OUT		DX,EAX						;бшярнбкъхл юдпея б онпр PCI CONFIG_ADDRESS	
		MOV		DX,0CFCH	                
		IN		EAX,DX						;вхрюел пецхярп йнмт. опнярпюмярбю PCI хг CONFIG_DATA
		CMP		AX,0FFFFH					;еякх VenID = 0FFFFH, сярпниярбн нрясрярбсер.
	JE	.End								;бшахпюел якедсчыее сярпниярбн
		MOV		[regVenID],EAX				;янупнмъел пецхярп б ярщй
		
		MOV		EAX,[confAddr]				
		ADD		EAX,08H						;Class code/Subclass/ProgIF/Revision ID
		MOV		DX,0CF8H
		OUT		DX,EAX						
		MOV		DX,0CFCH
		IN		EAX,DX	
		MOV		[regClCode],EAX	
	CALL	OutputScreen
	
		SHR		EAX,16
		CMP		AX,0604H
	JNE	.End
	
		MOV		EAX,[confAddr]	
		ADD		EAX,18H							;Secondary Bus Number/Primary Bus Number сгмю╗л мнлеп брнпхвмни ьхмш
		MOV		DX,0CF8H	
		OUT		DX,EAX							
		MOV		DX,0CFCH	
		IN		EAX,DX	
		
		MOV		EBX,[confAddr]					;янупнмъел рейсысч ьхмс, сярпниярбн х тсмйжхч 
		PUSH	EBX
			
		MOV		BYTE[confAddr+2],AH				;бшярюбкъел Secondary Bus Number
		MOV		BYTE[confAddr+1],0				;намскъел D:F	
	CALL	ScanDevices	
	
		POP		EBX
		MOV		[confAddr],EBX					;бнгбпюыюел B.D:F
		
;бшахпюел якедсчыее сярпниярбн
.End:	
		CMP	 	WORD[confAddr],0FF00H			;яйюмхпсел ндмс ьхмс
	JE	_End
		ADD		[confAddr],100H					;якедсчыее сярпниярбн, ьхмю
	JMP	ScanDevices
	
_End:
		CMP		BYTE[confAddr+3],0
	JE	@F
	RET
@@:
	JMP	$
	
OutputScreen:
		PUSH	EAX

	;бшбндхл дюммше мю щйпюм					
		MOV		BL,BYTE[confAddr+2]			;бшъямъел мнлеп ьхмш
		ADD		[addrBdf],160				;якедсчыюъ ярпнйю бшбндю б бхденоюлърх(80 * (мю яхлб. + юрпха.))	
		MOV		DI,[addrBdf]	
		CMP		DI,0F00H					;онякедмъъ кх ярпнйю?	
	JE	NextPage							;сярюмюбкхбюел бшбнд мю мнбши щйпюм
.L1:
	CALL	ConvNumOfStr1					;бшбндел мнлеп ьхмш
		MOV		AL,'.'				           
		STOSW								;бшбндел мхфмхи якщь
		MOV		BL,BYTE[confAddr+1]			   		
		SHR		BL,3						;мнлеп сярпниярбю ярюпьхе 5 ахр
	CALL	ConvNumOfStr1
		MOV		AL,':'
		STOSW
		MOV		BL,BYTE[confAddr+1]
		AND		BL,7						;яювйхпсел ярюпьхе 5 ахр; мнлеп тсмйжхх 	
	CALL	ConvNumOfStr1	                
		MOV		EBX,[regVenID]				;б EBX пецхярп йнмт. опнярпюмярбю PCI
		ADD		[addrVen],160				;онйюгшбюер мю леярн дкъ бшбндю VenID
		MOV		DI,[addrVen]
	CALL	ConvNumOfStr2
		SHR		EBX,16
		ADD		[addrDev],160				;онйюгшбюер мю леярн дкъ бшбндю DevID
		MOV		DI,[addrDev]				
	CALL	ConvNumOfStr2		
		MOV		BX,WORD[regClCode+2]
		ADD		[addrRegPci],160			;!!!люцхвеяйне вхякн
		MOV		DI,[addrRegPci]
	CALL	ConvNumOfStr2
		MOV		BL,BYTE[regClCode+1]
	CALL	ConvNumOfStr1
		POP		EAX
	RET
;вей тсмйжхъ нопедекъчыюъ лняр PCI-PCI	

	
;тсмйжхъ ондцюрнбйх якедсчыеи ярпюмхжш	
NextPage:
		MOV		SI,msg
		MOV		AH,00000111B	;аекши яхлбнк мю в╗пмюл тнме			
	CALL	LineOut				;бшбндел яннаыемхе
		MOV		AH,10H          
	INT	16H						;явхршбюмхъ яхлбнкю я нфхдюмхел
		XOR		EAX,EAX
		XOR		DI,DI
		MOV		CX,0FA0H
	REP	STOSD
		MOV		[addrBdf],160
		MOV		[addrVen],32
		MOV		[addrDev],64
		MOV		[addrRegPci],96
		MOV		[addrHeadType],128
		XOR		DI,DI
;пюглхвюхл оюкъ	
	CALL	FieldMarkup
		MOV		DI,160
	JMP	OutputScreen.L1

;пюглерйю онкъ	
FieldMarkup:
		MOV		SI,msgBdf				;бшбндхлюъ ярпнйю
;гюлемхрэ мю йнмярюмрс
		MOV		AH,00000100B			;йпюямши яхлбнк мю в╗пмнл тнме		
	CALL	LineOut                       
		MOV		DI,[addrVen]			;мюдохяэ VenID
		MOV		SI,msgVen               
		MOV		AH,00000100B			;йпюямши яхлбнк мю в╗пмнл тнме		
	CALL	LineOut				        
		MOV		DI,[addrDev]					;мюдохяэ DevID
		MOV		SI,msgDev               
		MOV		AH,00000100B			;йпюямши яхлбнк мю в╗пмнл тнме		
	CALL	LineOut
		MOV		DI,[addrRegPci]
		MOV		SI,msgClassCode
		MOV		AH,00000100B
	CALL	LineOut
		MOV		DI,[addrHeadType]
		MOV		SI,msgHeadType	
		MOV		AH,00000100B
	CALL	LineOut
	
	RET	
		
;опенапюгсел дбю аюирю б ASCII яхлбнк
;б BX бшбндхлне HEX гмювемхе
;б ES:DI юдпея бхденоюлърх
ConvNumOfStr2:		
		MOV		AH,00000100B	
		MOV		AL,BH			;ярюпьхи аюир
;!!!!!!!!!!!!!! оПХДСЛЮРЭ МЮГБЮМХЕ
	CALL	Fun1				;бшбндхл аюир
		MOV		AL,BL			;лкюдьхи аюир
	CALL	Fun1                

	RET                         
Fun1:	                        
		PUSH	AX				;янупюмъел AL
		SHR		AL,4			;ярюпьхи пюгпъд аюирю
	CALL 	CharOut				;бшбнд яхлбнкю
		POP		AX				;бнярюмюбкебюел
		AND		AL,00001111B	;лкюдьхи пюгпъд аюирю		
	CALL	CharOut			    

	RET                         

CharOut:						
		CMP		AL,0AH			;жхтпш хкх асйбш
		JAE	L1	                
		ADD		AL,30H			;опеюапюгсхл б ASCII
@@:			                    
		STOSW                   
	RET                         

L1:                             
		ADD		AL,37H			;опеюапюгсхл б ASCII
	JMP	@b	

;опенапюгсел 1 аюир б ASCII яхлбнк
;б BL бшбндхлне HEX гмювемхе
;б ES:DI юдпея бхденоюлърх
ConvNumOfStr1:
		MOV		AH,00000100B	
		MOV		AL,BL			;бшбндхлши аюир	
		PUSH	AX				;янупюмъел AL
		SHR		AL,4			;ярюпьхи пюгпъд аюирю
	CALL 	.CharOut			;бшбнд яхлбнкю
		POP		AX				;бнярюмюбкебюел
		AND		AL,00001111B	;лкюдьхи пюгпъд аюирю
	CALL	.CharOut							
	RET                         

.CharOut:                       
		CMP		AL,0AH			;жхтпш хкх асйбш
		JAE	.L1	                
		ADD		AL,30H			;опенапюгсел б ASCII
@@:			                    
		STOSW                   
	RET                         
	
.L1:                            
		ADD		AL,37H			;опенапюгсел б ASCII
	JMP	@b	
	
;бшбндел ярпнйс яхлбнкнб гюйюмвхбючысчяъ 0
;б DS:SI ярпнйю яхлбнкнб	
;б ES:DI ялеыемхе б бхденоюлърх
;б AH юрпхаср яхлбнкю		
LineOut:						
		MOV		AL,[SI]
		CMP		AL,0
	JE	.End
			STOSW	
		INC		SI
	JMP	LineOut
	
.End:	
	RET	
	


;==========================дюммшх==================================
msgBdf			DB	'B.D:F',0					;ьхмю.сярп:тсм
msgVen			DB	'VenID',0
msgDev			DB	'DevID',0
msgClassCode	DB	'ClCode/SubCl',0
msgHeadType		DB	'HeaderType',0
msg				DB	"Press any button to continue...",0
;0-2 тсмйжхъ(3 ахрю),3-7 сярпниярбн(5 ахр),8-15 ьхмю(8 ахр)
confAddr		DD	80000000H					;мювюкэмши юдпея
regClCode		DD  0	
regVenID		DD  0
regHeadType		DD	0							;оепелеммюъ дкъ упюмемхъ пец. PCI	
addrBdf			DW	0							;леярн бшбндю "B.D:F"
secondaryBus	DB	0							;мнлеп брнпхвмни ьхмш
addrVen			DW	32							;леярн бшбндю VenID	
addrDev			DW	64							;леярн бшбндю DevID		
addrRegPci		DW	96							;леярн бшбндю пец. PCI
addrHeadType	DW	128	
					