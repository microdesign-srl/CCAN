Lparameters toForm

Local lcStmt, lcMsg, lcTipoImport, lcXlsFileName, lcErrDsc, lcCd_xOperatore As String
Local lnRecCount, lnRecNo, lnSkipped, lnNormalized, lnTotTime As Integer
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
		lcMsg = "Ci sono problemi con l'apertura del file XLS !!"
	Else
		Fclose(lnFileHandle)
		Use In (Select('curMain'))
		lnRet = XLS_ImportData(lcXlsFileName, "[Worksheet$]", "datiXLS", , @lnErrNum, @lcErrDsc)
		llExit = lnRet < 0
		lcMsg = lcErrDsc
	Endif

	If llExit
		xMessageBox(lcMsg + Chr(13) + Chr(13) + 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	Select datiXLS
	Go Top

	Do Case
		Case 	Vartype(datiXLS.Classe_A) == 'N' And Vartype(datiXLS.Classe_B) == 'N'

			Select Alltrim(Str(Classe_A)) As Cd_DOSottoCommessa, Alltrim(Str(Classe_B)) As Cd_PrAttivita, ;
				Space(20) As Cd_PrRisorsa, Matricola As NumeroMatricola, Space(20) As Cd_xOperatore, ;
				Giorno As DataInizio, Giorno As DataFine, Nvl(Pres_, Ecc_) As Cd_xRDTipoVal, Durcen_ As Durata ;
				From datiXLS Into Cursor curMain Readwrite ;
				Where !IsEmpty(Classe_A) And !IsEmpty(Classe_B) And !IsEmpty(Matricola) And !IsEmpty(Giorno) ;
				And (!IsEmpty(Pres_) Or !IsEmpty(Ecc_))

		Case 	Vartype(datiXLS.Classe_A) == 'N' And Vartype(datiXLS.Classe_B) == 'C'

			Select Alltrim(Str(Classe_A)) As Cd_DOSottoCommessa, Alltrim(Classe_B) As Cd_PrAttivita, ;
				Space(20) As Cd_PrRisorsa, Matricola As NumeroMatricola, Space(20) As Cd_xOperatore, ;
				Giorno As DataInizio, Giorno As DataFine, Nvl(Pres_, Ecc_) As Cd_xRDTipoVal, Durcen_ As Durata ;
				From datiXLS Into Cursor curMain Readwrite ;
				Where !IsEmpty(Classe_A) And !IsEmpty(Classe_B) And !IsEmpty(Matricola) And !IsEmpty(Giorno) ;
				And (!IsEmpty(Pres_) Or !IsEmpty(Ecc_))

		Case 	Vartype(datiXLS.Classe_A) == 'C' And Vartype(datiXLS.Classe_B) == 'N'

			Select Alltrim(Classe_A) As Cd_DOSottoCommessa, Alltrim(Str(Classe_B)) As Cd_PrAttivita, ;
				Space(20) As Cd_PrRisorsa, Matricola As NumeroMatricola, Space(20) As Cd_xOperatore, ;
				Giorno As DataInizio, Giorno As DataFine, Nvl(Pres_, Ecc_) As Cd_xRDTipoVal, Durcen_ As Durata ;
				From datiXLS Into Cursor curMain Readwrite ;
				Where !IsEmpty(Classe_A) And !IsEmpty(Classe_B) And !IsEmpty(Matricola) And !IsEmpty(Giorno) ;
				And (!IsEmpty(Pres_) Or !IsEmpty(Ecc_))

		Case 	Vartype(datiXLS.Classe_A) == 'C' And Vartype(datiXLS.Classe_B) == 'C'

			Select Alltrim(Classe_A) As Cd_DOSottoCommessa, Alltrim(Classe_B) As Cd_PrAttivita, ;
				Space(20) As Cd_PrRisorsa, Matricola As NumeroMatricola, Space(20) As Cd_xOperatore, ;
				Giorno As DataInizio, Giorno As DataFine, Nvl(Pres_, Ecc_) As Cd_xRDTipoVal, Durcen_ As Durata ;
				From datiXLS Into Cursor curMain Readwrite ;
				Where !IsEmpty(Classe_A) And !IsEmpty(Classe_B) And !IsEmpty(Matricola) And !IsEmpty(Giorno) ;
				And (!IsEmpty(Pres_) Or !IsEmpty(Ecc_))
	Endcase

	* Compilo il campo Cd_PrRisorsa
	Select curMain

	Scan
		TEXT TO lcStmt NOSHOW TEXTMERGE
			Declare @Cd_PrRisorsa As Varchar(20)
			Declare @Gruppo As Bit

			Select @Cd_PrRisorsa = A.Cd_PrRisorsa, @Gruppo = R.Gruppo
			 From PRAttivita A Inner Join PRRisorsa R On A.Cd_PrRisorsa = R.Cd_PrRisorsa
			 Where A.Cd_PrAttivita = <<Format4Spt(curMain.Cd_PRAttivita)>>

			If @Gruppo = 1
				Begin
					Select @Cd_PrRisorsa = Cd_PrRisorsa_C
					 From PRRisorsaLink
					 Where Cd_PrRisorsa_P = @Cd_PrRisorsa And Sequenza = 1
				End

			Select @Cd_PrRisorsa
		ENDTEXT

		Replace Cd_PrRisorsa With Nvl(xSqlExec2Var(lcStmt), '') In curMain
	Endscan

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
		lnRecNo = Recno('curMain')
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport + ' ' + Transform(lnRecNo) + '/' + Transform(lnRecCount - 1))

		* Ricerca il ticket associato alla sottocommessa
		lnId_xRDTicket = xSqlExec2Var("Select Top 1 Id_xRDTicket From xRDTicket Where (GestisciTicket = 0) And Cd_DOSottocommessa = " + Format4Spt(curMain.Cd_DOSottoCommessa))

		If IsEmpty(lnId_xRDTicket)
			lnSkipped = lnSkipped + 1
			Loop && Ticket non associato a commessa.
		Endif

		* Verifica se il codice operatore esiste
		* [Top 1 con Order By ID x prendere il primo operatore a cui è stata assegnata quella matricola nel caso la stessa matricola fosse erroneamente assegnata a più operatori.]
		lcCd_xOperatore = xSqlExec2Var("Select Top 1 Cd_xOperatore From xOperatore Where NumeroMatricola = " + Format4Spt(curMain.NumeroMatricola) + " Order By Id_xOperatore")
		If IsEmpty(lcCd_xOperatore)
			lnSkipped = lnSkipped + 1
			Loop && Operatore inesistente.
		Else
			Replace Cd_xOperatore With lcCd_xOperatore In curMain
		Endif

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
							INSERT INTO xRDTicketAttivitaOperatore (Id_xRDTicketAttivita, CD_xOperatore, Descrizione, Riga, RigaPadre)
							VALUES (@Id_xRDTicketAttivita, <<Format4Spt(curMain.Cd_xOperatore)>>, @Descrizione_Op, 1, @Riga)
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
			xMessageBox(Alltrim(oApp.oSqlConn.LastErrorMsg) ;
				+ Chr(13) ;
				+ 'problemi con la procedura di normalizzazione!' ;
				+ Chr(13) ;
				+ Chr(13) ;
				+ 'Impossibile continuare.', 16, 'Normalizzazione riga ' + Transform(lnRecNo))
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
	Return "1.3 del 26-03-2014"
Endfunc
* ---------------------------------------------------------------
