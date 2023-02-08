Lparameters toForm

Local lcStmt 				As String
Local lnRecCount 			As Integer
Local lnSkipped 			As Integer
Local lnNormalized		As Integer
Local cXlsFileName 		As String
Local cCd_xLS				As String
Local ltStartTime 		As Datetime
Local ltEndTime 			As Datetime
Local lnTotTime 			As Integer
Local lcMsg 				As String
Local lcStr 				As String
Local lnFileHandle 		As Integer
Local llExit 				As Boolean
Local lnPrezzoAcquisto 	As Double
Local lnPrezzoVendita 	As Double
Local lnErrNum				As Integer
Local lcErrDsc				As String

With toForm
	cXlsFileName 	= .PF.pgGenerale.txtDBFileName.Field.Value
	cCd_xLS			= .PF.pgGenerale.txtCd_xLS.Field.Value
	ltStartTime = Datetime()

	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Inizio normalizzazione: " + Ttoc(ltStartTime))
	.PF.pgNormalizzazione.edtLog.WriteLog("")

	* Verifica se si è scelto un corretto file di import
	llExit = .F.
	lnFileHandle = Fopen(cXlsFileName)
	If lnFileHandle < 0
		llExit = .T.
	Else
		Fclose(lnFileHandle)
		Use In (Select('curMain'))
		lnRet = XLS_ImportData(cXlsFileName, "[SIELSP$]", "datiXLS", , @lnErrNum, @lcErrDsc)
		llExit = lnRet < 0
	Endif

	If llExit
		xMessageBox('Il file di import non è un file SIEMENS oppure ci sono' ;
			+ Chr(13) ;
			+ 'problemi con la procedura di normalizzazione!' ;
			+ Chr(13) ;
			+ Chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		Return .F.
	Endif

	***********************************************************************************
	* 15-02-2013:
	*  1) indicazione ed esclusione degli articoli duplicati nel file di import
	*  2) indicazione ed esclusione delle righe se i campi di tipo codice eccedono
	*     la lunghezza disponibile nel gestionale
	* ---------------------------------------------------------------------------------
	Create Cursor curAppoggio (		;
		Codice_Ordinazione C(100)	 	 ;
		,Descrizione C(254)		NOT NULL ;
		,Prezzo_Pubblico__ B(6)	NULL	 ;
		,Sconto C(20)	 		NULL	 ;
		,Note M					NULL	 ;
		,Marca C(100) 			NULL	 )

	Select curAppoggio
	Append From Dbf('datiXLS')
	Use In datiXLS

	Select A.Codice_Ordinazione, B.Descrizione From ( ;
		Select Codice_Ordinazione, Count(*) As NVolte From curAppoggio Group By Codice_Ordinazione ;
		) A Inner Join curAppoggio As B On A.Codice_Ordinazione = B.Codice_Ordinazione ;
		Into Cursor curDuplicati ;
		Where A.NVolte > 1

	If Reccount('curDuplicati') > 0
		.PF.pgNormalizzazione.edtLog.WriteLog("Articoli esclusi perchè duplicati nel file di import:",,,,oApp.ColorGridForeRed)
		*.PF.pgNormalizzazione.edtLog.WriteLog("")
		Select curDuplicati
		Scan
			.PF.pgNormalizzazione.edtLog.WriteLog(" " + Alltrim(curDuplicati.Codice_Ordinazione) + ;
				" - " + curDuplicati.Descrizione,,,,oApp.ColorGridForeRed,,, .T.)
		Endscan
		.PF.pgNormalizzazione.edtLog.WriteLog("")
	Endif

	Select Codice_Ordinazione, Descrizione, Marca ;
		From curAppoggio ;
		Into Cursor curEccedenze ;
		Where Len(Alltrim(Codice_Ordinazione)) > 20 Or Len(Alltrim(Marca)) > 20

	If Reccount('curEccedenze') > 0
		.PF.pgNormalizzazione.edtLog.WriteLog("Articoli esclusi per lunghezza codici superiore a quella disponibile nel gestionale:",,,,oApp.ColorGridForeRed)
		*.PF.pgNormalizzazione.edtLog.WriteLog("")
		Select curEccedenze
		Scan
			.PF.pgNormalizzazione.edtLog.WriteLog(" " + Alltrim(curEccedenze.Codice_Ordinazione) + ;
				" - " + curEccedenze.Descrizione,,,,oApp.ColorGridForeRed,,, .T.) &&  + " [" + Alltrim(curEccedenze.Marca) + "]"
		Endscan
		.PF.pgNormalizzazione.edtLog.WriteLog("")
	Endif

	Select	Codice_Ordinazione As Cd_AR ;
		, Descrizione ;
		, Prezzo_Pubblico__ As PrezzoAcquisto ;
		, Prezzo_Pubblico__ As PrezzoVendita ;
		, Sconto As ScontoAcquisto ;
		, Note As NotexLSImport ;
		, Marca As Cd_ARMarca ;
		From curAppoggio ;
		Into Cursor curMain Readwrite ;
		Where !IsEmpty(Codice_Ordinazione) ;
		And Codice_Ordinazione Not In (Select Distinct Codice_Ordinazione From curDuplicati) ;
		And Codice_Ordinazione Not In (Select Distinct Codice_Ordinazione From curEccedenze)

	Use In curAppoggio
	Use In curDuplicati
	Use In curEccedenze
	.PF.pgNormalizzazione.edtLog.WriteLog("ATTENZIONE: i campi descrittivi troppo lunghi verranno troncati!")
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	***********************************************************************************

	* Cancellazione dati su tabella BLS xLSImport
	* (vengono cancellati solo i records che riguardano il listino Siemens)
	.PF.pgNormalizzazione.edtLog.WriteLog("Cancellazione records presenti listino Siemens")
	xSqlExec("Delete From xLSImport Where Cd_xLS = " + Format4Spt(cCd_xLS), , .T.)

	* Inserimento dati su tabella BLS xLSImport
	Select curMain
	Go Top
	lnRecCount 	= Reccount('curMain') &&- 1
	lnSkipped 	= 0
	.ProgBarShow(0, Reccount('curMain'), 'Normalizzazione listino Siemens') && - 1
	.PF.pgNormalizzazione.edtLog.WriteLog("OK!",,,,,,, .T.)
	.PF.pgNormalizzazione.edtLog.WriteLog("")
	.PF.pgNormalizzazione.edtLog.WriteLog("Normalizzazione listino Siemens") &&,,,,,, .T.

	Scan
		.ProgBarAdvance(Recno('curMain'), 'Normalizzazione listino Siemens - ' + Transform(Recno('curMain')) + '/' + Transform(Reccount('curMain'))) &&  - 1

		TEXT TO lcStmt TEXTMERGE NOSHOW
			Declare @LastIdentity Int

			Insert Into [xLSImport]
		           ([Cd_xLS]
		           ,[Cd_AR]
		           ,[Descrizione]
		           ,[PrezzoAcquisto]
		           ,[PrezzoVendita]
		           ,[ScontoAcquisto]
		           ,[NotexLSImport]
		           ,[Cd_ARMarca])
		     Values
		           (<<Format4Spt(cCd_xLS)>>
		           ,<<Format4Spt(curMain.Cd_AR)>>
		           ,<<Format4Spt(Left(curMain.Descrizione, 80))>>
		           ,<<Format4Spt(curMain.PrezzoAcquisto)>>
		           ,<<Format4Spt(curMain.PrezzoVendita)>>
		           ,<<Format4Spt(PercStrNormalize(curMain.ScontoAcquisto))>>
		           ,<<Format4Spt(curMain.NotexLSImport)>>
		           ,<<Format4Spt(curMain.Cd_ARMarca)>>)

	    If @@ROWCOUNT > 0
				Set @LastIdentity = SCOPE_IDENTITY()
			Else
				Set @LastIdentity = 0

			Select @LastIdentity AS NewId
		ENDTEXT

		If xSqlExec(lcStmt, 'Inserted', .T.) < 0
			xMessageBox('Il file di import non è un file SIEMENS oppure ci sono' ;
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
Return "2.0 del 15-02-2013"
Endfunc
* ---------------------------------------------------------------
