Lparameters toForm

Local lcStmt, lcSourceFile, lcMsg, lcTipoImport, lcErrDsc As String
Local lnRecCount, lnSkipped, lnNormalized, lnTotTime, lnErrNum As Integer
Local lnFileHandle, lnRet, lnCurDec As Integer
Local ltStartTime, ltEndTime As Datetime
Local llExit As Boolean

With toForm
	lcTipoImport	= .PF.pgGenerale.txtCd_xPreventivoImportTipo.Field.Value
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
		Cd_ARMarca 				C(20) ; && da 01  a 20  - Codice Marca
	,Cd_AR 					C(30)	; && da 21 	a 50  - Codice Articolo
	,Descrizione			C(80)	; && da 51 	a 130 - Descrizione
	,Quantita 				C(10)	; && da 131	a 140 - Quantità
	,CostoUnitarioV		C(15)	; && da 141	a 155 - Prezzo Unitario
	,CostoTotaleV			C(15)	; && da 156	a 170 - Prezzo Totale
	,UM 						C(3)	; && da 171	a 173 - Unità di Misura
	,RicavoUnitarioV		C(15))  && da 174	a 188	- Costo Unitario

	Select curMain
	Append From (lcSourceFile) Type Delimited With Character ";"

	* Cancellazione dati su tabella BLS xPreventivoImport
	* (vengono cancellati solo i records che riguardano la tipologia selezionata)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti per la tipologia di import " + lcTipoImport)
	xSqlExec("Delete From xPreventivoImport Where Cd_xPreventivoImportTipo = " + Format4Spt(lcTipoImport), , .T.)

	* Inserimento dati su tabella BLS xPreventivoImport
	Go Top In curMain
	Delete && Primo record (nomi campi).
	Delete For IsEmpty(Cd_AR) Or Len(Alltrim(Cd_AR)) > 20
	lnRecCount 	= Reccount('curMain')
	lnSkipped 	= 0
	.ProgBarShow(0, Reccount('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport)
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog('Normalizzazione tipologia di import ' + lcTipoImport) &&,,,,,, .T.

	Scan For !Deleted()
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport + ' ' + Transform(Recno('curMain')) + '/' + Transform(Reccount('curMain') - 1))

		TEXT TO lcStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int

			INSERT INTO [xPreventivoImport]
		           ([Cd_xPreventivoImportTipo]
		           ,[Cd_AR]
		           ,[Descrizione]
		           ,[UM]
		           ,[Quantita]
		           ,[CostoUnitarioV]
		           ,[RicavoUnitarioV]
		           ,[Cd_ARMarca])
		     VALUES
		           (<<Format4Spt(lcTipoImport)>>
		           ,<<Format4Spt(curMain.Cd_AR)>>
		           ,<<Format4Spt(curMain.Descrizione)>>
		           ,Null
		           ,<<Format4Spt(Val(CHRTRAN(curMain.Quantita, ',', '.')))>>
		           ,<<Format4Spt(Val(CHRTRAN(curMain.CostoUnitarioV, ',', '.')))>>
		           ,0
		           ,NullIf(<<Format4Spt(Nvl(curMain.Cd_ARMarca, ''))>>, ''))

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

		Righe Processate:	<< lnRecCount >>
		Righe Normalizzate:	<< lnNormalized >>
		Righe Saltate:	<< lnSkipped >>
		Tempo impiegato:	<< SecToHms(lnTotTime, 1) >>

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,, 'Courier New')

	If lnSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono state esluse " + Transform(lnSkipped) + " righe.",,,, oApp.ColorGridForeRed)
	Endif
Endwith

* ---------------------------------------------------------------
Function PR_GetVersion()
	Return "1.1 del 03-04-2012"
Endfunc
* ---------------------------------------------------------------
