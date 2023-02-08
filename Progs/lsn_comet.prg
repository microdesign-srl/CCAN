Lparameters toForm
*****************************************************************
* G.A.C. Evolution - Procedura di normalizzazione listino COMET
* ---------------------------------------------------------------
* AUTORE:	Michele Bravi / Alberto Starnari
* DATA:		03-11-2010 		/ 14-12-2010
* ---------------------------------------------------------------
* SCOPO:	Normalizzazione del listino Comet
* ---------------------------------------------------------------
Local lcStmt 				As String
Local lnRecCount 		As Integer
Local lnSkipped 		As Integer
Local lnNormalized	As Integer
Local lcTxtFile 		As String
Local ltStartTime 	As Datetime
Local ltEndTime 		As Datetime
Local lnTotTime 		As Integer
Local lcMsg 				As String

With toForm
	lcTxtFile 	= .PF.pgGenerale.txtDBFileName.Field.Value
	ltStartTime = Datetime()

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(ltStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	Use In (Select('curMain'))

	Create Cursor curMain (		;
		Fill0 C(9) 	 				; && da 01 	a 09 			- non utilizzato
	,Cd_AR C(17)	 				;	&& da 10 	a 26 		- Articolo Fornitore
	,Descrizion C(35)			;	&& da 27 	a 61 		- Descrizione
	,Fill1 C(78)	 				; && da 62 	a 139 		- non utilizzato
	,Fill10 C(20)					;	&& da 140 a 159			- non utilizzato (era il Listino di Vendita della vecchia versione)
	,Fill2 C(22)					;	&& da 160	a 181			- non utilizzato
	,UM C(2)							;	&& da 182	a 183		- Unità di Misura
	,Fill3 C(104) 				;	&& da 184	a 287			- non utilizzato
	,PrezzoAcquisto C(20)	;	&& da 288	a 307		- Prezzo Acquisto (Listino Nettissimo in Comet)
	,Fill4 C(15)					;	&& da 308	a 322    	- non utilizzato
	,PrezzoVendita C(20)	;	&& da 323 a 342		- Prezzo Vendita (Listino vendita in Comet)
	,Fill11 C(183)				;	&& da 343	a 525    	- non utilizzato
	,Famiglia C(4)				;	&& da 526	a 529		- Marca
	,Gruppo C(18)					;	&& da 530	a 547		- Famiglia Metel
	,Fill9 C(68) )					&& da 548  a 615		- non utilizzato

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
	* (vengono cancellati solo i records che riguardano il listino Comet)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti listino Comet")
	xSqlExec("Delete From xLSImport Where Cd_xLS = 'COMET'", , .T.)

	* Inserimento dati su tabella BLS xLSImport
	Go Top In curMain
	lnRecCount 	= Reccount('curMain')
	lnSkipped 	= 0
	.ProgBarShow(0, Reccount('curMain'), 'Normalizzazione listino Comet')
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Normalizzazione listino Comet") &&,,,,,, .T.

	Scan
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione listino Comet - ' + Transform(Recno('curMain')) + '/' + Transform(Reccount('curMain')))
		TEXT TO lcStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int

			Insert Into [xLSImport]
		           ([Cd_xLS]
		           ,[Cd_AR]
		           ,[Descrizione]
		           ,[UM]
		           ,[PrezzoAcquisto]
		           ,[PrezzoVendita]
		           ,[Famiglia]
		           ,[Gruppo])
	--	           ,[Sottogruppo])
		     Values
		           ('COMET'
		           ,<<Format4Spt(curMain.Cd_AR)>>
		           ,<<Format4Spt(curMain.Descrizion)>>
		           ,<<Format4Spt(curMain.UM)>>
		           ,<<curMain.PrezzoAcquisto>>
		           ,<<curMain.PrezzoVendita>>
		           ,<<Format4Spt(curMain.Famiglia)>>
		           ,<<Format4Spt(curMain.Gruppo)>>)
	--	         '  ,<<<Format4Spt(curMain.Sottogruppo)>>>)'

	    If @@ROWCOUNT > 0
				Set @LastIdentity = SCOPE_IDENTITY()
			Else
				Set @LastIdentity = 0

			Select @LastIdentity AS NewId
		ENDTEXT

		If xSqlExec(lcStmt, 'Inserted', .T.) < 0
			xMessageBox('Il file di import non è un file COMET oppure ci sono' ;
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
Return "1.1 del 04-02-2011"
Endfunc
* ---------------------------------------------------------------
