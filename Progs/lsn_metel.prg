Lparameters toForm
*****************************************************************
* G.A.C. Evolution - Procedura di normalizzazione listino METEL
* ---------------------------------------------------------------
* AUTORE:	Alberto Starnari
* DATA:		04-02-2011
* ---------------------------------------------------------------
* SCOPO:	Normalizzazione del listino Metel
* ---------------------------------------------------------------
Local lcStmt 						As String
Local lnRecCount 				As Integer
Local lnSkipped 				As Integer
Local lnNormalized			As Integer
Local lcTxtFile 				As String
Local ltStartTime 			As Datetime
Local ltEndTime 				As Datetime
Local lnTotTime 				As Integer
Local lcMsg 						As String
Local lcStr 						As String
Local lnFileHandle 			As Integer
Local llExit 						As Boolean
Local lnPrezzoAcquisto 	As Double
Local lnPrezzoVendita 	As Double
With toForm
	lcTxtFile 	= .PF.pgGenerale.txtDBFileName.Field.Value
	ltStartTime = Datetime()

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(ltStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	* Verifica se si è scelto un corretto file di import
	llExit = .F.
	lnFileHandle = Fopen(lcTxtFile)
	If lnFileHandle < 0
		llExit = .T.
	Else
		lcStr = Fgets(lnFileHandle)
		Fclose(lnFileHandle)
		If Upper(Left(lcStr, 13)) # 'LISTINO METEL'
			llExit = .T.
		Endif
	Endif

	If llExit
		xMessageBox('Il file di import non è un file METEL oppure ci sono' ;
			+ Chr(13) ;
			+ 'problemi con la procedura di normalizzazione!' ;
			+ Chr(13) ;
			+ Chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	Use In (Select('curMain'))

	Create Cursor curMain (		;
		Cd_AR_Prefisso C(3)  ; && da 01  a 03    - Prefisso Articolo Fornitore
	,Cd_AR C(16)	 				;	&& da 04 	a 19 		- Articolo Fornitore
	,Fill0 C(13)	 				; && da 20 	a 32 			- non utilizzato
	,Descrizion C(43)			;	&& da 33 	a 75 		- Descrizione
	,Fill1 C(22)					;	&& da 76	a 97			- non utilizzato
	,PrezzoAcquisto C(11)	;	&& da 98	a 108		- Prezzo Acquisto (Prezzo al Grossista in Metel)
	,PrezzoVendita C(11)	;	&& da 109 a 119		- Prezzo Vendita (Prezzo al Pubblico in Metel)
	,Moltiplicatore C(6)	;	&& da 120 a 125		- Moltiplicatore del Prezzo
	,Fill2 C(3)						;	&& da 126	a 128    	- non utilizzato
	,UM C(3)							;	&& da 129	a 131		- Unità di Misura
	,Fill3 C(46) )					&& da 132 a 177		- non utilizzato

	* Riempe un cursore temporaneo dove in seguito i dati vengono
	* ripuliti per avere il cursore principale senza incongruenze.
	Select * ;
		FROM curMain ;
		INTO Cursor curMainTemp Readwrite ;
		WHERE 1 = 0

	Select curMainTemp
	Append From (lcTxtFile) Type Sdf

	* Elimina i records con articoli duplicati
	Index On Cd_AR Tag Cd_AR
	Set Order To Tag Cd_AR

	Select Cd_AR, Count(*) As Volte ;
		FROM curMainTemp ;
		INTO Cursor curTest ;
		GROUP By Cd_AR ;
		ORDER By Volte Desc

	Go Top In curTest
	Select curMainTemp

	If curTest.Volte > 1
		lcCurCd_AR = ''
		Go Top In curMainTemp
		Scan
			If curMainTemp.Cd_AR == lcCurCd_AR
				Delete
			Else
				lcCurCd_AR = curMainTemp.Cd_AR
			Endif
		Endscan
	Endif

	Use In curTest
	Select curMain
	Append From Dbf('curMainTemp')
	Use In curMainTemp

	* Cancellazione dati su tabella BLS xLSImport
	* (vengono cancellati solo i records che riguardano il listino Metel)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti listino Metel")
	xSqlExec("Delete From xLSImport Where Cd_xLS Like 'METEL%'", , .T.)

	* Inserimento dati su tabella BLS xLSImport
	Go Top In curMain
	lnRecCount 	= Reccount('curMain') - 1
	lnSkipped 	= 0
	.ProgBarShow(0, Reccount('curMain') - 1, 'Normalizzazione listino Metel')
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Normalizzazione listino Metel") &&,,,,,, .T.

	Scan
		If Recno('curMain') = 1
			Loop && Nel file di import METEL il primo record è sempre un'intestazione del file stesso.
		Endif
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione listino Metel - ' + Transform(Recno('curMain')) + '/' + Transform(Reccount('curMain') - 1))
		* Calcolo del prezzo di acquisto e del prezzo di vendita tramite moltiplicatore
		lnPrezzoAcquisto	=	(Val(Left(curMain.PrezzoAcquisto, 9)) + (Val(Right(curMain.PrezzoAcquisto	, 2))/100)) / Val(curMain.Moltiplicatore)
		lnPrezzoVendita	  =	(Val(Left(curMain.PrezzoVendita	, 9)) + (Val(Right(curMain.PrezzoVendita	, 2))/100)) / Val(curMain.Moltiplicatore)

		TEXT TO lcStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int

			Insert Into [xLSImport]
		           ([Cd_xLS]
		           ,[Cd_AR]
		           ,[Descrizione]
		           ,[UM]
		           ,[PrezzoAcquisto]
		           ,[PrezzoVendita])
		     Values
		           ('METEL'
		           ,<<Format4Spt(Cd_AR_Prefisso + curMain.Cd_AR)>>
		           ,<<Format4Spt(curMain.Descrizion)>>
		           ,<<Format4Spt(curMain.UM)>>
		           ,<<Format4Spt(lnPrezzoAcquisto)>>
		           ,<<Format4Spt(lnPrezzoVendita)>>)

	    If @@ROWCOUNT > 0
				Set @LastIdentity = SCOPE_IDENTITY()
			Else
				Set @LastIdentity = 0

			Select @LastIdentity AS NewId
		ENDTEXT

		If xSqlExec(lcStmt, 'Inserted', .T.) < 0
			xMessageBox('Il file di import non è un file METEL oppure ci sono' ;
				+ Chr(13) ;
				+ 'problemi con la procedura di normalizzazione!' ;
				+ Chr(13) ;
				+ Chr(13) ;
				+ 'Impossibile continuare.', 16)
			toForm.CmdExit()
			Return .F.
		Else
			lnSkipped = lnSkipped + Iif(Inserted.NewId = 0, 1, 0)
		Endif
	Endscan

	Use In curMain

	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.ProgBarHide()

	ltEndTime 		= Datetime()
	lnNormalized 	= lnRecCount - lnSkipped
	lnTotTime 		= ltEndTime - ltStartTime

	TEXT To lcMsg TextMerge NoShow Pretext 3

		Articoli Processati:		<< lnRecCount >>
		Articoli Normalizzati:	<< lnNormalized >>
		Articoli Saltati:		<< lnSkipped >>
		Tempo impiegato:		<< SecToHms(lnTotTime, 1) >>

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,, 'Courier New')

	If lnSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono stati eslusi " + Transform(lnSkipped) + " articoli.",,,, oApp.ColorGridForeRed)
	Endif
Endwith

* ---------------------------------------------------------------
Function LS_GetVersion()
	Return "1.0 del 04-02-2011"
Endfunc
* ---------------------------------------------------------------
