Local lcSetupDir As String
Local lcPersDirServer As String

lcSetupDir = Addbs(oParm.InstallDir)
lcPersDirServer = Addbs(oApp.PersDirServer)

If !Directory(lcPersDirServer)
	*Mkdir lcPersDirServer
	CreateDirectory(lcPersDirServer,  0)
Endif

** MMImages
If !Directory(lcPersDirServer + 'MMImages')
	*Mkdir lcPersDirServer + 'MMImages'
	CreateDirectory(lcPersDirServer + 'MMImages',  0)
Endif
If File(lcPersDirServer + 'MMImages\Blank.jpg')
	*Delete File lcPersDirServer + 'MMImages\Blank.jpg'
	DeleteFile(lcPersDirServer + 'MMImages\Blank.jpg') 
Endif
*Copy File lcSetupDir + 'MMImages\Blank.jpg' To lcPersDirServer + 'MMImages'
CopyFile(lcSetupDir + 'MMImages\Blank.jpg', lcPersDirServer + 'MMImages\Blank.jpg', 0)

** MMTemplates
If !Directory(lcPersDirServer + 'MMTemplates')
	*Mkdir lcPersDirServer + 'MMTemplates'
	CreateDirectory(lcPersDirServer + 'MMTemplates',  0)
Endif
If File(lcPersDirServer + 'MMTemplates\Template.doc')
	*Delete File lcPersDirServer + 'MMTemplates\Template.doc'
	DeleteFile(lcPersDirServer + 'MMTemplates\Template.doc')
Endif
*Copy File lcSetupDir + 'MMTemplates\Template.doc' To lcPersDirServer + 'MMTemplates'
CopyFile(lcSetupDir + 'MMTemplates\Template.doc', lcPersDirServer + 'MMTemplates\Template.doc', 0)

Return .T.
