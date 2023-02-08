Lparameters toForm

Local cStmt, cMsg, cTipoImport, cXlsFileName, cErrDsc, cLogExpr, cCd_CF, cCd_AR As String
Local nRecCount, nSkipped, nNormalized, nTotTime, nFileHandle, nRet, nErrNum As Integer
Local dDataLettura As Date
Local tStartTime, tEndTime As Datetime
Local lExit As Boolean

With toForm
	cTipoImport  = Alltrim(.PF.pgGenerale.txtCd_xContatoreLetturaImportTipo.Field.Value)
	cXlsFileName = .PF.pgGenerale.txtDBFileName.Field.Value
	tStartTime   = Datetime()

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(tStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	* Apertura file di import e selezione dati iniziale
	.PF.pgNormalizzazione.edtLog.WriteLog("Apertura file di import e selezione dati iniziale")

	* Verifica se si è scelto un corretto file di import
	lExit = .F.
	nFileHandle = Fopen(cXlsFileName)

	If nFileHandle < 0
		lExit = .T.
	Else
		Fclose(nFileHandle)
		Use In (Select('curMain'))
		nRet = XLS_ImportData(cXlsFileName, "[sheet1$]", "datiXLS", , @nErrNum, @cErrDsc)
		lExit = nRet < 0
	Endif

	If lExit
		xMessageBox('Ci sono problemi con la procedura di normalizzazione!' + Chr(13) + Chr(13) + 'Impossibile continuare.', 16, 'IMPORT LETTURE - NORMALIZZAZIONE DATI')
		toForm.CmdExit()
		Return .F.
	Endif

	Select	Cliente As Cd_CF, ;
		Serial_number As Cd_xMatricola, ;
		Ttod(Data_lettura) As DataLettura, ;
		Int(Val(TRANSFORM(Contatore_mono_fine_periodo))) As Lettura_C1, ;
		Int(Val(TRANSFORM(Contatore_colore_fine_periodo))) As Lettura_C2 ;
		From datiXLS ;
		Into Cursor curMain Readwrite ;
		Where !IsEmpty(Cliente) ;
		And !IsEmpty(Serial_number) ;
		And !IsEmpty(Data_lettura)

	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	* Cancellazione dati su tabella BLS xContatoreLetturaImport
	* (vengono cancellati solo i records che riguardano la tipologia selezionata)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti per la tipologia di import " + cTipoImport)
	cStmt = "Delete From xContatoreLetturaImport Where Cd_xContatoreLetturaImportTipo = " + Format4Spt(cTipoImport)
	If xSqlExec(cStmt, , .T.) < 0
		xMessageBox('Error : ' + Transform(oApp.oSqlConn.LastErrorCode(1)) + Chr(13) + oApp.oSqlConn.LastErrorMsg(1) + Chr(13) + Chr(13) + 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	* Inserimento dati su tabella BLS xContatoreLetturaImport
	Go Top In curMain
	nRecCount 	= Reccount('curMain')
	nSkipped 	= 0
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	.ProgBarShow(0, Reccount('curMain'), 'Normalizzazione dati tipologia di import ' + cTipoImport)
	.PF.pgNormalizzazione.edtLog.WriteLog('Normalizzazione dati tipologia di import ' + cTipoImport) &&,,,,,, .T.

	* Log CCA
	oCCA.Log_Create(Alltrim(Evaluate(.PF.pgGenerale.txtCd_xContatoreLetturaImportTipo.Field.FKAlias +'.FileProcedura')), Juststem(cXlsFileName))
	oCCA.Log_Write("")
	oCCA.Log_Write("Motivo dell'esclusione - Cliente;Matricola;DataLettura;")
	oCCA.Log_Write("")

	Use In datiXLS
	Select curMain

	Scan
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione tipologia di import ' + cTipoImport + ' ' + Transform(Recno('curMain')) + '/' + Transform(Reccount('curMain') - 1))

		cLogExpr = '"' + Alltrim(curMain.Cd_CF) + '";' + '"' + Alltrim(curMain.Cd_xMatricola)   + '";' + '"' + Dtoc(curMain.DataLettura)    + '";'

		* Verifica se il cliente esiste (test su codice e descrizione)
		TEXT TO cStmt NOSHOW TEXTMERGE
     Select Top 1 Cd_CF From (Select Cd_CF from CF Where Cd_CF = <<Format4Spt(curMain.Cd_CF)>> Union Select '' As Cd_CF) A Order By Cd_CF Desc
		ENDTEXT

		cCd_CF = Alltrim(xSqlExec2Var(cStmt))

		If Len(cCd_CF) < 7
			TEXT TO cStmt NOSHOW TEXTMERGE
       Select Top 1 Cd_CF From (Select Cd_CF from CF Where Descrizione Like <<Format4Spt(curMain.Cd_CF + '%')>> Union Select '' As Cd_CF) A Order By Cd_CF Desc
			ENDTEXT

			cCd_CF = Alltrim(xSqlExec2Var(cStmt))

			If Len(cCd_CF) < 7
				nSkipped = nSkipped + 1
				oCCA.Log_Write("Cliente inesistente", cLogExpr)
				Loop && Cliente inesistente.
			Endif
		Endif

		* Verifica se la matricola esiste e ne recupera l'articolo (top 1 order by cd_ar desc)
		TEXT TO cStmt NOSHOW TEXTMERGE
     Select Top 1 Cd_AR From (Select Cd_AR from xMatricola Where Noleggio = 1 And Cd_xMatricola = <<Format4Spt(curMain.Cd_xMatricola)>> Union Select '' As Cd_AR) A Order By Cd_AR Desc
		ENDTEXT

		cCd_AR = Alltrim(xSqlExec2Var(cStmt))

		If Len(cCd_AR) = 0
			nSkipped = nSkipped + 1
			oCCA.Log_Write("Matricola inesistente", cLogExpr)
			Loop && Matricola inesistente.
		Endif

		* Verifica se la data lettura è valida
		Try
			dDataLettura = Date(Year(curMain.DataLettura), Month(curMain.DataLettura), Day(curMain.DataLettura))
		Catch
			nSkipped = nSkipped + 1
			oCCA.Log_Write("Data lettura non valida", cLogExpr)
			Loop && Data lettura non valida.
		Endtry

		* Verifica se le letture sono valori > 0
		If curMain.Lettura_C1 <= 0
			nSkipped = nSkipped + 1
			oCCA.Log_Write("Lettura contatore 1 non valida", cLogExpr)
			Loop && Lettura contatore 1 non valida.
		Endif

		If curMain.Lettura_C2 <= 0
			nSkipped = nSkipped + 1
			oCCA.Log_Write("Lettura contatore 2 non valida", cLogExpr)
			Loop && Lettura contatore 2 non valida.
		Endif

		* Inserimento nuova lettura
		TEXT TO cStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int

			Insert Into [dbo].[xContatoreLetturaImport]
			  ([Cd_xContatoreLetturaImportTipo]
			  ,[Cd_AR],[Cd_xMatricola],[Cd_xImpianto],[Cd_CF],[Cd_CFDest],[DataLettura]
			  ,[Lettura_C1],[Lettura_C2],[Lettura_C3],[Lettura_C4],[Lettura_C5],[Lettura_C6])
			Values
			  (<<Format4Spt(cTipoImport)>>
			  ,<<Format4Spt(cCd_AR)>>,<<Format4Spt(curMain.Cd_xMatricola)>>,Null,<<Format4Spt(cCd_CF)>>,Null,<<Format4Spt(dDataLettura)>>
			  ,<<Format4Spt(curMain.Lettura_C1)>>,<<Format4Spt(curMain.Lettura_C2)>>,0,0,0,0)
	    If @@ROWCOUNT > 0
				Set @LastIdentity = SCOPE_IDENTITY()
			Else
				Set @LastIdentity = 0

			Select @LastIdentity AS NewId
		ENDTEXT

		If xSqlExec(cStmt, 'Inserted', .T.) < 0
			xMessageBox('Error : ' + Transform(oApp.oSqlConn.LastErrorCode(1)) + Chr(13) + oApp.oSqlConn.LastErrorMsg(1) + Chr(13) + Chr(13) + 'Impossibile continuare.', 16)
			toForm.CmdExit()
			Return .F.
		Else
			nSkipped = nSkipped + Iif(Inserted.NewId = 0, 1, 0)
			Use In Inserted
		Endif
	Endscan

	Use In curMain

	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.ProgBarHide()

	tEndTime 	  = Datetime()
	nNormalized = nRecCount - nSkipped
	nTotTime 		= tEndTime - tStartTime

	TEXT To cMsg TextMerge NoShow Pretext 3

		Letture Processate:		<< nRecCount >>
		Letture Normalizzate:	<< nNormalized >>
		Letture Saltate:		<< nSkipped >>
		Tempo impiegato:		<< SecToHms(nTotTime, 1) >>

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog(cMsg,,, 'Courier New')
	oCCA.Log_Write("")
	oCCA.Log_Write(cMsg)

	If nSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(tEndTime),,,, oApp.ColorGridForeBlu)
		oCCA.Log_Write("")
		oCCA.Log_Write("Normalizzazione terminata con successo alle " + Ttoc(tEndTime))
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		oCCA.Log_Write("")
		oCCA.Log_Write("Normalizzazione terminata.")
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono state esluse " + Transform(nSkipped) + " letture.",,,, oApp.ColorGridForeRed)
		oCCA.Log_Write("")
		oCCA.Log_Write("Sono state esluse " + Transform(nSkipped) + " letture.")
	Endif

	* Log CCA
	oCCA.Log_Save()
Endwith

* ---------------------------------------------------------------
Function CLN_GetVersion()
	Return "1.0 del 10-05-2016"
Endfunc
* ---------------------------------------------------------------
