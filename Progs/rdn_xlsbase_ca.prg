lparameters toForm

local lcStmt, lcMsg, lcTipoImport, lcXlsFileName, lcErrDsc as string
local lnRecCount, ln2BeEvaluated, lnTotTime as integer
local lnFileHandle, lnRet, lnErrNum as integer
local lnCosto as decimal
local llExit, llCalcolaCosto as Boolean

with toForm
	lcTipoImport	 = .PF.pgGenerale.txtCd_xRDImportTipo.field.value
	lcXlsFileName  = .PF.pgGenerale.txtDBFileName.field.value
	llCalcolaCosto = .PF.pgGenerale.chkCalcolaMediaCostoProssimoMese.value
	ltStartTime 	 = datetime()

	.PF.pgValutazione.edtLog.WriteLog("")
	.PF.pgValutazione.edtLog.WriteLog("Inizio valutazione: " + ttoc(ltStartTime))

	* Verifica se si è scelto un corretto file di import
	llExit = .f.
	lnFileHandle = fopen(lcXlsFileName)
	if lnFileHandle < 0
		llExit = .t.
	else
		fclose(lnFileHandle)
		**use in (select('curMainCA'))
		lnRet = XLS_ImportData(lcXlsFileName, "[MRO$]", "datiXLSCA", , @lnErrNum, @lcErrDsc)
		llExit = lnRet < 0
	endif

	if llExit
		xMessageBox('Ci sono problemi con la procedura di valutazione!' ;
			+ chr(13) ;
			+ chr(13) ;
			+ 'Impossibile continuare.', 16)
		toForm.CmdExit()
		return .f.
	endif

	delete all in curMainCA

	insert into curMainCA(Cd_DOSottoCommessa, Cd_PrAttivita, Cd_PrRisorsa, Cd_xOperatore, DataInizio, DataFine, Cd_xRDTipoVal, Durata, selected, Messaggio) ;
		select	Codice_Commessa, ;
		Identificativo_Attività, ;
		Codice_Risorsa, ;
		Codice_Operatore, ;
		data, data, ;
		Tipo_Valorizzazione, ;
		Nr_Ore, ;
		.t., ;
		space(100) ;
		from datiXLSCA ;
		where !IsEmpty(Codice_Commessa) ;
		and !IsEmpty(Identificativo_Attività) ;
		and !IsEmpty(Codice_Risorsa) ;
		and !IsEmpty(Codice_Operatore) ;
		and !IsEmpty(data) ;
		and !IsEmpty(Tipo_Valorizzazione)

	* Valutazione dati
	select curMainCA
	calculate cnt() for !deleted() to lnRecCount in curMainCA
	go top

	ln2BeEvaluated 	= 0
	.ProgBarShow(0, reccount('curMainCA'), 'Valutazione dati tipologia di import ' + lcTipoImport)
	.PF.pgValutazione.edtLog.WriteLog("OK!",,,,,,, .t.)
	.PF.pgValutazione.edtLog.WriteLog("")
	.PF.pgValutazione.edtLog.WriteLog('Valutazione dati tipologia di import ' + lcTipoImport) &&,,,,,, .T.

	scan
		.ProgBarAdvance(recno('curMainCA'), 'Valutazione dati tipologia di import ' + lcTipoImport + ' ' + transform(recno('curMainCA')) + '/' + transform(reccount('curMainCA') - 1))

		* Calcola la media retribuzione oraria per operatore
		if llCalcolaCosto
			text TO lcStmt NOSHOW TEXTMERGE
				select
					count(*)
				from
					[dbo].[xOperatoreVal] OV
					inner join xOperatore O on OV.Id_xOperatore = O.Id_xOperatore
				where
					Cd_xOperatore = <<Format4Spt(curMainCA.Cd_xOperatore)>>
					and Cd_xRDTipoValorizzazione = <<Format4Spt(curMainCA.Cd_xRDTipoVal)>>
					and [dbo].[afn_dt_Datetime2Date] (InizioValidita) = [dbo].[afn_dt_Datetime2Date] ([dbo].[afn_dt_FirstDayOfMonth] (<<Format4Spt(curMainCA.DataInizio)>>))
			ENDTEXT

			if xSqlExec2Var(lcStmt) = 0
				text TO lcStmt NOSHOW TEXTMERGE
					select top 6
						OV.Id_xOperatore
					  ,[Costo]
					from
						[dbo].[xOperatoreVal] OV
						inner join xOperatore O on OV.Id_xOperatore = O.Id_xOperatore
					where
						Cd_xOperatore = <<Format4Spt(curMainCA.Cd_xOperatore)>>
						and Cd_xRDTipoValorizzazione = <<Format4Spt(curMainCA.Cd_xRDTipoVal)>>
						and InizioValidita < [dbo].[afn_dt_FirstDayOfMonth] (<<Format4Spt(curMainCA.DataInizio)>>)
					order by
						InizioValidita desc
				ENDTEXT

				lcStmt = xSqlExec(lcStmt, 'curOV')

				if reccount('curOV') > 0
					calculate sum(Costo) to lnCosto
					lnCosto = round(lnCosto / reccount('curOV'), 2)

					text TO lcStmt NOSHOW TEXTMERGE
						insert into [dbo].[xOperatoreVal]
						  ([Id_xOperatore]
						  ,[Cd_xRDTipoValorizzazione]
						  ,[Costo]
						  ,[Riga]
						  ,[InizioValidita]
						  ,[NumOrePrev])
						select top 1
							OV.Id_xOperatore
						  ,<<Format4Spt(curMainCA.Cd_xRDTipoVal)>>
						  ,<<Format4Spt(lnCosto)>>
						  ,(select max(Riga) + 1 from xOperatoreVal where Id_xOperatore in (select Id_xOperatore from xOperatore where Cd_xOperatore = <<Format4Spt(curMainCA.Cd_xOperatore)>>))
						  ,[dbo].[afn_dt_FirstDayOfMonth] (<<Format4Spt(curMainCA.DataInizio)>>)
						  ,0
						from
							[dbo].[xOperatoreVal] OV
							inner join xOperatore O on OV.Id_xOperatore = O.Id_xOperatore
						where
							Cd_xOperatore = <<Format4Spt(curMainCA.Cd_xOperatore)>>
					ENDTEXT

					xSqlExec(lcStmt)
				endif

				use in curOV
			endif
		endif

		* Verifica se il codice risorsa esiste
		select curMainCA

		do case
			case nvl(xSqlExec2Var("Select COUNT(*) From PRRisorsa Where Cd_PRRisorsa = " + Format4Spt(curMainCA.Cd_PrRisorsa)), 0) = 0
				replace Messaggio with 'Risorsa non presente', TipoInsert with 1 in curMainCA
				ln2BeEvaluated = ln2BeEvaluated + 1
			case nvl(xSqlExec2Var("Select COUNT(*) from [PRRisorsaLink] RL inner join PRRisorsa R on RL.Cd_PrRisorsa_P = R.Cd_PrRisorsa where Cd_PrRisorsa_C = " + Format4Spt(curMainCA.Cd_PrRisorsa) + " and Cd_PrRisorsa_P in (select Cd_PrRisorsa from PRAttivita where Cd_PrAttivita = " + Format4Spt(curMainCA.Cd_PrAttivita) + " and R.Gruppo = 1)"), 0) = 0
				replace Messaggio with "Risorsa non associata al gruppo risorse dell'attività", TipoInsert with 2 in curMainCA
				ln2BeEvaluated = ln2BeEvaluated + 1
			case nvl(xSqlExec2Var("Select COUNT(*) From [xOperatorePRRisorsa] Where Cd_PRRisorsa = " + Format4Spt(curMainCA.Cd_PrRisorsa) + " and Id_xOperatore in (select Id_xOperatore from xOperatore where Cd_xOperatore = " + Format4Spt(curMainCA.Cd_xOperatore) + ")"), 0) = 0
				replace Messaggio with "Risorsa non associata all'operatore", TipoInsert with 3 in curMainCA
				ln2BeEvaluated = ln2BeEvaluated + 1
			otherwise
				delete in curMainCA
		endcase
	endscan

	go top

	.PF.pgValutazione.edtLog.WriteLog("OK!",,,,,,, .t.)
	.PF.pgValutazione.edtLog.WriteLog("")
	.ProgBarHide()

	ltEndTime 		= datetime()
	lnTotTime 		= ltEndTime - ltStartTime

	text To lcMsg TextMerge NoShow Pretext 3

		Rilevazioni Processate:	<< lnRecCount >>
		Rilevazioni Da Valutare:	<< ln2BeEvaluated >>
		Tempo impiegato:		<< SecToHms(lnTotTime, 1) >>

	ENDTEXT

	.PF.pgValutazione.edtLog.WriteLog(lcMsg,,, 'Courier New')

	if ln2BeEvaluated = 0
		.PF.pgValutazione.edtLog.WriteLog(chr(13) + "Valutazione terminata con successo alle " + ttoc(ltEndTime),,,, oApp.ColorGridForeBlu)
	else
		.PF.pgValutazione.edtLog.WriteLog(chr(13) + "Valutazione terminata.",,,, oApp.ColorGridForeRed)
		.PF.pgValutazione.edtLog.WriteLog(chr(13) + "Sono da sistemare " + transform(ln2BeEvaluated) + " rilevazioni.",,,, oApp.ColorGridForeRed)
	endif
endwith
