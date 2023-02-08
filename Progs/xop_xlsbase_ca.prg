lparameters toForm

local lcXlsFileName, lcErrDsc, lcStmt as string
local lnFileHandle, lnRet, lnErrNum as integer
local llExit as Boolean

with toForm
	lcXlsFileName  = .PF.pgGenerale.txtDBFileName.field.value
	ltStartTime 	 = datetime()

	* Verifica se si è scelto un corretto file di import
	llExit = .f.
	lnFileHandle = fopen(lcXlsFileName)
	if lnFileHandle < 0
		llExit = .t.
	else
		fclose(lnFileHandle)
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

	insert into curMainCA(Cd_xOperatore, NumeroMatricola, InizioValidita, Cd_xRDTipoVal, NumOrePrev, Costo, selected) ;
		select	Codice_Operatore, ;
		Matricola, ;
		data, ;
		Tipo_Valorizzazione, ;
		Ore_Presunte, ;
		Costo_Orario, ;
		.t. ;
		from datiXLSCA ;
		where !IsEmpty(Codice_Operatore) ;
		and !IsEmpty(data) ;
		and !IsEmpty(Tipo_Valorizzazione)

	* Valutazione dati
	select curMainCA
	go top

	scan
		.ProgBarAdvance(recno('curMainCA'), 'Valutazione dati ' + transform(recno('curMainCA')) + '/' + transform(reccount('curMainCA') - 1))

		* Esclude i record non trovati
		text TO lcStmt NOSHOW TEXTMERGE
				select
					count(*)
				from
					[dbo].[xOperatoreVal] OV
					inner join xOperatore O on OV.Id_xOperatore = O.Id_xOperatore
				where
					Cd_xOperatore = <<Format4Spt(curMainCA.Cd_xOperatore)>>
					and Cd_xRDTipoValorizzazione = <<Format4Spt(curMainCA.Cd_xRDTipoVal)>>
					and [dbo].[afn_dt_Datetime2Date] (InizioValidita) = [dbo].[afn_dt_Datetime2Date] ([dbo].[afn_dt_FirstDayOfMonth] (<<Format4Spt(curMainCA.InizioValidita)>>))
		ENDTEXT

		if xSqlExec2Var(lcStmt) = 0
			delete in curMainCA
		endif
	endscan

	go top
endwith
