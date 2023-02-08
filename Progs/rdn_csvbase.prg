Lparameters toForm

Local lcStmt, lcSourceFile, lcMsg, lcTipoImport	As String
Local lnRecCount, lnSkipped, lnNormalized, lnTotTime As Integer
Local lnFileHandle, lnTempoInizio, lnTempoFine As Integer
Local ltStartTime, ltEndTime As Datetime
Local llExit As Boolean
Local loxRDTicketAttivita As Object

With toForm
	lcTipoImport	= .PF.pgGenerale.txtCd_xRDImportTipo.Field.Value
	lcSourceFile 	= .PF.pgGenerale.txtDBFileName.Field.Value
	ltStartTime 	= Datetime()

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(ltStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	* Verifica se si è scelto un corretto file di import
	llExit = .F.
	lnFileHandle = Fopen(lcSourceFile)
	If lnFileHandle < 0
		llExit = .T.
	Else
		Fclose(lnFileHandle)
	Endif

	If llExit
		xMessageBox('Ci sono problemi con la procedura di normalizzazione!' ;
			+ Chr(13) ;
			+ Chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	Use In (Select('curMain'))

	Create Cursor curMain (	;
	Cd_DOSottoCommessa 	C(20) ; && da 01  a 20  - Codice SottoCommessa
	,Id_Attivita 			C(20)	; && da 21 	a 40  - Identificativo Attività
	,Cd_PrRisorsa			C(20)	; && da 41 	a 60  - Codice Risorsa
	,Cd_xOperatore 		C(20)	; && da 61 	a 80  - Codice Operatore
	,DataInizio 			C(10)	; && da 81	a 90  - Data Inizio
	,DataFine 				C(10)	; && da 91	a 100	- Data Fine
	,TempoInizio 			C(5)	; && da 101	a 105 - Tempo Inizio
	,TempoFine 				C(5)	; && da 106 a 110 - Tempo Fine
	,Cd_xRDTipoVal			C(5)	; && da 111 a 115 - Codice Tipo Valorizzazione
	,NoteAttivitaMov 		C(254)) && da 116	a 369 - Note

	Select curMain
	Append From (lcSourceFile) Type Csv

	* Cancellazione dati su tabella BLS xRDImport
	* (vengono cancellati solo i records che riguardano la tipologia selezionata)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti per la tipologia di import " + lcTipoImport)
	xSqlExec("Delete From xRDImport Where Cd_xRDImportTipo = " + Format4Spt(lcTipoImport), , .T.)

	* Inserimento dati su tabella BLS xRDImport
	Go Top In curMain
	lnRecCount 	= Reccount('curMain')
	lnSkipped 	= 0
	.ProgBarShow(0, Reccount('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport)
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog('Normalizzazione tipologia di import ' + lcTipoImport) &&,,,,,, .T.

	Scan
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport + ' ' + Transform(Recno('curMain')) + '/' + Transform(Reccount('curMain') - 1))
		* Ricerca dell'identificativo ticket e del codice attività a partire dall'identificativo attività
		loxRDTicketAttivita = xSqlExec2Obj('Select Id_xRDTicket, Cd_PRAttivita From xRDTicketAttivita Where Id_xRDTicketAttivita = ' + Format4Spt(curMain.Id_Attivita))
		
		If IsEmpty(loxRDTicketAttivita)
			lnSkipped = lnSkipped + 1
			Loop && Perchè l'identificativo attività non è presente nel gestionale.
		Endif
		
		* Se il campo DataFine è vuoto, viene impostato uguale al campo DataInizio.
		If IsEmpty(curMain.DataFine)
			Replace DataFine With DataInizio in curMain
		Endif
		
		* Calcola il TempoInizio e il TempoFine in secondi.
		lnTempoInizio = Val(Left(curMain.TempoInizio, 2)) * 60 * 60
		lnTempoInizio = lnTempoInizio + (Val(Right(curMain.TempoInizio, 2)) * 60)
		lnTempoFine = Val(Left(curMain.TempoFine, 2)) * 60 * 60
		lnTempoFine = lnTempoFine + (Val(Right(curMain.TempoFine, 2)) * 60)
		
		TEXT TO lcStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int
			
			INSERT INTO [xRDImport]
		           ([Cd_xRDImportTipo]
		           ,[Id_xRDTicket]
		           ,[Cd_DOSottoCommessa]
		           ,[Id_xRDTicketAttivita]
		           ,[Cd_PrAttivita]
		           ,[Cd_PrRisorsa]
		           ,[Cd_xOperatore]
		           ,[DataInizio]
		           ,[DataFine]
		           ,[TempoInizio]
		           ,[TempoFine]
		           ,[NoteAttivitaMov]
		           ,[Cd_xRDTipoValorizzazione])
		     VALUES
		           (<<Format4Spt(lcTipoImport)>>
		           ,<<Format4Spt(loxRDTicketAttivita.Id_xRDTicket)>>
		           ,<<Format4Spt(curMain.Cd_DOSottoCommessa)>>
		           ,<<Format4Spt(curMain.Id_Attivita)>>
		           ,<<Format4Spt(loxRDTicketAttivita.Cd_PRAttivita)>>
		           ,<<Format4Spt(curMain.Cd_PRRisorsa)>>
		           ,<<Format4Spt(curMain.Cd_xOperatore)>>
		           ,<<Format4Spt(curMain.DataInizio)>>
		           ,<<Format4Spt(curMain.DataFine)>>
		           ,<<Format4Spt(lnTempoInizio)>>
		           ,<<Format4Spt(lnTempoFine)>>
		           ,<<Format4Spt(curMain.NoteAttivitaMov)>>
		           ,<<Format4Spt(curMain.Cd_xRDTipoVal)>>)

	    If @@ROWCOUNT > 0
				Set @LastIdentity = SCOPE_IDENTITY()
			Else
				Set @LastIdentity = 0

			Select @LastIdentity AS NewId
		ENDTEXT

		If xSqlExec(lcStmt, 'Inserted', .T.) < 0
			xMessageBox('Il file di import non è un file valido oppure ci sono' ;
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

		Rilevazioni Processate:	<< lnRecCount >>
		Rilevazioni Normalizzate:	<< lnNormalized >>
		Rilevazioni Saltate:		<< lnSkipped >>
		Tempo impiegato:		<< SecToHms(lnTotTime, 1) >>

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,, 'Courier New')

	If lnSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono state esluse " + Transform(lnSkipped) + " rilevazioni.",,,, oApp.ColorGridForeRed)
	Endif

	TEXT To lcMsg TextMerge NoShow Pretext 3

		Avanzando, verrà instanziato il wizard di Inserimento Rilevazioni
		dove saranno riportate tutte le rilevazioni normalizzate.

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,,,,,.T.,.T.)
Endwith

* ---------------------------------------------------------------
Function RD_GetVersion()
Return "1.0 del 01-03-2012"
Endfunc
* ---------------------------------------------------------------
