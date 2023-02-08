Lparameters toForm

Local lcStmt, lcMsg, lcTipoImport, lcXlsFileName, lcErrDsc, lnRecCount, lnSkipped, lnNormalized, lnTotTime, lnFileHandle
Local lnRet, lnErrNum, lnRiga, llExit, oAtt

With toForm
	lcTipoImport	= .PF.pgGenerale.txtCd_xRDTicketAttivitaImportTipo.Field.Value
	lcXlsFileName 	= .PF.pgGenerale.txtDBFileName.Field.Value
	ltStartTime 	= Datetime()
	lnRecCount 		= 0

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
		lnRet = XLS_ImportData(lcXlsFileName, "[RDA$]", "datiXLS", , @lnErrNum, @lcErrDsc)
		llExit = lnRet < 0
	Endif

	*************************
	** Tracciato file XLS: **
	*************************
	** 		Cd_PRAttivita
	**		Descrizione

	If llExit
		xMessageBox('Ci sono problemi con la procedura di normalizzazione!' ;
			+ Chr(13) ;
			+ Chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	* Cancellazione dati su tabella BLS xRDTicketAttivitaImport
	* (vengono cancellati solo i records che riguardano la tipologia selezionata)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti per la tipologia di import " + lcTipoImport)
	xSqlExec("Delete From xRDTicketAttivitaImport Where Cd_xRDTicketAttivitaImportTipo = " + Format4Spt(lcTipoImport), , .T.)

	* Inserimento dati su tabella BLS xRDTicketAttivitaImport
	lnSkipped 	= 0
	.ProgBarShow(0, 10, 'Normalizzazione tipologia di import ' + lcTipoImport)
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog('Normalizzazione tipologia di import ' + lcTipoImport) &&,,,,,, .T.

	lnRiga = 0

	Select datiXLS
	Scan
		lnRecCount = lnRecCount + 1
		.ProgBarAdvance(lnRecCount, 'Normalizzazione tipologia di import ' + lcTipoImport)

		* Verifica se il codice attività esiste
		oAtt = xSqlExec2Obj("Select Cd_PRAttivita, Descrizione From PRAttivita Where Cd_PRAttivita = " + Format4Spt(datiXLS.Cd_PRAttivita))
		If IsEmpty(oAtt)
			lnSkipped = lnSkipped + 1
			Loop && Attività inesistente.
		Endif

		lnRiga = lnRiga + 1

		TEXT TO lcStmt TEXTMERGE NOSHOW
			declare @LastIdentity int
			declare @Descrizione varchar(80)
			set @Descrizione = case when isnull(<<Format4Spt(datiXLS.Descrizione)>>, '') = '' then <<Format4Spt(oAtt.Descrizione)>> else <<Format4Spt(datiXLS.Descrizione)>> end

			insert into xRDTicketAttivitaImport(
				Cd_xRDTicketAttivitaImportTipo
				, Riga
				, Cd_PRAttivita
				, Descrizione
				, Cd_ArItem
				, DescrizioneARItem
				, TipoVincolo
				, NumOrePrev
				, Riferimento
				, Ordine
			)
			values (
				<<Format4Spt(lcTipoImport)>>
				, <<Format4Spt(lnRiga)>>
				, <<Format4Spt(oAtt.Cd_PRAttivita)>>
				, @Descrizione
				, null
				, null
				, 0
				, null
				, null
				, null
			)

			if @@ROWCOUNT > 0
				set @LastIdentity = SCOPE_IDENTITY()
			else
				set @LastIdentity = 0

			select @LastIdentity as NewId
		ENDTEXT

		** _cliptext = lcstmt

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

	Use In datiXLS

	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.ProgBarHide()

	ltEndTime 		= Datetime()
	lnNormalized 	= lnRecCount - lnSkipped
	lnTotTime 		= ltEndTime - ltStartTime

	TEXT To lcMsg TextMerge NoShow Pretext 3

		Attività Processate:	<< lnRecCount >>
		Attività Normalizzate:	<< lnNormalized >>
		Attività Escluse:		<< lnSkipped >>
		Tempo impiegato:		<< SecToHms(lnTotTime, 1) >>

	ENDTEXT

	.PF.pgNormalizzazione.edtLog.WriteLog(lcMsg,,, 'Courier New')

	If lnSkipped = 0
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata con successo alle " + Ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
	Else
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Normalizzazione terminata.",,,, oApp.ColorGridForeRed)
		.PF.pgNormalizzazione.edtLog.WriteLog(Chr(13) + "Sono state esluse " + Transform(lnSkipped) + " attività.",,,, oApp.ColorGridForeRed)
	Endif

Endwith

* ---------------------------------------------------------------
Function RDA_GetVersion()
	Return "1.0 del 24-06-2021"
Endfunc
* ---------------------------------------------------------------
