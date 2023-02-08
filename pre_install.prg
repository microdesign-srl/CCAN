Local cPath As String
cPath = Addbs(oApp.PersDir) + 'Forms\'

* Bisogna eliminare dalla cartella Forms i files che riguardano l'import Comet
If File(cPath + 'cmd_xcomet_import.vcx')
	Delete File cPath + 'cmd_xcomet_import.*'
Endif
If File(cPath + 'fedi_xcometarmisura.vcx')
	Delete File cPath + 'fedi_xcometarmisura.*'
Endif
If File(cPath + 'fedi_xcometargruppo.vcx')
	Delete File cPath + 'fedi_xcometargruppo.*'
Endif

* Bisogna eliminare dalla cartella Forms i files che sono stati sostituiti da altri con nomi più consoni.
If File(cPath + 'cmd_creazioneofferte.vcx')
	Delete File cPath + 'cmd_creazioneofferte.*'
Endif
If File(cPath + 'cmd_generacodice.vcx')
	Delete File cPath + 'cmd_generacodice.*'
Endif
If File(cPath + 'cmd_xdoprenotamateriali.vcx')
	Delete File cPath + 'cmd_xdoprenotamateriali.*'
Endif

* Bisogna eliminare dalla cartella Forms i files che riguardano personalizzazioni specifiche di clienti.
If File(cPath + 'cmd_xrdticket_generaPers.vcx')
	Delete File cPath + 'cmd_xrdticket_generaPers.*'
Endif
If File(cPath + 'cmd_xstatolavoropers.vcx')
	Delete File cPath + 'cmd_xstatolavoropers.*'
Endif
If File(cPath + 'fedi_xrdticketPers.vcx')
	Delete File cPath + 'fedi_xrdticketPers.*'
Endif

&& Prosegue con l'installazione\aggiornamento solo se è presente uno dei seguenti moduli nella licenza:
&&  - GAC
&&  - Assistenza
&&  - Contratti
Return oApp.LicInfo.GAC	Or oApp.LicInfo.Assistenza Or oApp.LicInfo.Contratti
