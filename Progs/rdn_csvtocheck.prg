Lparameters toForm

Local lcStmt, lcMsg, lcTipoImport, lcCsvFileName, lcErrDsc, lcCd_xOperatore, lcHead4CCALog, lcExpr4CCALog As String
Local lnRecCount, lnRecNo, lnSkipped, lnNormalized, lnTotTime As Integer
Local lnFileHandle, lnRet, lnErrNum, lnId_xRDTicket, lnId_xRDTicketAttivita As Integer
Local llExit As Boolean

With toForm
	lcTipoImport	= .PF.pgGenerale.txtCd_xRDImportTipo.Field.Value
	lcCsvFileName 	= .PF.pgGenerale.txtDBFileName.Field.Value
	ltStartTime 	= Datetime()

	* Log CCA
	oCCA.Log_Create(lcTipoImport, Juststem(lcCsvFileName))
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	oCCA.Log_Write("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(ltStartTime))
	oCCA.Log_Write("Inizio normalizzazione: " + Ttoc(ltStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	oCCA.Log_Write("")

	* Verifica se si è scelto un corretto file di import
	llExit = .F.
	lnFileHandle = Fopen(lcCsvFileName)
	If lnFileHandle < 0
		llExit = .T.
	Else
		Fclose(lnFileHandle)
	Endif

	If llExit
		xMessageBox("Ci sono problemi con l'apertura del file CSV !!" ;
			+ Chr(13) ;
			+ Chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	Use In (Select('curMain'))
	Use In (Select('curTemp'))

	Create Cursor curTemp ( ;
		Triade 					C(10) ; && da 01  a 10  - Triade
	,Matricola				C(10)	; && da 11 	a 20  - Matricola
	,Cognome			      C(20)	; && da 21 	a 40  - Cognome
	,Nome			         C(20)	; && da 41 	a 60  - Nome
	,Giorno		         C(10)	; && da 61 	a 70  - Giorno
	,Dalle               C(5)  ; && da 71 	a 75  - Dalle
	,Alle                C(5)  ; && da 76 	a 80  - Alle
	,Durata              C(5)  ; && da 81 	a 85  - Durata
	,Durcen_             C(5)  ; && da 86 	a 90  - Durcen
	,Pres_               C(5)  ; && da 91 	a 95  - Pres
	,Ecc_                C(5)  ; && da 96 	a 100 - Ecc
	,Classe_A  				C(20)	; && da 101	a 120 - ClasseA
	,Classe_B	   		C(20)	; && da 121	a 140 - ClasseB
	,Classe_C 			   C(20)	; && da 141	a 160 - ClasseC
	,DescriA 			   C(20)	; && da 161	a 180 - DescriA
	,DescriB 			   C(20)	; && da 181	a 200 - DescriB
	,DescriC 			   C(20) ) && da 201	a 221 - DescriC

	Select curTemp
	Append From (lcCsvFileName) Type Delimited With Character ";"

	* Creo il cursore curMain da curTemp, rinominando alcuni campi, aggiungendone altri ed escludendone alcuni.
	Select Alltrim(Classe_A) As Cd_DOSottoCommessa, Alltrim(Classe_B) As Cd_PrAttivita, ;
		Space(20) As Cd_PrRisorsa, Transform(Val(Matricola)) As NumeroMatricola, Space(20) As Cd_xOperatore, ;
		Giorno As DataInizio, Giorno As DataFine, Iif(IsEmpty(Pres_), Ecc_, Pres_) As Cd_xRDTipoVal, Val(Chrtran(Alltrim(Durcen_), ',', '.')) As Durata ;
		From curTemp Into Cursor curMain Readwrite ;
		Where !IsEmpty(Classe_A) And !IsEmpty(Classe_B) And !IsEmpty(Matricola) And !IsEmpty(Giorno) ;
		And (!IsEmpty(Pres_) Or !IsEmpty(Ecc_))

	* Compilo il campo Cd_PrRisorsa
	Use In curTemp
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
	oCCA.Log_Write("Cancellazione records presenti per la tipologia di import " + lcTipoImport)
	xSqlExec("Delete From xRDImport Where Cd_xRDImportTipo = " + Format4Spt(lcTipoImport), , .T.)

	* Inserimento dati su tabella BLS xRDImport
	Go Top In curMain
	lnRecCount 	= Reccount('curMain')
	lnSkipped 	= 0
	.ProgBarShow(0, Reccount('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport)
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	oCCA.Log_Write("OK!")
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	oCCA.Log_Write("")
	.PF.pgNormalizzazione.edtLog.WriteLog('Normalizzazione tipologia di import ' + lcTipoImport) &&,,,,,, .T.
	oCCA.Log_Write("Normalizzazione tipologia di import " + lcTipoImport)
	oCCA.Log_Write("")

	Scan
		lnRecNo = Recno('curMain')
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione tipologia di import ' + lcTipoImport + ' ' + Transform(lnRecNo) + '/' + Transform(lnRecCount - 1))

		* Log CCA
		lcHead4CCALog = "Motivo dell'esclusione - Sottocommessa;Attività;Risorsa;Matricola;DataInizio;DataFine;TipoVal;Durata;"
		lcExpr4CCALog = '"' + Alltrim(curMain.Cd_DOSottoCommessa) + '";' ;
			+ '"' + Alltrim(curMain.Cd_PrAttivita)   + '";' ;
			+ '"' + Alltrim(curMain.Cd_PrRisorsa)    + '";' ;
			+ '"' + Alltrim(curMain.NumeroMatricola) + '";' ;
			+ '"' + Alltrim(curMain.DataInizio)      + '";' ;
			+ '"' + Alltrim(curMain.DataFine)        + '";' ;
			+ '"' + Alltrim(curMain.Cd_xRDTipoVal)   + '";' ;
			+ '"' + Transform(curMain.Durata)        + '";'

		* Ricerca il ticket associato alla sottocommessa
		lnId_xRDTicket = xSqlExec2Var("Select Top 1 Id_xRDTicket From xRDTicket Where (GestisciTicket = 0) And Cd_DOSottocommessa = " + Format4Spt(curMain.Cd_DOSottoCommessa))

		If IsEmpty(lnId_xRDTicket)
			lnSkipped = lnSkipped + 1
			If lnSkipped = 1
				oCCA.Log_Write(lcHead4CCALog)
				oCCA.Log_Write("")
			Endif
			oCCA.Log_Write("Nessun Ticket associato alla Commessa.", lcExpr4CCALog)
			Loop && Ticket non associato a commessa.
		Endif

		* Verifica se il codice operatore esiste
		* [Top 1 con Order By ID x prendere il primo operatore a cui è stata assegnata quella matricola nel caso la stessa matricola fosse erroneamente assegnata a più operatori.]
		lcCd_xOperatore = xSqlExec2Var("Select Top 1 Cd_xOperatore From xOperatore Where NumeroMatricola = " + Format4Spt(curMain.NumeroMatricola) + " Order By Id_xOperatore")
		If IsEmpty(lcCd_xOperatore)
			lnSkipped = lnSkipped + 1
			If lnSkipped = 1
				oCCA.Log_Write(lcHead4CCALog)
				oCCA.Log_Write("")
			Endif
			oCCA.Log_Write("Nessun Operatore associato alla Matricola.", lcExpr4CCALog)
			Loop && Operatore inesistente.
		Else
			Replace Cd_xOperatore With lcCd_xOperatore In curMain
		Endif

		* Verifica se il codice attività esiste
		If Nvl(xSqlExec2Var("Select COUNT(*) From PRAttivita Where Cd_PRAttivita = " + Format4Spt(curMain.Cd_PrAttivita)), 0) = 0
			lnSkipped = lnSkipped + 1
			If lnSkipped = 1
				oCCA.Log_Write(lcHead4CCALog)
				oCCA.Log_Write("")
			Endif
			oCCA.Log_Write("Codice Attività inesistente.", lcExpr4CCALog)
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
				+ Chr(13) ;
				+ 'Impossibile continuare.', 16, 'Normalizzazione riga ' + Transform(lnRecNo))
			oCCA.Log_Write(Alltrim(oApp.oSqlConn.LastErrorMsg), lcExpr4CCALog)
			oCCA.Log_Write("Impossibile continuare.")
			toForm.CmdExit()
			Return .F.
		Else
			lnSkipped = lnSkipped + Iif(Inserted.NewId = 0, 1, 0)
		Endif
	Endscan

	Use In curMain

	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	oCCA.Log_Write("")
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
	oCCA.Log_Write(lcMsg)

	If lnSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
		oCCA.Log_Write("")
		oCCA.Log_Write("Normalizzazione terminata con successo alle " + Ttoc(ltEndTime))
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		oCCA.Log_Write("")
		oCCA.Log_Write("Normalizzazione terminata.")
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono state esluse " + Transform(lnSkipped) + " rilevazioni.",,,, oApp.ColorGridForeRed)
		oCCA.Log_Write("")
		oCCA.Log_Write("Sono state esluse " + Transform(lnSkipped) + " rilevazioni.")
	Endif

	TEXT To lcMsg TextMerge NoShow Pretext 3

		Avanzando, verrà instanziato il wizard di Inserimento Rilevazioni
		dove saranno riportate tutte le rilevazioni normalizzate.

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,,,,,.T.,.T.)

	* Log CCA
	oCCA.Log_Save()
Endwith

* ---------------------------------------------------------------
Function RD_GetVersion()
	Return "1.0 del 23-04-2014"
Endfunc
* ---------------------------------------------------------------
