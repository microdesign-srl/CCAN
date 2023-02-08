Lparameters toForm

Local lcStmt, lcSourceFile, lcMsg, lcTipoImport	As String
Local lnRecCount, lnSkipped, lnNormalized, lnTotTime As Integer
Local lnFileHandle As Integer
Local ltStartTime, ltEndTime As Datetime
Local llExit As Boolean

With toForm
	lcTipoImport	= .PF.pgGenerale.txtCd_xContrattoImportTipo.Field.Value
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
		Cd_xContratto			C(10) ; && da 01  a 10  - Codice Contratto
	,Descrizione 			C(230); && da 11 	a 230 - Descrizione
	,Cd_CF						C(7)	; && da 231	a 237 - Codice Cliente \ Fornitore
	)

	Select curMain
	Append From (lcSourceFile) Type Csv

	* Cancellazione dati su tabella BLS xContrattoImportSviluppo, xContrattoImportMatricola, xContrattoImport (in questo ordine)
	* (vengono cancellati solo i records che riguardano la tipologia selezionata)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti per la tipologia di import " + lcTipoImport)
	xSqlExec("Delete From xContrattoImportAR Where Id_xContrattoImport In (Select Distinct Id_xContrattoImport From xContrattoImport Where Cd_xContrattoImportTipo = " + Format4Spt(lcTipoImport) + ")", , .T.)
	xSqlExec("Delete From xContrattoImportSviluppo Where Id_xContrattoImport In (Select Distinct Id_xContrattoImport From xContrattoImport Where Cd_xContrattoImportTipo = " + Format4Spt(lcTipoImport) + ")", , .T.)
	xSqlExec("Delete From xContrattoImportMatricola Where Id_xContrattoImport In (Select Distinct Id_xContrattoImport From xContrattoImport Where Cd_xContrattoImportTipo = " + Format4Spt(lcTipoImport) + ")", , .T.)
	xSqlExec("Delete From xContrattoImport Where Cd_xContrattoImportTipo = " + Format4Spt(lcTipoImport), , .T.)

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

		TEXT TO lcStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int

			INSERT INTO [xContrattoImport]
		           ([Cd_xContrattoImportTipo]
		           ,[Cd_xContratto]
		           ,[Descrizione]
		           ,[Cd_CF])
		     VALUES
		           (<<Format4Spt(lcTipoImport)>>
		           ,<<Format4Spt(curMain.Cd_xContratto)>>
		           ,<<Format4Spt(curMain.Descrizione)>>
		           ,<<Format4Spt(curMain.Cd_CF)>>)

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
		Contratti Processati:	<< lnRecCount >>
		Contratti Normalizzati:	<< lnNormalized >>
		Contratti Saltati:		<< lnSkipped >>
		Tempo impiegato:		<< SecToHms(lnTotTime, 1) >>
	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,, 'Courier New')

	If lnSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono state esluse " + Transform(lnSkipped) + " rilevazioni.",,,, oApp.ColorGridForeRed)
	Endif
Endwith

* ---------------------------------------------------------------
Function XCO_GetVersion()
	Return "1.0 del 11-09-2015"
Endfunc
* ---------------------------------------------------------------
