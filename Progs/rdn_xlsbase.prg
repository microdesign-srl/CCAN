Lparameters toForm

Local lcStmt, lcMsg, lcTipoImport, lcXlsFileName, lcErrDsc As String
Local lnRecCount, lnSkipped, lnNormalized, lnTotTime As Integer
Local lnFileHandle, lnRet, lnErrNum, lnId_xRDTicket, lnId_xRDTicketAttivita As Integer
Local llExit As Boolean

With toForm
	lcTipoImport	= .PF.pgGenerale.txtCd_xRDImportTipo.Field.Value
	lcXlsFileName 	= .PF.pgGenerale.txtDBFileName.Field.Value
	ltStartTime 	= Datetime()

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(ltStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	* Verifica se si è scelto un corretto file di import
	llExit = .F.
	lnFileHandle = Fopen(lcXlsFileName)
	If lnFileHandle < 0
		llExit = .T.
	Else
		Fclose(lnFileHandle)
		Use In (Select('curMain'))
		lnRet = XLS_ImportData(lcXlsFileName, "[MRO$]", "datiXLS", , @lnErrNum, @lcErrDsc)
		llExit = lnRet < 0
	Endif

	If llExit
		xMessageBox('Ci sono problemi con la procedura di normalizzazione!' ;
			+ Chr(13) ;
			+ Chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	Select	Codice_Commessa As Cd_DOSottoCommessa, ;
		Identificativo_Attività As Cd_PrAttivita, ;
		Codice_Risorsa As Cd_PrRisorsa, ;
		Codice_Operatore As Cd_xOperatore	, ;
		Data As DataInizio, Data As DataFine, ;
		Tipo_Valorizzazione As Cd_xRDTipoVal, ;
		Nr_Ore As Durata ;
		From datiXLS ;
		INTO Cursor curMain Readwrite ;
		WHERE !IsEmpty(Codice_Commessa) ;
		AND !IsEmpty(Identificativo_Attività) ;
		AND !IsEmpty(Codice_Risorsa) ;
		AND !IsEmpty(Codice_Operatore) ;
		AND !IsEmpty(Data) ;
		AND !IsEmpty(Tipo_Valorizzazione)

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

		* Ricerca il ticket associato alla sottocommessa
		lnId_xRDTicket = xSqlExec2Var("Select Top 1 Id_xRDTicket From xRDTicket Where Cd_DOSottocommessa = " + Format4Spt(curMain.Cd_DOSottoCommessa))

		If IsEmpty(lnId_xRDTicket)
			lnSkipped = lnSkipped + 1
			Loop && Ticket non associato a commessa.
		Endif

		* Verifica se il codice operatore esiste
		IF Nvl(xSqlExec2Var("Select COUNT(*) From xOperatore Where Cd_xOperatore = " + Format4Spt(curMain.Cd_xOperatore)), 0) = 0
			lnSkipped = lnSkipped + 1
			Loop && Operatore inesistente.
		ENDIF 

		* Verifica se il codice attività esiste
		If Nvl(xSqlExec2Var("Select COUNT(*) From PRAttivita Where Cd_PRAttivita = " + Format4Spt(curMain.Cd_PrAttivita)), 0) = 0
			lnSkipped = lnSkipped + 1
			Loop && Attività inesistente.
		Else
			* Ricerca l'attività associata al ticket
			lnId_xRDTicketAttivita = xSqlExec2Var("Select Top 1 Id_xRDTicketAttivita From xRDTicketAttivita Where Id_xRDTicket = " + Format4Spt(lnId_xRDTicket) ;
				+ " And Cd_PRAttivita = " + Format4Spt(curMain.Cd_PrAttivita))
			If IsEmpty(lnId_xRDTicketAttivita)
				&& Inserisco la nuova attività per il ticket
				** Recupero il numero massimo di riga per le attivita per inserire la nuova
				TEXT TO lcStmt TEXTMERGE NOSHOW
					DECLARE @Riga As Integer
					DECLARE @Descrizione As VarChar(80)
					DECLARE @Descrizione_Op As VarChar(80)
					DECLARE @Id_xRDTicketAttivita As Integer

					SELECT @Riga = ISNULL(MAX(Riga), 0) FROM xRDTicketAttivita WHERE Id_xRDTicket = <<Format4Spt(lnId_xRDTicket)>>
					SET @Riga = @Riga + 1

					SELECT @Descrizione = Descrizione FROM PRAttivita WHERE Cd_PRAttivita = <<Format4Spt(curMain.Cd_PrAttivita)>>
					SELECT @Descrizione_Op = Descrizione FROM xOperatore WHERE Cd_xOperatore = <<Format4Spt(curMain.Cd_xOperatore)>>

					INSERT INTO xRDTicketAttivita (Id_xRDTicket, CD_PRAttivita, Descrizione, Riga, DataApertura)
					VALUES (<<Format4Spt(lnId_xRDTicket)>>, <<Format4Spt(curMain.Cd_PrAttivita)>>, @Descrizione, @Riga, GetDate())
					
					Select @Id_xRDTicketAttivita = SCOPE_IDENTITY()
					IF @Id_xRDTicketAttivita > 0
						BEGIN
							INSERT INTO xRDTicketAttivitaOperatore (Id_xRDTicketAttivita, CD_xOperatore, Descrizione, Riga, RigaPadre, Confermato, Durata)
							VALUES (@Id_xRDTicketAttivita, <<Format4Spt(curMain.Cd_xOperatore)>>, @Descrizione_Op, 1, @Riga, 1, 0)
						END
								
					Select @Id_xRDTicketAttivita
				ENDTEXT
				lnId_xRDTicketAttivita = xSqlExec2Var(lcStmt)
			Endif
		Endif

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
		           ,[Cd_xRDTipoValorizzazione]
		           ,[DataInizio]
		           ,[DataFine]
		           ,[Durata])
		     VALUES
		           (<<Format4Spt(lcTipoImport)>>
		           ,<<Format4Spt(lnId_xRDTicket)>>
		           ,<<Format4Spt(curMain.Cd_DOSottoCommessa)>>
		           ,<<Format4Spt(lnId_xRDTicketAttivita)>>
		           ,<<Format4Spt(curMain.Cd_PrAttivita)>>
		           ,<<Format4Spt(curMain.Cd_PRRisorsa)>>
		           ,<<Format4Spt(curMain.Cd_xOperatore)>>
		           ,<<Format4Spt(curMain.Cd_xRDTipoVal)>>
		           ,<<Format4Spt(curMain.DataInizio)>>
		           ,<<Format4Spt(curMain.DataFine)>>
		           ,<<Format4Spt(curMain.Durata)>>)

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
	Return "1.0 del 16-04-2012"
Endfunc
* ---------------------------------------------------------------
